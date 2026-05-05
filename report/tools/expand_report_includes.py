#!/usr/bin/env python3
"""
Expand @include directives in Markdown report sources.

Typical entrypoint: report/main.template.md → report/main.md (see Makefile
target report).

Each line that matches (entire line):
  @include path/to/file.md
is replaced by the UTF-8 text of that file, resolved relative to the
**directory of the file that contains the @include** line.

Nested @include lines in included files are supported. Cycles raise an error.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

INCLUDE_RE = re.compile(r"^@include\s+(.+?)\s*$")


def expand_file(path: Path, chain: list[Path]) -> str:
    resolved = path.resolve()
    if resolved in chain:
        cycle = " -> ".join(str(p) for p in chain + [resolved])
        raise SystemExit(f"include cycle detected: {cycle}")

    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as e:
        raise SystemExit(f"cannot read {path}: {e}") from e

    chain.append(resolved)
    try:
        out: list[str] = []
        for line in raw.splitlines(keepends=True):
            if line.endswith("\r\n"):
                body, nl = line[:-2], "\r\n"
            elif line.endswith("\n"):
                body, nl = line[:-1], "\n"
            else:
                body, nl = line, ""

            m = INCLUDE_RE.match(body)
            if m:
                rel = m.group(1).strip()
                inc_path = (path.parent / rel).resolve()
                out.append(expand_file(inc_path, chain))
            else:
                out.append(line)
        return "".join(out)
    finally:
        chain.pop()


def main() -> None:
    p = argparse.ArgumentParser(description="Expand @include lines in a Markdown file.")
    p.add_argument("input", type=Path, help="Entry Markdown file (e.g. report/main.template.md)")
    p.add_argument("output", type=Path, help="Output path for expanded Markdown")
    args = p.parse_args()

    text = expand_file(args.input, [])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
