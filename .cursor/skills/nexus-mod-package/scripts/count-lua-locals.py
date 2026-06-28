#!/usr/bin/env python3
"""Check Lua files for the per-function 200 local variable limit (Lua MAXVARS)."""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

LIMIT = 200
LUAC_CANDIDATES = ("luac", "/opt/homebrew/bin/luac", "/usr/local/bin/luac")


def find_luac() -> str | None:
    for candidate in LUAC_CANDIDATES:
        path = shutil.which(candidate) if "/" not in candidate else candidate
        if path and Path(path).is_file():
            return path
    return None


def check_with_luac(luac: str, path: Path) -> tuple[bool | None, str | None]:
    proc = subprocess.run([luac, "-p", str(path)], capture_output=True, text=True)
    if proc.returncode == 0:
        return True, None
    err = (proc.stderr or proc.stdout or "").strip()
    if "too many local" in err.lower():
        return False, err
    return None, err or "luac compile failed"


def strip_comments_and_strings(code: str) -> str:
    out: list[str] = []
    i = 0
    n = len(code)
    while i < n:
        if code.startswith("--", i):
            while i < n and code[i] != "\n":
                i += 1
            continue
        if code[i] in ("'", '"'):
            quote = code[i]
            i += 1
            while i < n:
                if code[i] == "\\" and i + 1 < n:
                    i += 2
                    continue
                if code[i] == quote:
                    i += 1
                    break
                i += 1
            out.append(" ")
            continue
        if code.startswith("[[", i):
            end = code.find("]]", i + 2)
            if end == -1:
                break
            i = end + 2
            out.append(" ")
            continue
        out.append(code[i])
        i += 1
    return "".join(out)


def count_names_in_local_tail(tail: str) -> int:
    tail = tail.strip()
    if not tail:
        return 0
    if tail.startswith("function"):
        m = re.match(r"function\s+([A-Za-z_][\w.]*)", tail)
        return 1 if m else 0
    head = tail.split("=", 1)[0]
    head = re.sub(r"\bfunction\s+[A-Za-z_][\w.]*", "", head)
    return len([p for p in head.split(",") if p.strip()])


def parse_params(param_text: str) -> int:
    param_text = param_text.strip()
    if not param_text:
        return 0
    if param_text.startswith("..."):
        return 1
    return len([p for p in param_text.split(",") if p.strip()])


def push_block(stack: list[str], kind: str) -> None:
    stack.append(kind)


def pop_blocks(line: str, stack: list[str], func_counts: list[int]) -> None:
    if re.search(r"\buntil\b", line):
        if stack and stack[-1] == "repeat":
            stack.pop()
        return
    ends = len(re.findall(r"\bend\b", line))
    for _ in range(ends):
        if not stack:
            break
        kind = stack.pop()
        if kind == "function" and len(func_counts) > 1:
            func_counts.pop()


def open_function(func_counts: list[int], params: str, is_local_name: bool) -> None:
    if is_local_name:
        func_counts[-1] += 1
    func_counts.append(parse_params(params))
    return None


def max_locals_static(path: Path) -> int:
    code = strip_comments_and_strings(path.read_text(encoding="utf-8"))
    func_counts = [0]
    stack: list[str] = []

    for raw_line in code.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        fn_match = re.match(
            r"^(local\s+)?function\s+([A-Za-z_][\w.]*)\s*(\([^)]*\))?",
            line,
        )
        if fn_match:
            is_local = bool(fn_match.group(1))
            params = (fn_match.group(3) or "()")[1:-1]
            open_function(func_counts, params, is_local)
            push_block(stack, "function")
            continue

        if re.search(r"\bfunction\s*\(", line) and not fn_match:
            m = re.search(r"function\s*(\([^)]*\))", line)
            if m:
                open_function(func_counts, m.group(1)[1:-1], False)
                push_block(stack, "function")

        if re.match(r"^(local\s+)?function\b", line):
            pass
        elif re.match(r"^repeat\b", line):
            push_block(stack, "repeat")
        elif re.match(r"^(if|for|while|do)\b", line):
            push_block(stack, "block")

        for m in re.finditer(r"\blocal\b", line):
            if re.match(r"^local\s+function\b", line) and m.start() == 0:
                continue
            func_counts[-1] += count_names_in_local_tail(line[m.end() :])

        for vars_part in re.findall(
            r"\bfor\s+([A-Za-z_][\w.]*(?:\s*,\s*[A-Za-z_][\w.]*)*)\s+in\b",
            line,
        ):
            func_counts[-1] += len([v for v in re.split(r"\s*,\s*", vars_part.strip()) if v])

        for _ in re.findall(r"\bfor\s+([A-Za-z_][\w.]*)\s*=", line):
            func_counts[-1] += 1

        pop_blocks(line, stack, func_counts)

    return max(func_counts)


def check_file(path: Path, luac: str | None) -> tuple[int, str | None, str]:
    if luac:
        ok, err = check_with_luac(luac, path)
        if ok is True:
            count = max_locals_static(path)
            return count, None, "luac+static"
        if ok is False:
            return LIMIT + 1, err, "luac"
    count = max_locals_static(path)
    method = "static"
    if count > LIMIT:
        return count, f"static analysis: {count} locals in at least one function (limit {LIMIT})", method
    return count, None, method


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: count-lua-locals.py <file.lua>...", file=sys.stderr)
        return 2

    luac = find_luac()
    if not luac:
        print(
            "note: luac not found — using static analysis (install lua for compile-accurate check)",
            file=sys.stderr,
        )

    worst = 0
    failures: list[str] = []
    for arg in argv[1:]:
        path = Path(arg)
        count, err, method = check_file(path, luac)
        print(f"{path.name}: max {count} locals ({method})")
        worst = max(worst, count)
        if count > LIMIT:
            failures.append(f"{path}: {err or f'{count} locals exceeds limit of {LIMIT}'}")

    if failures:
        print("\nWARNING: Lua 200 local variable limit exceeded:", file=sys.stderr)
        for msg in failures:
            print(f"  - {msg}", file=sys.stderr)
        print(
            "\nUE4SS may fail to load these files. Refactor into tables, do/end blocks, or split modules.",
            file=sys.stderr,
        )
        return 1

    if worst >= LIMIT - 20:
        print(
            f"\nnote: highest count {worst}/{LIMIT} — approaching Lua local limit",
            file=sys.stderr,
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
