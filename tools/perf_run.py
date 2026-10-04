#!/usr/bin/env python3
"""Windowed performance run (IS-067; mimari.md S6 `--perf`). Python standard library only.

Usage:
    python tools/perf_run.py [--seconds 10] [--level res://levels/store_a.tscn] [--clients 1]
        [--windows host|all] [--bot host=res://... --bot c1=...] [--window-size 1280x720]
        [--out build/perf] [--name NAME] [--godot-gui PATH] [--verbose]

The host (GUI exe, GPU window) opens the level and clients join (headless console exe by default; `--windows all` makes all
windowed - they share the GPU, which skews the host measurement). Everyone runs with `--perf --perf-seconds=N`; the host writes its
dump and exits at `JOIN_SLACK_SEC + N` seconds, the measurement window is the last N seconds (clients are connected then; `peers` in
the host dump shows it). Clients write their dumps and exit when they lose the host (`--quit-after` is only a backup). Dumps are
`<out>/<name>/<peer>.json`; a summary table is printed at the end.

NOT part of CI (needs a window and GPU); with no display / in CI it prints "atlandı" and returns 0. If other Godot processes are
running on the same machine their count is printed as a warning (they load the measurement).
Exit code: 0 if the processes ended with code 0, no ERROR in the log and the host's "render" section is valid; otherwise 1.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from typing import Any

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

from net_smoke import ERROR_LINE, HOST_READY_TIMEOUT, WINDOWS, Proc, find_godot, free_udp_port  # noqa: E402
from screenshot import (  # noqa: E402
    WINDOW_CASCADE,
    WINDOW_ORIGIN,
    display_skip_reason,
    parse_kv,
    parse_window_size,
    peer_names,
    resolve_gui_godot,
)

DEFAULT_LEVEL = "res://levels/store_a.tscn"
DEFAULT_BOT = "res://tests/net/bots/wander.json"
DEFAULT_OUT = os.path.join("build", "perf")
DEFAULT_SECONDS = 10.0
# Margin before the host's measurement window for clients to join and the game to warm up (main.gd PERF_WARMUP_SEC=1).
JOIN_SLACK_SEC = 3.0
# Clients' backup exit: this long after the host (normally they exit earlier on losing the host).
CLIENT_BACKSTOP_SEC = 5.0
# Same as Args PERF_SECONDS_MIN/MAX.
PERF_SECONDS_RANGE = (1.0, 600.0)
# Same as core/perf_report.gd RENDER_ONLY_KEYS (not measured in headless).
RENDER_ONLY = {"process_total_ms", "draw_calls", "objects", "primitives", "render_cpu_ms", "render_gpu_ms", "frame_setup_ms"}

# Table columns: (header, dump path, format). A path "a.b" is a nested key.
COLUMNS: list[tuple[str, str, str]] = [
    ("fps ort", "fps.avg", "{:.0f}"),
    ("fps %1", "fps.p1_low", "{:.0f}"),
    ("kare p50", "frame_ms.p50", "{:.2f}"),
    ("kare p95", "frame_ms.p95", "{:.2f}"),
    ("kare p99", "frame_ms.p99", "{:.2f}"),
    ("draw", "draw_calls.avg", "{:.0f}"),
    ("nesne", "objects.avg", "{:.0f}"),
    ("ilkel", "primitives.avg", "{:.0f}"),
    ("process", "process_ms.avg", "{:.2f}"),
    ("process max", "process_ms.max", "{:.2f}"),
    ("physics", "physics_ms.avg", "{:.2f}"),
    ("işleme", "process_total_ms.avg", "{:.2f}"),
    ("işleme p95", "process_total_ms.p95", "{:.2f}"),
    ("motor 1sn max", "process_max_1s_ms.max", "{:.2f}"),
    ("rcpu", "render_cpu_ms.avg", "{:.2f}"),
    ("rgpu", "render_gpu_ms.avg", "{:.2f}"),
    ("rgpu p95", "render_gpu_ms.p95", "{:.2f}"),
]


def parse_seconds(text: str) -> float:
    try:
        v = float(text)
    except ValueError:
        raise ValueError(f"saniye bir sayı olmalı: {text!r}") from None
    lo, hi = PERF_SECONDS_RANGE
    if not (lo <= v <= hi):
        raise ValueError(f"saniye {lo:g}..{hi:g} aralığında olmalı: {text!r}")
    return v


def host_quit_after(seconds: float) -> float:
    return JOIN_SLACK_SEC + seconds


def peer_args(name: str, port: int, level: str, seconds: float, dump: str, bot: str | None,
              window: tuple[int, int] | None) -> list[str]:
    """Godot user arguments (after `--`) - S6."""
    user = [f"--name={name}", "--perf", f"--perf-seconds={seconds:g}", f"--dump={dump}"]
    if name == "host":
        user += ["--host", f"--port={port}", f"--level={level}", f"--quit-after={host_quit_after(seconds):g}"]
    else:
        user += ["--join=127.0.0.1", f"--port={port}",
                 f"--quit-after={host_quit_after(seconds) + CLIENT_BACKSTOP_SEC:g}"]
    if bot:
        user.append(f"--bot={bot}")
    if window is not None:
        user.append(f"--window-size={window[0]}x{window[1]}")
    return user


def dig(data: Any, path: str) -> Any:
    for part in path.split("."):
        if not isinstance(data, dict) or part not in data:
            return None
        data = data[part]
    return data


def fmt(value: Any, spec: str) -> str:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return "-"
    return spec.format(value)


def summary_rows(dumps: dict[str, dict | None]) -> list[list[str]]:
    """Table row per peer: peer, mode, peers, then COLUMNS. In headless the renderer columns are "-"."""
    rows: list[list[str]] = []
    for name, dump in dumps.items():
        render = dump.get("render") if isinstance(dump, dict) else None
        if not isinstance(render, dict):
            rows.append([name, "döküm yok"] + ["-"] * (len(COLUMNS) + 1))
            continue
        headless = bool(render.get("headless"))
        mode = "headless" if headless else "pencere"
        peers = dump.get("peers") if isinstance(dump, dict) else None
        row = [name, mode, str(len(peers)) if isinstance(peers, list) else "-"]
        for _title, path, spec in COLUMNS:
            key = path.split(".")[0]
            if headless and key in RENDER_ONLY:
                row.append("-")
            else:
                row.append(fmt(dig(render, path), spec))
        rows.append(row)
    return rows


def format_table(rows: list[list[str]]) -> str:
    header = ["peer", "kip", "peers"] + [c[0] for c in COLUMNS]
    widths = [max(len(header[i]), *(len(r[i]) for r in rows)) if rows else len(header[i]) for i in range(len(header))]
    lines = ["  ".join(h.ljust(widths[i]) for i, h in enumerate(header))]
    lines.append("  ".join("-" * w for w in widths))
    for r in rows:
        lines.append("  ".join(c.rjust(widths[i]) if i >= 2 else c.ljust(widths[i]) for i, c in enumerate(r)))
    return "\n".join(lines)


def describe_machine(render: dict) -> str:
    """One-line environment description from the host dump."""
    win = render.get("window") or ["?", "?"]
    vsync = {0: "kapalı", 1: "açık", 2: "uyarlamalı", 3: "mailbox"}.get(render.get("vsync"), str(render.get("vsync")))
    return (f"GPU: {render.get('adapter') or '?'} ({render.get('vendor') or '?'}) · {render.get('renderer')}/"
            f"{render.get('driver')} · API {render.get('api_version') or '?'} · pencere {win[0]}x{win[1]} · "
            f"ekran {render.get('refresh_hz')} Hz · vsync {vsync} · max_fps {render.get('max_fps')} · "
            f"ölçüm {render.get('measured_s')}/{render.get('window_s')} sn, {render.get('frames')} kare")


def host_problems(dump: dict | None) -> list[str]:
    render = dump.get("render") if isinstance(dump, dict) else None
    if not isinstance(render, dict):
        return ["host dökümünde render bölümü yok"]
    out: list[str] = []
    if render.get("headless"):
        out.append("host headless koştu (pencere yok)")
    if not render.get("valid"):
        out.append("host render ölçümü geçersiz (valid=false)")
    return out


def count_other_godot() -> int:
    """Number of Godot processes open on the machine before the run (best effort; -1 if it cannot be counted)."""
    try:
        if WINDOWS:
            out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True, timeout=10,
                                 errors="replace").stdout
            return sum(1 for line in out.splitlines() if re.match(r'^"Godot[^"]*\.exe"', line, re.I))
        out = subprocess.run(["ps", "-A", "-o", "comm="], capture_output=True, text=True, timeout=10).stdout
        return sum(1 for line in out.splitlines() if line.strip().lower().startswith("godot"))
    except (OSError, subprocess.SubprocessError):
        return -1


def run(args: argparse.Namespace) -> int:
    skip = display_skip_reason()
    if skip:
        print(f"atlandı perf_run: {skip}")
        return 0
    seconds = parse_seconds(str(args.seconds))
    window = parse_window_size(args.window_size)
    clients = args.clients
    names = peer_names(clients)
    bots = {n: DEFAULT_BOT for n in names}
    bots.update(parse_kv(args.bot, "--bot"))
    unknown = sorted(set(bots) - set(names))
    if unknown:
        raise ValueError(f"--bot: bilinmeyen peer {', '.join(unknown)}")
    windowed = set(names) if args.windows == "all" else {"host"}
    name = args.name or os.path.splitext(os.path.basename(args.level))[0]
    out_dir = os.path.join(args.out if os.path.isabs(args.out) else os.path.join(ROOT, args.out), name)
    os.makedirs(out_dir, exist_ok=True)
    gdignore = os.path.join(os.path.dirname(out_dir), ".gdignore")
    if not os.path.exists(gdignore):
        open(gdignore, "w", encoding="utf-8").close()
    gui = resolve_gui_godot(args.godot_gui)
    console = find_godot()
    tmp = tempfile.mkdtemp(prefix="perf_run_")
    others = count_other_godot()
    port = free_udp_port()
    procs: dict[str, Proc] = {}
    failures: list[str] = []
    t_begin = time.monotonic()

    def make(peer: str, index: int) -> Proc:
        dump = os.path.join(out_dir, f"{peer}.json")
        if os.path.exists(dump):
            os.remove(dump)
        log = ["--log-file", os.path.join(tmp, f"{peer}.godot.log")]
        if peer in windowed:
            pos = (WINDOW_ORIGIN[0] + WINDOW_CASCADE[0] * index, WINDOW_ORIGIN[1] + WINDOW_CASCADE[1] * index)
            cmd = [gui, "--path", ROOT, "--position", f"{pos[0]},{pos[1]}"] + log + ["--"]
            user = peer_args(peer, port, args.level, seconds, dump, bots.get(peer), window)
        else:
            cmd = [console, "--headless", "--path", ROOT] + log + ["--"]
            user = peer_args(peer, port, args.level, seconds, dump, bots.get(peer), None)
        qa = host_quit_after(seconds) + (0.0 if peer == "host" else CLIENT_BACKSTOP_SEC)
        return Proc(name=peer, cmd=cmd + user, dump_path=dump, quit_after=qa)

    print(f"perf_run {name}: {seconds:g} sn ölçüm, host pencereli, {clients} istemci "
          f"({'pencereli' if args.windows == 'all' else 'headless'})")
    if others > 0:
        print(f"  UYARI: koşudan önce {others} Godot süreci açık (başka iş yük bindirebilir; ölçüm gürültülü)")
    try:
        host = make("host", 0)
        procs["host"] = host
        host.start()
        while not host.ready.wait(0.05):
            if host.popen is not None and host.popen.poll() is not None:
                break
            if time.monotonic() - host.started_at > HOST_READY_TIMEOUT:
                break
        if not host.ready.is_set():
            failures.append(f"host {HOST_READY_TIMEOUT:g} sn içinde hazır olmadı")
        else:
            for i, peer in enumerate(names[1:], start=1):
                proc = make(peer, i)
                procs[peer] = proc
                proc.start()
        deadline = max(p.started_at + p.quit_after for p in procs.values()) + 15.0
        for proc in procs.values():
            assert proc.popen is not None
            try:
                proc.popen.wait(timeout=max(0.1, deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                pass
    finally:
        for proc in procs.values():
            proc.kill()
            proc.finish()

    dumps: dict[str, dict | None] = {}
    for proc in procs.values():
        if proc.killed:
            failures.append(f"{proc.name} zaman aşımında öldürüldü")
        elif proc.exit_code != 0:
            failures.append(f"{proc.name} çıkış kodu {proc.exit_code}")
        for line in proc.lines:
            if ERROR_LINE.match(line):
                failures.append(f"{proc.name} log hatası: {line.strip()}")
        try:
            with open(proc.dump_path, encoding="utf-8") as f:
                dumps[proc.name] = json.load(f)
        except (OSError, ValueError):
            dumps[proc.name] = None
    failures += host_problems(dumps.get("host"))
    shutil.rmtree(tmp, ignore_errors=True)

    ok = not failures
    print(f"{'PASS' if ok else 'FAIL'} perf_run {name}: {time.monotonic() - t_begin:.1f} sn")
    host_render = dig(dumps.get("host"), "render")
    if isinstance(host_render, dict):
        print("  " + describe_machine(host_render))
    print(format_table(summary_rows(dumps)))
    print("  (süreler ms. process/physics: kare başına ölçülen _process/_physics_process süresi, 0,25 sn aralık "
          "ortalamalarının ortalaması; 'max' tek karenin tepesi. işleme: tüm işleme adımı (geri çağrılar + ertelenmiş "
          "çağrılar + _draw kaydı; yalnız pencere). 'motor 1sn max' = Performance.TIME_PROCESS: motor "
          "saniyede bir günceller, son saniyenin en kötü karesi — kare başı değil. fps %1 = en yavaş %1 karenin eşiği)")
    for path in sorted(p.dump_path for p in procs.values()):
        print(f"  döküm: {os.path.relpath(path, ROOT)}")
    for text in failures:
        print(f"  FAIL {text}")
    if args.verbose or not ok:
        for proc in procs.values():
            print(f"----- {proc.name} log -----")
            print("\n".join(proc.lines) if proc.lines else "(boş)")
    return 0 if ok else 1


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Pencereli performans koşusu ve özet tablo (IS-067, S6 --perf)")
    ap.add_argument("--seconds", default=str(DEFAULT_SECONDS), help=f"ölçüm penceresi, sn [{DEFAULT_SECONDS:g}]")
    ap.add_argument("--level", default=DEFAULT_LEVEL, help=f"res:// seviye [{DEFAULT_LEVEL}]")
    ap.add_argument("--clients", type=int, default=1, help="istemci sayısı [1]")
    ap.add_argument("--windows", choices=("host", "all"), default="host", help="pencereli peer'lar [host]")
    ap.add_argument("--bot", action="append", default=[], help=f"PEER=res://...json (varsayılan {DEFAULT_BOT})")
    ap.add_argument("--window-size", default="1280x720", help="pencere boyutu [1280x720]")
    ap.add_argument("--out", default=DEFAULT_OUT, help=f"döküm kökü [{DEFAULT_OUT}]")
    ap.add_argument("--name", help="alt dizin adı (varsayılan seviye adı)")
    ap.add_argument("--godot-gui", help="pencereli Godot exe (yoksa GODOT_GUI ya da GODOT'un *_console kardeşi)")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args(argv)
    # When writing to a pipe (e.g. Git Bash, CI) the local code page must not garble Turkish characters.
    if not sys.stdout.isatty() and hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if args.clients < 0:
        ap.error("istemci sayısı >= 0 olmalı")
    try:
        return run(args)
    except ValueError as e:
        ap.error(str(e))
    return 2


if __name__ == "__main__":
    sys.exit(main())
