#!/usr/bin/env python3
# =============================================================================
# yt-summarize — download YouTube captions with yt-dlp, summarize them with
#                OpenRouter's FREE model router ("openrouter/free")
# =============================================================================
# Usage:
#   yt-summarize <youtube-url> [more urls...]
#   yt-summarize -l de <url>                  # subtitles in German
#   yt-summarize -m "some/vendor:model:free" <url>   # pin a specific model
#
# How it works:
#   1. yt-dlp downloads the video's subtitles (manual captions preferred,
#      auto-generated ASR fallback) as VTT into a temp dir.
#   2. The VTT is cleaned (timestamps, tags, HTML entities) to plain text.
#   3. Transcripts longer than YT_SUM_CHUNK chars are split into chunks; each
#      chunk is summarized ("map"), then the part-summaries are combined into
#      one final summary ("reduce").
#   4. The model defaults to "openrouter/free" — OpenRouter's router that
#      AUTOMATICALLY picks a free (:free) model per request, so no model
#      pinning is needed. Override with -m or YT_SUM_MODEL.
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
#   YT_SUM_MODEL         model id (default: openrouter/free)
#   YT_SUM_LANG          subtitle language (default: en)
#   YT_SUM_CHUNK         max chars per map chunk (default: 60000)
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
    p.add_argument("-m", "--model", default=os.environ.get("YT_SUM_MODEL", "openrouter/free"),
                   help="model id (default: openrouter/free)")
    p.add_argument("-c", "--chunk", type=int,
                   default=int(os.environ.get("YT_SUM_CHUNK", "60000")),
                   help="max chars per map chunk (default: 60000)")
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
def call_api(api_url, model, max_tokens, key, sys_prompt, user_prompt):
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
            retryable = e.code == 429 or e.code >= 500
            if retryable and attempt < 4:
                print(f"  openrouter: HTTP {e.code} — retrying in {3 * attempt}s "
                      f"({errmsg})", file=sys.stderr)
                time.sleep(3 * attempt)
                continue
            raise RuntimeError(f"OpenRouter API HTTP {e.code}: {errmsg}")
        except urllib.error.URLError as e:
            if attempt < 4:
                print(f"  openrouter: network error ({e.reason}) — retrying in "
                      f"{3 * attempt}s", file=sys.stderr)
                time.sleep(3 * attempt)
                continue
            raise RuntimeError(f"OpenRouter API unreachable: {e.reason}")
    choice = (data.get("choices") or [{}])[0] or {}
    content = (choice.get("message") or {}).get("content") or ""
    model_used = data.get("model", "")
    total = ((data.get("usage") or {}).get("total_tokens") or "")
    if model_used:
        print(f"  ↳ resolved model: {model_used}"
              + (f" ({total} tokens)" if total else ""), file=sys.stderr)
    if not content:
        print("  warning: empty assistant response", file=sys.stderr)
    return content


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
    chunks = chunk_text(transcript, cfg.chunk)
    n = len(chunks)
    if n == 0:
        raise RuntimeError("empty transcript")

    def video_hdr():
        return f"Video: {title}\nChannel: {uploader}\nDuration: {duration}"

    if n == 1:
        user = (f"{video_hdr()}\n\nFull transcript:\n\n{transcript}\n\n"
                "Produce the final summary: a 2-3 sentence TL;DR, then "
                '"## Key Points" as deduplicated bullets that keep names, '
                'numbers and terms, then optional "## Notable Details", then '
                '"## Bottom Line" (1-2 sentences). Use Markdown.')
        return call_api(cfg.api_url, cfg.model, cfg.max_tokens, key,
                        SYS_PROMPT, user)

    # map phase
    parts = []
    for i, chunk in enumerate(chunks, 1):
        print(f"  summarizing part {i}/{n} ({len(chunk)} chars)...",
              file=sys.stderr)
        user = (f"Video: {title}\n\nPart {i}/{n} of the transcript:\n\n"
                f"{chunk}\n\nSummarize THIS PART in concise bullet points: "
                "key topics, names, numbers and conclusions. Be thorough but "
                "do not add outside information.")
        part = call_api(cfg.api_url, cfg.model, cfg.max_tokens, key,
                        SYS_PROMPT, user)
        parts.append(f"[{i}/{n}] {part}")

    # reduce phase
    joined = "\n\n".join(parts)
    user = (f"{video_hdr()}\n\nHere are the {n} part-summaries of the "
            f"transcript:\n\n{joined}\n\nCombine them into the FINAL summary: "
            'a 2-3 sentence TL;DR, then "## Key Points" as deduplicated '
            'bullets that keep specifics, then optional "## Notable Details", '
            'then "## Bottom Line" (1-2 sentences). Use Markdown.')
    return call_api(cfg.api_url, cfg.model, cfg.max_tokens, key, SYS_PROMPT, user)


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
def main():
    cfg = parse_args()
    if not cfg.urls:
        print("error: no URL given (try -h)", file=sys.stderr)
        sys.exit(2)
    if cfg.chunk < 1:
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
        print(f"  transcript: {len(transcript)} chars", file=sys.stderr)

        try:
            print(summarize_transcript(cfg, key, title, uploader, duration, transcript))
        except RuntimeError as e:
            print(f"error: {e}", file=sys.stderr)
        print(file=sys.stderr)


if __name__ == "__main__":
    main()
