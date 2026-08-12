---
name: tavily
description: Search the web, extract page content, crawl sites, map websites, and run deep research using Tavily's hosted MCP server (tavily_search, tavily_extract, tavily_crawl, tavily_map, tavily_research). Use when the user asks for web search, current information, fetching or reading a webpage, site research, or deep multi-source research.
---

# Tavily Search (MCP)

Connects to Tavily's official hosted MCP server (`https://mcp.tavily.com/mcp/`).
All 5 tools are reachable as `async` methods on the `tavily` module. Tool names
use **underscores** (e.g. `tavily_search`, not `tavily-search`).

## Setup

The API key lives in `~/.prime/agent/auth.json` under `"mcp:tavily"` as
`{"type": "api_key", "key": "tvly-..."}` (env override: `TAVILY_API_KEY`).
If a call raises `NotEnabled`, the key is missing — tell the user to message
the agent the key (or set `TAVILY_API_KEY`) so it can be saved to auth.json.
Host-side config (the `mcpServers.tavily` entry in
`~/.prime/agent/settings.json`) resolves the endpoint URL and shows it in
`/mcp list`.

## Usage (native)

```python
import tavily

# Discover tools + inspect a tool's arguments (don't assume schemas):
for tool in await tavily.list_tools():
    print(tool["name"], "-", tool["description"])
help(tavily.tavily_search)          # shows the JSON Schema

# Call a tool; keyword args must match its input schema:
result = await tavily.tavily_search(query="latest Prime Agent release", max_results=5)
```

Notes:
- Every tool is `async` — always `await`.
- Results are already-parsed Python (dict/JSON for structured output, else text).
- Unknown/odd tool names: `await tavily.call_tool("name", {"arg": "value"})`.

## Tools reference

### `tavily_search` — search the web
The workhorse: current info, news, facts, anything beyond training cutoff.
- Required: `query: str`
- Useful options: `max_results` (default 5), `search_depth`
  (`basic` | `advanced` | `fast` | `ultra-fast`), `topic`
  (`general` | `news` | `finance` | …), `time_range`, `include_images`,
  `include_raw_content`, `include_domains` / `exclude_domains`, `country`,
  `start_date` / `end_date` (YYYY-MM-DD), `exact_match`.
```python
r = await tavily.tavily_search(query="NixOS 26.05 release notes", max_results=8, topic="news", time_range="month")
```

### `tavily_extract` — read page content from URLs
Turn URLs into clean markdown/text. Use after search when snippets are thin.
- Required: `urls: list[str]`
- Options: `extract_depth` (`advanced` for LinkedIn/protected/tables),
  `format` (`markdown` | `text`), `include_images`, `query`
  (rerank chunks by relevance).
```python
r = await tavily.tavily_extract(urls=["https://example.com/page"], extract_depth="advanced")
```

### `tavily_crawl` — crawl a site
Walk a site from a root URL and extract content with depth/breadth limits.
- Required: `url: str`
- Options: `max_depth` (default 1), `max_breadth` (default 20), `limit`
  (default 50), `instructions` (natural-language filter, e.g. "only pricing pages"),
  `select_paths` / `select_domains` (regex), `allow_external`, `extract_depth`,
  `format`.
```python
r = await tavily.tavily_crawl(url="https://docs.example.com", max_depth=2, instructions="Return only API reference pages")
```

### `tavily_map` — map a site's structure
List URLs discovered from a base URL (like a sitemap). No content extraction.
- Required: `url: str`
- Options: `max_depth` (default 1), `max_breadth` (default 20), `limit`
  (default 50), `instructions`, `select_paths` / `select_domains`,
  `allow_external`.
```python
r = await tavily.tavily_map(url="https://docs.example.com", max_depth=2)
```

### `tavily_research` — deep multi-source research
Synthesize an answer from many sources for a broad question/task. Rate limit:
20 requests/min.
- Required: `input: str` (comprehensive task description)
- Options: `model` (`auto` | `mini` | `pro`) — `mini` for narrow tasks,
  `pro` for broad ones.
```python
r = await tavily.tavily_research(input="Compare the free tiers of Exa, Tavily, and Brave Search APIs for use in an AI agent")
```

## Fallback (module unavailable)

If `import tavily` fails (e.g. kernel env not yet rebuilt on this NixOS host),
connect directly with the installed `mcp` SDK:

```python
import json, os
from pathlib import Path
import httpx
from mcp import ClientSession
from mcp.client.streamable_http import streamable_http_client

def _tavily_key():
    env = os.environ.get("TAVILY_API_KEY", "").strip()
    if env:
        return env
    try:
        auth = json.loads((Path.home() / ".prime" / "agent" / "auth.json").read_text())
        cred = auth.get("mcp:tavily") or {}
        if cred.get("type") == "api_key":
            return str(cred.get("key") or "").strip()
    except (OSError, ValueError):
        pass
    return ""

async def tavily_call(tool, arguments=None):
    key = _tavily_key()
    if not key:
        return "Tavily is not set up: no API key in auth.json (mcp:tavily) or TAVILY_API_KEY."
    headers = {"Authorization": f"Bearer {key}"}
    async with httpx.AsyncClient(headers=headers) as client:
        async with streamable_http_client("https://mcp.tavily.com/mcp/", http_client=client) as (read, write, _sid):
            async with ClientSession(read, write) as session:
                await session.initialize()
                if arguments is None:
                    return [dict(t) for t in (await session.list_tools()).tools]
                result = await session.call_tool(tool, arguments or {})
    if hasattr(result, "content"):
        parts = []
        for item in result.content:
            text = getattr(item, "text", None)
            if text is not None:
                parts.append(text)
            elif hasattr(item, "structuredContent") and item.structuredContent:
                parts.append(json.dumps(item.structuredContent, indent=2))
        return "\n\n".join(parts) if parts else str(result)
    return str(result)

# tools = await tavily_call(None)                                 # discover
# r = await tavily_call("tavily_search", {"query": "...", "max_results": 5})   # search
# r = await tavily_call("tavily_extract", {"urls": ["https://example.com"]})   # extract
# r = await tavily_call("tavily_research", {"input": "..."})                    # research
```
