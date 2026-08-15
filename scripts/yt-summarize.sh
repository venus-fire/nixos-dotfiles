#!/usr/bin/env python3
# =============================================================================
# yt-summarize — download YouTube captions with yt-dlp, summarize them with
#                OpenRouter's FREE model router ("openrouter/free")
# =============================================================================
# Usage:
#   yt-summarize <youtube-url> [more urls...]
#   yt-summarize --list-models                 # browse auto-pickable free models
#   yt-summarize -l de <url>                   # subtitles in German
#   yt-summarize -m "some/vendor:model:free" <url>   # one-off override (optional)
#
# How it works:
#   1. yt-dlp downloads the video's subtitles (manual captions preferred,
#      auto-generated ASR fallback) as VTT into a temp dir.
#   2. The VTT is cleaned (timestamps, tags, HTML entities) to plain text.
#   3. Chunking is context-aware: the chunk size is auto-sized from the
#      preferred model's context window, so a transcript is only chunked
#      (map then reduce) when it truly exceeds what the model can take in one
#      call. Override with -c or $YT_SUM_CHUNK.
#   4. Model selection — always automatic, nothing to maintain:
#      fetch OpenRouter's free (:free) model list, filter OUT non-chat models
#      (safety/classifier/embedding/audio/transcription — the plain
#      "openrouter/free" router does NOT filter and can land on e.g.
#      nvidia/nemotron-3.5-content-safety:free), then rank for FAST MIDRANGE
#      summarization: preferred context sweet spot 128k-262k, non-reasoning,
#      small active params first; giant 500B+/1M-context models sink to the
#      bottom of the failover list. If a model becomes unavailable (free
#      models rotate), the next one is tried automatically; "openrouter/free"
#      is only a last resort. Optional one-off override with -m/$YT_SUM_MODEL.
#
# Requirements (declared in the dotfiles repo):
#   yt-dlp  (modules/packages.nix)
#   python3 (modules/packages.nix)
#
# API key: read from $OPENROUTER_API_KEY, or from a key file OUTSIDE this
# repo (default ~/.config/openrouter/key — override with OPENROUTER_KEY_FILE).
# One-time setup (the key itself never enters the dotfiles repo):
#     mkdir -p ~/.config/openrouter
#     printf '%s\n' 'sk-or-v1-...' > ~/.config/openrouter/key
#     chmod 600 ~/.config/openrouter/key
# Free keys: https://openrouter.ai/keys  (free models cost $0)
#
# Env overrides:
#   OPENROUTER_API_KEY   key (takes precedence over the key file)
#   OPENROUTER_KEY_FILE  key file (default: ~/.config/openrouter/key)
#   YT_SUM_MODEL         one-off model override (same as -m; otherwise auto)
#   YT_SUM_LANG          subtitle language (default: en)
#   YT_SUM_CHUNK         max chars per chunk (default: auto from model context)
#   YT_SUM_MAX_TOKENS    max completion tokens per call (default: 4096)
#   YT_SUM_API_URL       API base URL (default: https://openrouter.ai/api/v1)
# =============================================================================

import argparse
import html
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

SYS_PROMPT = (
    "Summarize YouTube video transcripts faithfully. Never invent facts not "
    "present in the transcript. Use Markdown. Answer in the language of the "
    "transcript."
)

KEY_FILE = os.environ.get(
    "OPENROUTER_KEY_FILE", os.path.expanduser("~/.config/openrouter/key")
)


# ---------------------------------------------------------------------------
# config
# ---------------------------------------------------------------------------
def parse_args():
    p = argparse.ArgumentParser(
        description="Download YouTube captions with yt-dlp and summarize them "
        "via OpenRouter's free model router."
    )
    p.add_argument("urls", nargs="*", metavar="URL", help="YouTube video URL(s)")
    p.add_argument("-l", "--lang", default=os.environ.get("YT_SUM_LANG", "en"),
                   help="subtitle language (default: en)")
    p.add_argument("-m", "--model",
                   help="optional one-off model override (default: auto-picked "
                        "best free chat model, with automatic failover)")
    p.add_argument("--list-models", action="store_true",
                   help="list the free chat models the script auto-picks from")
    p.add_argument("-c", "--chunk", type=int,
                   default=int(os.environ.get("YT_SUM_CHUNK") or 0) or None,
                   help="max chars per chunk (default: auto-sized to the "
                        "selected model's context — only chunks when needed)")
    p.add_argument("-t", "--max-tokens", type=int,
                   default=int(os.environ.get("YT_SUM_MAX_TOKENS", "4096")),
                   help="max completion tokens per call (default: 4096)")
    p.add_argument("--api-url", default=os.environ.get(
        "YT_SUM_API_URL", "https://openrouter.ai/api/v1"))
    return p.parse_args()


def get_key():
    key = os.environ.get("OPENROUTER_API_KEY", "").strip()
    if not key and os.path.isfile(KEY_FILE):
        key = open(KEY_FILE, encoding="utf-8").read().strip()
    return key


# ---------------------------------------------------------------------------
# model selection
# ---------------------------------------------------------------------------
# model ids that are NOT chat/summarization models — never auto-pick these
# (the plain "openrouter/free" router does not filter, which is how a
# content-safety classifier can end up "summarizing" a transcript).
_NON_CHAT_HINTS = (
    "content-safety", "safety", "guard", "moder", "classif", "reward",
    "embed", "rerank", "speech", "audio", "whisper", "asr", "stt", "tts",
    "transcrib", "dall-e", "flux", "sdxl", "stable-diffusion", "upscal",
    "segment", "detect", "ocr",
)


def is_chat_model(model_id):
    return not any(h in model_id.lower() for h in _NON_CHAT_HINTS)


# --- model ranking: prefer FAST MIDRANGE models -----------------------------
# Free models rotate, so this is heuristic, not a hardcoded list:
#   * context sweet spot 128k-262k (fits any transcript; giant-context MoEs
#     like the 550B/1M nemotron are slow and overkill for a summary)
#   * non-reasoning models (reasoning = extra thinking latency)
#   * smaller active parameter count (parsed from "aXXb" MoE ids, else XXb)
_SWEET_MIN_CTX = 131072
_SWEET_MAX_CTX = 262144
_GIANT_CTX = 512000
_REASONING_HINTS = ("reasoning", "thinking", "-r1-", "deepseek")


def _active_size_b(model_id, name):
    """Active params in billions (MoE 'aXXb'), else total 'XXb', else inf."""
    text = f"{model_id} {name}".lower()
    m = re.search(r"a(\d+(?:\.\d+)?)\s*b", text)
    if m:
        return float(m.group(1))
    m = re.search(r"(^|[\-_.\s/])(\d+(?:\.\d+)?)\s*b", text)
    if m:
        return float(m.group(2))
    return float("inf")


def _model_score(m):
    """Higher = better default pick. Context band dominates; reasoning and
    size are tie-breaks inside a band."""
    ctx = m["context_length"]
    if ctx > _GIANT_CTX:
        base = 15.0                                   # giant 500B+/1M: last resort
    elif ctx > _SWEET_MAX_CTX:
        base = 60.0 + (ctx - _SWEET_MAX_CTX) / (_GIANT_CTX - _SWEET_MAX_CTX) * 20.0
    elif ctx >= _SWEET_MIN_CTX:
        base = 100.0 + (ctx - _SWEET_MIN_CTX) / (_SWEET_MAX_CTX - _SWEET_MIN_CTX) * 50.0
    else:
        base = 30.0 + ctx / _SWEET_MIN_CTX * 30.0     # <128k: works, needs chunking
    if any(h in m["id"].lower() for h in _REASONING_HINTS):
        base -= 0.5
    return base


def fetch_free_models(api_url):
    """Free (:free) chat-capable models, ranked for fast summarization."""
    req = urllib.request.Request(
        f"{api_url}/models", headers={"User-Agent": "yt-summarize"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.load(resp)
    models = []
    for m in data.get("data", []):
        mid = m.get("id", "")
        if not mid.endswith(":free") or not is_chat_model(mid):
            continue
        models.append({
            "id": mid,
            "context_length": m.get("context_length") or 0,
            "name": m.get("name") or mid,
        })
    models.sort(key=lambda m: (-_model_score(m), _active_size_b(m["id"], m["name"]), m["id"]))
    return models


class ApiError(Exception):
    pass


class FatalApiError(ApiError):
    """Auth/credit failure — pointless to try another model, stop."""


class ModelUnavailable(ApiError):
    """This model is gone/not accessible — try the next candidate."""


class TransientApiError(ApiError):
    """Rate limit / 5xx / network, retries exhausted — try the next model."""


def resolve_models(api_url, cli_model):
    """-m/$YT_SUM_MODEL override, else the ranked free chat list.

    Returns (models, how, models_ctx): models is the ordered list of
    candidates to try (first is preferred; later ones are automatic failover
    targets); models_ctx maps model id -> context_length (None if unknown).
    """
    explicit = cli_model or os.environ.get("YT_SUM_MODEL")
    if explicit:
        ctx = model_context(api_url, explicit)
        return [explicit], "explicit override", {explicit: ctx}
    try:
        free = fetch_free_models(api_url)
        if free:
            ids = [m["id"] for m in free]
            ctx = {m["id"]: m["context_length"] for m in free}
            return ids, f"auto (ranked free chat list, {len(ids)} models)", ctx
    except Exception as e:
        print(f"  note: could not fetch free model list ({e}); "
              "falling back to openrouter/free", file=sys.stderr)
    return ["openrouter/free"], "last-resort router", {"openrouter/free": None}


def model_context(api_url, model_id):
    """Context length for any model id, or None if not found."""
    try:
        req = urllib.request.Request(
            f"{api_url}/models", headers={"User-Agent": "yt-summarize"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.load(resp)
        for m in data.get("data", []):
            if m.get("id") == model_id:
                return m.get("context_length") or None
    except Exception:
        pass
    return None


# --- context-aware chunking ------------------------------------------------
# Rough English token density: ~3.5 chars/token (conservative). Reserve space
# for the answer (max_tokens) plus prompt overhead. Cap the chunk so even a
# failover to a 128k model still fits (current smallest free model).
_CHARS_PER_TOKEN = 3.5
_MAX_CHUNK_CHARS = 200000      # ~57k tokens — fits every free model
_MIN_CHUNK_CHARS = 8000


def compute_chunk_size(cfg):
    """Auto chunk size from the preferred model's context window.

    Returns None when the model's context is unknown (caller falls back to a
    conservative fixed size); otherwise the max chars per chunk.
    """
    ctx = None
    if cfg.models and cfg.models_ctx:
        ctx = cfg.models_ctx.get(cfg.models[0])
    if not ctx:
        return None
    size = int((ctx - cfg.max_tokens - 2048) * _CHARS_PER_TOKEN)
    return max(_MIN_CHUNK_CHARS, min(size, _MAX_CHUNK_CHARS))


# ---------------------------------------------------------------------------
# yt-dlp
# ---------------------------------------------------------------------------
def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def fetch_meta(url):
    r = run(["yt-dlp", "-q", "--skip-download", "--no-playlist",
             "--print", "%(title)s", "--print", "%(uploader)s",
             "--print", "%(duration_string)s", url], timeout=180)
    if r.returncode != 0:
        raise RuntimeError(f"yt-dlp could not fetch metadata for {url}\n{r.stderr.strip()[-400:]}")
    lines = [l.strip() for l in r.stdout.splitlines()] + ["", "", ""]
    return lines[0] or url, lines[1] or "?", lines[2] or "?"


def fetch_vtt(url, lang, tmpdir):
    """Return the downloaded .vtt path, or None if no subtitles exist."""
    r = run(["yt-dlp", "-q", "--skip-download", "--no-playlist",
             "--write-subs", "--write-auto-subs", "--sub-langs", lang,
             "--sub-format", "vtt", "-o", f"{tmpdir}/%(id)s.%(ext)s", url],
            timeout=300)
    for f in sorted(os.listdir(tmpdir)):
        if f.endswith(".vtt"):
            return os.path.join(tmpdir, f)
    return None


# ---------------------------------------------------------------------------
# VTT -> plain text
# ---------------------------------------------------------------------------
_TIMING = re.compile(r"^\d{1,2}:\d{2}:\d{2}(?:\.\d{3})?\s*-->")
_CUE_ID = re.compile(r"^\d+$")
_SETTINGS = re.compile(r"^(align|position|line|size)\s*:")


def clean_vtt(path):
    out = []
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.strip()
        if not line or line == "WEBVTT" or line.startswith("Kind:") or \
                line.startswith("Language:") or _SETTINGS.match(line) or \
                _TIMING.match(line) or _CUE_ID.match(line):
            continue
        line = re.sub(r"<[^>]*>", "", line)          # <c>, <00:00:10.000>
        line = html.unescape(line)                   # &nbsp; &amp; &#39; ...
        line = re.sub(r"\s+", " ", line)
        if line:
            out.append(line)
    text = " ".join(out)
    return re.sub(r"\s+", " ", text).strip()


# ---------------------------------------------------------------------------
# OpenRouter
# ---------------------------------------------------------------------------
_MODEL_ERR_HINTS = (
    "model", "provider", "does not exist", "not found", "unavailable",
    "not available", "not supported", "context", "too long", "exceeds",
)


def _is_model_error(code, errmsg):
    """True if this error means 'this model can't be used right now'."""
    if code in (400, 404):
        low = (errmsg or "").lower()
        return any(h in low for h in _MODEL_ERR_HINTS)
    return False


def call_api(api_url, model, max_tokens, key, sys_prompt, user_prompt):
    """One chat completion for ONE model. Raises classified ApiError on
    failure so the caller can fail over to another model. max_tokens is the
    answer budget (input capacity is handled by chunk sizing)."""
    body = json.dumps({
        "model": model,
        "max_tokens": max_tokens,
        "temperature": 0.3,
        "messages": [
            {"role": "system", "content": sys_prompt},
            {"role": "user", "content": user_prompt},
        ],
    }).encode("utf-8")
    req = urllib.request.Request(
        f"{api_url}/chat/completions", data=body, method="POST",
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "X-Title": "yt-summarize",
        })
    attempt = 0
    while True:
        attempt += 1
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                data = json.load(resp)
            break
        except urllib.error.HTTPError as e:
            errmsg = "unknown"
            try:
                err = json.load(e)
                errmsg = (err.get("error") or {}).get("message", "unknown")
            except Exception:
                pass
            if _is_model_error(e.code, errmsg):
                raise ModelUnavailable(
                    f"HTTP {e.code}: {errmsg}") from e
            if e.code in (401, 403, 402):
                raise FatalApiError(f"HTTP {e.code}: {errmsg}") from e
            retryable = e.code == 429 or e.code >= 500
            if retryable and attempt < 3:
                print(f"  openrouter: HTTP {e.code} — retrying in {3 * attempt}s "
                      f"({errmsg})", file=sys.stderr)
                time.sleep(3 * attempt)
                continue
            if retryable:
                raise TransientApiError(f"HTTP {e.code}: {errmsg}") from e
            raise FatalApiError(f"HTTP {e.code}: {errmsg}") from e
        except urllib.error.URLError as e:
            if attempt < 3:
                print(f"  openrouter: network error ({e.reason}) — retrying in "
                      f"{3 * attempt}s", file=sys.stderr)
                time.sleep(3 * attempt)
                continue
            raise TransientApiError(f"network error: {e.reason}") from e
    choice = (data.get("choices") or [{}])[0] or {}
    content = (choice.get("message") or {}).get("content") or ""
    model_used = data.get("model", "")
    total = ((data.get("usage") or {}).get("total_tokens") or "")
    if model_used:
        print(f"  ↳ resolved model: {model_used}"
              + (f" ({total} tokens)" if total else ""), file=sys.stderr)
        if not is_chat_model(model_used):
            print(f"  ⚠ that model is not a chat/summarization model — run "
                  f"--list-models and pick a chat model with -m", file=sys.stderr)
    if not content:
        print("  warning: empty assistant response", file=sys.stderr)
    return content


def call_with_failover(cfg, key, sys_prompt, user_prompt, max_tokens=None):
    """Try each candidate model in order until one succeeds."""
    tokens = max_tokens or cfg.max_tokens
    errors = []
    for model in cfg.models:
        try:
            return call_api(cfg.api_url, model, tokens, key,
                            sys_prompt, user_prompt)
        except FatalApiError:
            raise
        except ApiError as e:
            errors.append(f"{model}: {e}")
            print(f"  ⤷ {model} failed ({e}); trying next free model...",
                  file=sys.stderr)
    raise RuntimeError("all candidate models failed:\n  "
                       + "\n  ".join(errors))


# ---------------------------------------------------------------------------
# summarization
# ---------------------------------------------------------------------------
def chunk_text(text, max_chars):
    chunks, cur, cur_len = [], [], 0
    for w in text.split():
        if cur and cur_len + 1 + len(w) > max_chars:
            chunks.append(" ".join(cur))
            cur, cur_len = [w], len(w)
        else:
            cur.append(w)
            cur_len += 1 + len(w)
    if cur:
        chunks.append(" ".join(cur))
    return chunks


def summarize_transcript(cfg, key, title, uploader, duration, transcript):
    # chunk size: explicit -c/YT_SUM_CHUNK wins, else auto from the chosen
    # model's context. chunk_text() only splits when the transcript exceeds it,
    # so a typical video is a single call.
    chunk_size = cfg.chunk or cfg.chunk_size or 60000
    chunks = chunk_text(transcript, chunk_size)
    n = len(chunks)
    if n == 0:
        raise RuntimeError("empty transcript")

    def video_hdr():
        return f"Video: {title}\nChannel: {uploader}\nDuration: {duration}"

    ctx = cfg.models_ctx.get(cfg.models[0]) if cfg.models_ctx else None
    print(f"  transcript: {len(transcript)} chars | model context: "
          f"{ctx or 'unknown'} | chunk size: {chunk_size} chars"
          + (f" | {n} part(s)" if n > 1 else ""), file=sys.stderr)

    if n == 1:
        user = (f"{video_hdr()}\n\nFull transcript:\n\n{transcript}\n\n"
                "Produce the final summary: a 2-3 sentence TL;DR, then "
                '"## Key Points" as deduplicated bullets that keep names, '
                'numbers and terms, then optional "## Notable Details", then '
                '"## Bottom Line" (1-2 sentences). Use Markdown.')
        return call_with_failover(cfg, key, SYS_PROMPT, user)

    # map phase — keep each part summary short so the reduce call also fits
    # the model's context (parts feed back in as input).
    part_tokens = min(cfg.max_tokens, 2048)
    parts = []
    for i, chunk in enumerate(chunks, 1):
        print(f"  summarizing part {i}/{n} ({len(chunk)} chars)...",
              file=sys.stderr)
        user = (f"Video: {title}\n\nPart {i}/{n} of the transcript:\n\n"
                f"{chunk}\n\nSummarize THIS PART in concise bullet points: "
                "key topics, names, numbers and conclusions. Be thorough but "
                "do not add outside information.")
        part = call_with_failover(cfg, key, SYS_PROMPT, user,
                                  max_tokens=part_tokens)
        parts.append(f"[{i}/{n}] {part}")

    # reduce phase
    joined = "\n\n".join(parts)
    user = (f"{video_hdr()}\n\nHere are the {n} part-summaries of the "
            f"transcript:\n\n{joined}\n\nCombine them into the FINAL summary: "
            'a 2-3 sentence TL;DR, then "## Key Points" as deduplicated '
            'bullets that keep specifics, then optional "## Notable Details", '
            'then "## Bottom Line" (1-2 sentences). Use Markdown.')
    return call_with_failover(cfg, key, SYS_PROMPT, user)


# ---------------------------------------------------------------------------
# terminal markdown coloring (pure ANSI — no dependencies, works on any tty)
# ---------------------------------------------------------------------------
# Renders the markdown summary with basic colors. Disabled automatically when
# stdout is not a terminal (pipes/files), when NO_COLOR is set, or TERM=dumb —
# so piping stays clean. Default colors suit dark themes (Noctalia).
_ANSI = {
    "reset": "\x1b[0m", "bold": "\x1b[1m", "dim": "\x1b[2m",
    "italic": "\x1b[3m", "underline": "\x1b[4m", "reverse": "\x1b[7m",
    "cyan": "\x1b[96m", "yellow": "\x1b[93m", "magenta": "\x1b[95m",
    "blue": "\x1b[94m", "green": "\x1b[92m", "red": "\x1b[91m",
    "gray": "\x1b[90m", "white": "\x1b[97m",
}
_MD_COLOR = None  # lazy: None=undecided, True/False after first check


def _want_color():
    global _MD_COLOR
    if _MD_COLOR is None:
        term = os.environ.get("TERM", "")
        _MD_COLOR = (sys.stdout.isatty()
                     and os.environ.get("NO_COLOR") is None
                     and term not in ("", "dumb"))
    return _MD_COLOR


# placeholders: keep ANSI codes out of the regexes until the line is done
# (otherwise the link regex can match the '[' inside an ESC[..m sequence)
_PB = "\x00B"; _PI = "\x00I"; _PC = "\x00C"; _PU = "\x00U"; _PR = "\x00R"


def _md_inline(s):
    """Format inline markdown within one line: code, bold, italic, links."""
    s = re.sub(r"`([^`]+)`",
               lambda m: _PC + m.group(1) + _PR, s)
    s = re.sub(r"\*\*([^*]+)\*\*",
               lambda m: _PB + m.group(1) + _PR, s)
    s = re.sub(r"(?<!\*)\*([^*\n]+)\*(?!\*)",
               lambda m: _PI + m.group(1) + _PR, s)
    s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)",
               lambda m: _PU + _PC + m.group(1) + _PR + " (" + m.group(2) + ")", s)
    return (s.replace(_PB, _ANSI["bold"]).replace(_PI, _ANSI["italic"])
             .replace(_PC, _ANSI["cyan"]).replace(_PU, _ANSI["underline"])
             .replace(_PR, _ANSI["reset"]))


def render_markdown(text):
    """Colorize a markdown string for the terminal (plain text if not a tty)."""
    if not _want_color():
        return text
    out = []
    in_code = False
    for line in text.split("\n"):
        stripped = line.lstrip()
        if stripped.startswith("```"):
            in_code = not in_code
            out.append(_ANSI["gray"] + line + _ANSI["reset"])
            continue
        if in_code:
            out.append(_ANSI["reverse"] + line + _ANSI["reset"])
            continue
        m = re.match(r"^(#{1,6})\s+(.*)$", stripped)          # ATX headers
        if m:
            level = len(m.group(1))
            color = {1: "cyan", 2: "yellow", 3: "magenta"}.get(level, "white")
            out.append(_ANSI["bold"] + _ANSI[color] + "#" * level + " "
                       + _md_inline(m.group(2)) + _ANSI["reset"])
            continue
        if re.match(r"^([-*_])\1{2,}$", stripped):            # horizontal rule
            out.append(_ANSI["gray"] + line + _ANSI["reset"])
            continue
        if stripped.startswith(">"):                            # blockquote
            out.append(_ANSI["gray"] + _md_inline(line) + _ANSI["reset"])
            continue
        bm = re.match(r"^(\s*)([-*+]|\d+\.)\s+(.*)$", line)  # lists
        if bm:
            indent, marker, rest = bm.group(1), bm.group(2), bm.group(3)
            if marker.endswith("."):
                mark = _ANSI["bold"] + _ANSI["yellow"] + marker + _ANSI["reset"]
            else:
                mark = _ANSI["cyan"] + marker + _ANSI["reset"]
            out.append(f"{indent}{mark} " + _md_inline(rest) + _ANSI["reset"])
            continue
        out.append(_md_inline(line))
    return "\n".join(out)


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
def main():
    cfg = parse_args()

    # --- model browsing / default selection (no API key needed) -----------
    if cfg.list_models:
        try:
            free = fetch_free_models(cfg.api_url)
        except Exception as e:
            print(f"error: could not fetch model list from {cfg.api_url}: {e}",
                  file=sys.stderr)
            sys.exit(1)
        if not free:
            print("no free chat models found on OpenRouter right now",
                  file=sys.stderr)
            sys.exit(1)
        rec = free[0]
        print("Free chat models OpenRouter auto-picks from "
              "(ranked for fast summarization):")
        for m in free:
            tag = "  <- preferred (fast midrange)" if m["id"] == rec["id"] else ""
            print(f"  {m['context_length']:>8}  {m['id']}{tag}")
        print()
        print("  ranking: context sweet spot 128k-262k, non-reasoning, small ")
        print("  active params first; giant 500B+/1M-context models are only ")
        print("  failover. Auto fails over to the next if one is unavailable.")
        print("  optional one-off override: yt-summarize -m <id> URL")
        return 0

    if not cfg.urls:
        print("error: no URL given (try -h, or --list-models)", file=sys.stderr)
        sys.exit(2)
    if cfg.chunk is not None and cfg.chunk < 1:
        print("error: invalid chunk size", file=sys.stderr)
        sys.exit(2)
    if cfg.max_tokens < 1:
        print("error: invalid max tokens", file=sys.stderr)
        sys.exit(2)

    import shutil
    for tool in ("yt-dlp",):
        if shutil.which(tool) is None:
            print(f"error: {tool} not found (declared in modules/packages.nix — "
                  "rebuild to install)", file=sys.stderr)
            sys.exit(2)

    key = get_key()
    if not key:
        print("error: OpenRouter API key not found", file=sys.stderr)
        print(f"  set OPENROUTER_API_KEY, or write your key (outside this repo) to:",
              file=sys.stderr)
        print(f"    {KEY_FILE}", file=sys.stderr)
        print("  one-time setup:", file=sys.stderr)
        print(f"    mkdir -p {os.path.dirname(KEY_FILE)}", file=sys.stderr)
        print(f"    printf '%s\\n' 'sk-or-v1-...' > {KEY_FILE} && chmod 600 {KEY_FILE}",
              file=sys.stderr)
        print("  get a free key: https://openrouter.ai/keys", file=sys.stderr)
        sys.exit(2)

    cfg.models, how, cfg.models_ctx = resolve_models(cfg.api_url, cfg.model)
    cfg.chunk_size = compute_chunk_size(cfg)
    extra = f" (+{len(cfg.models) - 1} failover candidates)" \
        if len(cfg.models) > 1 else ""
    cs = f", chunk {cfg.chunk_size or 60000} chars" if not cfg.chunk else ""
    print(f"model: {cfg.models[0]} [{how}]{extra}{cs}", file=sys.stderr)

    for url in cfg.urls:
        print(f"== {url}", file=sys.stderr)
        try:
            title, uploader, duration = fetch_meta(url)
        except RuntimeError as e:
            print(f"error: {e}", file=sys.stderr)
            continue
        print(f"◉ {title} — {uploader} ({duration})", file=sys.stderr)

        with tempfile.TemporaryDirectory(prefix="yt-sum-") as tmp:
            vtt = fetch_vtt(url, cfg.lang, tmp)
            if not vtt:
                print(f"error: no {cfg.lang} subtitles found for \"{title}\" "
                      "(try -l with another language)", file=sys.stderr)
                continue
            transcript = clean_vtt(vtt)
        if not transcript:
            print(f"error: {cfg.lang} subtitles exist but cleaned transcript is empty",
                  file=sys.stderr)
            continue

        try:
            print(render_markdown(
                summarize_transcript(cfg, key, title, uploader, duration, transcript)))
        except (RuntimeError, ApiError) as e:
            print(f"error: {e}", file=sys.stderr)
        print(file=sys.stderr)


if __name__ == "__main__":
    main()
