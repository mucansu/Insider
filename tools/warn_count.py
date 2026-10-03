#!/usr/bin/env python3
"""GDScript warning count and gate (IS-047). Modifies no file. Python standard library only.

Usage:
    python tools/warn_count.py [--gate] [--json build/warn_count.json] [--top 10] [--timeout 300] [--quiet | --brief]

Gate (--gate): any warning of a kind at level 2 (error) in project.godot exits with code 2 and prints the locations to
stderr; kinds at level 0/1 are only counted as information. Two Godot runs (tools/warn_count.gd):
  1) Scan without the debugger (`-- --gate-only`): `SCRIPT ERROR: Parse Error: ... (Warning treated as error.)` lines are
     level-2 violations (the gate); any other `SCRIPT ERROR` line is a script error. If either exists run 2 is skipped (under
     `-d` an analysis error stops the local debugger and the process hangs; on "Debugger Break" the process is killed at once).
  2) Count (`-d`): Godot 4.7 `--import` / `--check-only` print no GDScript warnings, so tools/warn_count.gd re-analyses all .gd
     files with every warning kind set to 1 in memory and emits one `@@WC_JSON {...}` line, which this tool counts by kind and file:
  - per kind: the project.godot level (0 off / 1 warn / 2 error) and production / test / other counts; level-0 kinds are listed
    separately as "off (info)" (how many warnings they would give if enabled).
  - groups: production = autoload, core, entities, levels, ui, data and root scripts; test = tests/; other = the rest (e.g. tools/).
  - the --top files with the most warnings (only kinds at level >= 1 count).
The JSON report (--json, default build/warn_count.json; build/ is gitignored) has all the data and every warning's line.

Exit code: 0 count taken (and with --gate the gate passed); 1 Godot run failed, timed out, debugger stopped, script error or no
@@WC_JSON line (also a level-2 violation without --gate); 2 gate (--gate): a warning of a level-2 kind exists.
Godot: GODOT environment variable, else tools/get_godot.sh. On timeout the process tree is killed.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import threading
import time
from collections import Counter
from typing import Any

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

from net_smoke import ANSI, find_godot, kill_process_tree, popen_group_kwargs  # noqa: E402

JSON_MARKER = "@@WC_JSON "
SCRIPT = "res://tools/warn_count.gd"
PRODUCTION_DIRS = ("autoload", "core", "entities", "levels", "ui", "data")
GROUPS = ("uretim", "test", "diger")
LEVEL_NAMES = {0: "kapalı", 1: "uyar", 2: "hata"}
DEFAULT_JSON = os.path.join("build", "warn_count.json")
DEFAULT_TIMEOUT = 300.0
SCRIPT_ERROR = re.compile(r"^SCRIPT ERROR: (.*)$")
AT_LINE = re.compile(r"^at: .*\((res://[^)]*?):(\d+)\)")
HARD_SUFFIX = "(Warning treated as error.)"
DEBUG_BREAK = "Debugger Break"


def group_of(path: str) -> str:
    """Group of a res:// path: production (PRODUCTION_DIRS or a root script), test (tests/) or other."""
    rel = path[len("res://"):] if path.startswith("res://") else path
    parts = rel.split("/")
    if len(parts) == 1:
        return "uretim"
    if parts[0] in PRODUCTION_DIRS:
        return "uretim"
    if parts[0] == "tests":
        return "test"
    return "diger"


def extract_payload(lines: list[str]) -> dict[str, Any] | None:
    """Parses the last `@@WC_JSON {...}` line of Godot output (ANSI codes stripped); None if absent."""
    payload = None
    for raw in lines:
        line = ANSI.sub("", raw).strip()
        if line.startswith(JSON_MARKER):
            payload = json.loads(line[len(JSON_MARKER):])
    return payload


def aggregate(payload: dict[str, Any], top: int = 10) -> dict[str, Any]:
    """Report from warn_count.gd output: by kind (level + group counts), by file, top offenders."""
    levels: dict[str, int] = {str(k): int(v) for k, v in payload.get("levels", {}).items()}
    files: list[str] = list(payload.get("files", []))
    warnings: list[dict[str, Any]] = list(payload.get("warnings", []))

    file_groups = Counter(group_of(f) for f in files)
    by_type: dict[str, dict[str, Any]] = {}
    for name in sorted(set(levels) | {str(w["type"]) for w in warnings}):
        by_type[name] = {"level": levels.get(name, -1), **{g: 0 for g in GROUPS}, "toplam": 0}
    by_file: dict[str, dict[str, Any]] = {}
    for w in warnings:
        name, path = str(w["type"]), str(w["file"])
        group = group_of(path)
        t = by_type[name]
        t[group] += 1
        t["toplam"] += 1
        f = by_file.setdefault(path, {"group": group, "etkin": 0, "toplam": 0, "types": {}})
        f["toplam"] += 1
        f["types"][name] = f["types"].get(name, 0) + 1
        if levels.get(name, 0) >= 1:
            f["etkin"] += 1

    def totals(active: bool) -> dict[str, int]:
        out = {g: 0 for g in GROUPS}
        for t in by_type.values():
            if (t["level"] >= 1) == active:
                for g in GROUPS:
                    out[g] += t[g]
        out["toplam"] = sum(out[g] for g in GROUPS)
        return out

    ranked = sorted(
        ((p, f) for p, f in by_file.items() if f["etkin"] > 0), key=lambda pf: (-pf[1]["etkin"], pf[0])
    )
    return {
        "godot": payload.get("godot", ""),
        "dosya_sayisi": {g: file_groups.get(g, 0) for g in GROUPS},
        "etkin_toplam": totals(True),
        "kapali_toplam": totals(False),
        "turler": by_type,
        "dosyalar": by_file,
        "en_cok": [{"file": p, **f} for p, f in ranked[:top]],
        "en_cok_uretim": [{"file": p, **f} for p, f in ranked if f["group"] == "uretim"][:top],
        "hatalar": list(payload.get("errors", [])),
        "kayip": int(payload.get("stray", 0)),
        "uyarilar": warnings,
    }


def render_text(report: dict[str, Any]) -> str:
    """Short text summary: active kinds, off kinds (info), files with the most warnings, load errors."""
    n = report["dosya_sayisi"]
    out = [
        f"Uyarı sayımı ({report['godot']}): {sum(n.values())} betik "
        f"(üretim {n['uretim']}, test {n['test']}, diğer {n['diger']})"
    ]
    head = f"  {'tür':<34} {'düzey':<7} {'üretim':>6} {'test':>6} {'diğer':>6} {'toplam':>6}"

    def rows(active: bool) -> list[str]:
        items = [
            (k, t) for k, t in report["turler"].items() if (t["level"] >= 1) == active and t["toplam"] > 0
        ]
        items.sort(key=lambda kt: (-kt[1]["toplam"], kt[0]))
        return [
            f"  {k:<34} {LEVEL_NAMES.get(t['level'], '?'):<7} {t['uretim']:>6} {t['test']:>6} {t['diger']:>6} "
            f"{t['toplam']:>6}"
            for k, t in items
        ]

    for active, title, key in ((True, "Etkin türler (düzey >= 1)", "etkin_toplam"),
                               (False, "Kapalı türler (düzey 0; açılsa, bilgi)", "kapali_toplam")):
        tot = report[key]
        out.append(f"{title}: toplam {tot['toplam']} (üretim {tot['uretim']}, test {tot['test']}, "
                   f"diğer {tot['diger']})")
        body = rows(active)
        out.extend([head, *body] if body else ["  (yok)"])
    for key, title in (("en_cok", "dosya"), ("en_cok_uretim", "üretim dosyası")):
        out.append(f"En çok uyarı veren {len(report[key])} {title} (etkin sayı; ayrıntıda kapalı türler de var):")
        for f in report[key]:
            detail = ", ".join(f"{k} {v}" for k, v in sorted(f["types"].items(), key=lambda kv: (-kv[1], kv[0])))
            out.append(f"  {f['etkin']:>4}  {f['file']}  [{f['group']}]  {detail}")
        if not report[key]:
            out.append("  (yok)")
    if report["hatalar"]:
        out.append(f"Yükleme hataları ({len(report['hatalar'])}):")
        out.extend(f"  {e.get('file')}:{e.get('line')}  {e.get('message')}" for e in report["hatalar"])
    if report["kayip"]:
        out.append(f"Not: yüklenen dosyaya ait olmayan {report['kayip']} uyarı sayılmadı (bağımlılık yeniden çözümlendi).")
    return "\n".join(out)


def render_brief(report: dict[str, Any]) -> str:
    """One-line summary (--brief, IS-090): script count, active/off warning totals, load error count."""
    n = report["dosya_sayisi"]
    on, off = report["etkin_toplam"], report["kapali_toplam"]
    line = (f"Uyarı sayımı: {sum(n.values())} betik; etkin {on['toplam']} (üretim {on['uretim']}), "
            f"kapalı {off['toplam']} (bilgi)")
    if report["hatalar"]:
        line += f"; yükleme hatası {len(report['hatalar'])}"
    return line


def gate_violations(report: dict[str, Any]) -> list[dict[str, Any]]:
    """Gate: warnings of kinds at level 2 (error) in project.godot (all groups); the gate passes if empty."""
    hard = {k for k, t in report["turler"].items() if t["level"] >= 2}
    return [w for w in report["uyarilar"] if str(w["type"]) in hard]


def parse_script_errors(lines: list[str]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """`SCRIPT ERROR:` lines of the run without the debugger (+ the following `at: ... (res://path:line)`).
    Returns (hard, other): hard = analysis errors ending in "(Warning treated as error.)" (a level-2 warning);
    other = remaining script errors. The same (file, line, message) counts once (a script that fails to load is
    re-analysed on every reference)."""
    hard: list[dict[str, Any]] = []
    other: list[dict[str, Any]] = []
    seen: set[tuple[str, int, str]] = set()
    clean = [ANSI.sub("", raw).strip() for raw in lines]
    for i, line in enumerate(clean):
        m = SCRIPT_ERROR.match(line)
        if not m:
            continue
        message = m.group(1).strip()
        path, lineno = "", 0
        at = AT_LINE.match(clean[i + 1]) if i + 1 < len(clean) else None
        if at:
            path, lineno = at.group(1), int(at.group(2))
        key = (path, lineno, message)
        if key in seen:
            continue
        seen.add(key)
        if message.endswith(HARD_SUFFIX):
            text = message[: -len(HARD_SUFFIX)].strip()
            text = text[len("Parse Error:"):].strip() if text.startswith("Parse Error:") else text
            hard.append({"file": path, "line": lineno, "message": text})
        else:
            other.append({"file": path, "line": lineno, "message": message})
    return hard, other


def run_godot(godot: str, timeout: float, debug: bool) -> tuple[int | None, list[str], bool]:
    """Runs warn_count.gd: with debug a `-d` count, otherwise a `-- --gate-only` scan.
    Returns (exit code or None if killed, output lines, whether the debugger stopped). Under `-d` on "Debugger Break"
    the process is killed without waiting (the local debugger waits on stdin and hangs)."""
    cmd = [godot, "--headless", *(["-d"] if debug else []), "--path", ROOT, "-s", SCRIPT]
    if not debug:
        cmd += ["--", "--gate-only"]
    popen = subprocess.Popen(
        cmd,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL,
        text=True,
        encoding="utf-8",
        errors="replace",
        **popen_group_kwargs(),
    )
    lines: list[str] = []
    broke = threading.Event()

    def read() -> None:
        assert popen.stdout is not None
        for raw in popen.stdout:
            line = raw.rstrip("\n")
            lines.append(line)
            if DEBUG_BREAK in line:
                broke.set()

    reader = threading.Thread(target=read, daemon=True)
    reader.start()
    deadline = time.monotonic() + timeout
    code: int | None = None
    while True:
        try:
            code = popen.wait(timeout=0.2)
            break
        except subprocess.TimeoutExpired:
            if broke.is_set() or time.monotonic() >= deadline:
                kill_process_tree(popen)
                code = None
                break
    reader.join(timeout=5.0)
    if popen.stdout is not None:
        popen.stdout.close()
    return code, lines, broke.is_set()


def run_failure(code: int | None, payload: dict[str, Any] | None, broke: bool) -> str:
    """Why the Godot run cannot be used; empty string if it can."""
    if broke:
        return "hata ayıklayıcı durdu (Debugger Break)"
    if code is None:
        return "zaman aşımı"
    if code != 0:
        return f"çıkış kodu {code}"
    return "" if payload is not None else "@@WC_JSON satırı yok"


def _fail(reason: str, lines: list[str]) -> int:
    print(f"warn_count: sayım alınamadı ({reason}). Son satırlar:", file=sys.stderr)
    for line in lines[-20:]:
        print("  " + ANSI.sub("", line), file=sys.stderr)
    return 1


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="GDScript uyarı sayımı ve düzey 2 kapısı.")
    ap.add_argument("--json", default=DEFAULT_JSON, help="JSON raporu yolu (köke göre; '' = yazma)")
    ap.add_argument("--top", type=int, default=10, help="en çok uyarı veren kaç dosya listelensin")
    ap.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT, help="her Godot koşusunun üst süresi (sn)")
    ap.add_argument("--quiet", action="store_true", help="metin özetini basma")
    ap.add_argument("--brief", action="store_true", help="tablolar yerine tek satır özet (ci_local kısa kipi)")
    ap.add_argument("--gate", action="store_true", help="düzeyi 2 olan türde uyarı varsa çıkış kodu 2")
    args = ap.parse_args(argv)
    godot = find_godot()

    # 1) Scan without the debugger: level-2 violations and analysis errors (under -d these hang the process).
    code, lines, broke = run_godot(godot, args.timeout, debug=False)
    hard, other = parse_script_errors(lines)
    if hard or other:
        if hard:
            print(f"warn_count KAPI: düzeyi 2 (hata) olan uyarı türlerinde {len(hard)} ihlal:", file=sys.stderr)
            for v in hard:
                print(f"  {v['file']}:{v['line']}  {v['message']}", file=sys.stderr)
        if other:
            print(f"warn_count: {len(other)} betik hatası:", file=sys.stderr)
            for v in other:
                print(f"  {v['file']}:{v['line']}  {v['message']}", file=sys.stderr)
        print("warn_count: sayım (-d koşusu) atlandı.", file=sys.stderr)
        return 2 if hard and args.gate else 1
    reason = run_failure(code, extract_payload(lines), broke)
    if reason:
        return _fail(reason, lines)

    # 2) Count: with -d, re-analysis with all kinds set to 1 in memory.
    code, lines, broke = run_godot(godot, args.timeout, debug=True)
    payload = extract_payload(lines)
    reason = run_failure(code, payload, broke)
    if reason or payload is None:
        return _fail(reason, lines)
    report = aggregate(payload, args.top)
    if args.json:
        path = args.json if os.path.isabs(args.json) else os.path.join(ROOT, args.json)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(report, fh, ensure_ascii=False, indent=1)
    if args.brief and not args.quiet:
        print(render_brief(report))
    elif not args.quiet:
        print(render_text(report))
        if args.json:
            print(f"JSON: {args.json}")
    if args.gate:
        bad = gate_violations(report)
        if bad:
            print(f"warn_count KAPI: düzeyi 2 (hata) olan türlerde {len(bad)} uyarı:", file=sys.stderr)
            for v in bad:
                print(f"  {v['file']}:{v['line']}  [{v['type']}]  {v['message']}", file=sys.stderr)
            return 2
        print("warn_count kapı: düzeyi 2 olan türlerde uyarı yok.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
