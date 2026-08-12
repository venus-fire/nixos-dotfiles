"""Tavily integration: tools auto-discovered from Tavily's hosted MCP server.

Usage in the kernel:

    import tavily
    results = await tavily.tavily_search(query="...", max_results=5)
"""

from __future__ import annotations

from rlm import McpIntegration

__all__ = ["Tavily", "tavily"]


class Tavily(McpIntegration):
    server = "tavily"
    url = "https://mcp.tavily.com/mcp/"


tavily = Tavily()


# Names the kernel bootstrap probes to decide if a module is a callable skill.
# Don't forward them, or `getattr(module, "run")` returns an MCP tool stub and the
# module gets wrapped as callable, breaking `await tavily.<tool>()` dispatch.
_RESERVED = {"run", "__wrapped__", "__call__"}


def __getattr__(name: str):
    # Forward bare module-level access (e.g. tavily.tavily_search) to the instance,
    # so `import tavily; await tavily.tavily_search(...)` works without `.tavily`.
    if name.startswith("_") or name in _RESERVED:
        raise AttributeError(name)
    return getattr(tavily, name)
