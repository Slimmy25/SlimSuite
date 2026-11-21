#!/usr/bin/env python3
"""Builds SlimSuite/SlimSuiteChangelog.lua from CHANGELOG.md, oldest release first, for the in-game Changelog page.
Run with --check to fail when the Lua file is out of date."""
import os, re, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = os.path.join(root, "CHANGELOG.md")
out = os.path.join(root, "SlimSuite", "SlimSuiteChangelog.lua")

def q(s):
    s = s.replace("|", "||")   # the game reads a single | as a colour code
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

def build():
    sections, cur = [], None
    for line in open(src, encoding="utf-8").read().splitlines():
        m = re.match(r"^## +(\S+)", line)
        if m:
            cur = {"v": m.group(1), "summary": "", "items": []}; sections.append(cur); continue
        if cur is None or not line.strip():
            continue
        text = re.sub(r"`([^`]*)`", r"\1", line.strip())
        text = re.sub(r"\*\*([^*]*)\*\*", r"\1", text)
        if line.lstrip().startswith(("- ", "* ")):
            cur["items"].append(text[2:].strip())
        elif cur["items"]:
            cur["items"][-1] += " " + text
        else:
            cur["summary"] = (cur["summary"] + " " + text).strip()
    sections.reverse()   # chronological: the first release first
    lines = ["-- Made by tools/make-changelog.py from CHANGELOG.md; do not edit by hand.",
             "if ( setfenv ) then setfenv(1, SS.ENV); end", "SS.CHANGELOG = {"]
    for s in sections:
        items = ", ".join(q(i) for i in s["items"])
        lines.append("\t{ v = %s, summary = %s, items = { %s } }," % (q(s["v"]), q(s["summary"]), items))
    lines.append("};")
    return "\n".join(lines) + "\n"

text = build()
if "--check" in sys.argv:
    old = open(out, encoding="utf-8").read() if os.path.exists(out) else ""
    if old != text:
        print("FAIL: SlimSuiteChangelog.lua is out of date; run python3 tools/make-changelog.py"); sys.exit(1)
    print("changelog page is up to date"); sys.exit(0)
open(out, "w", encoding="utf-8").write(text)
print("wrote", out)
