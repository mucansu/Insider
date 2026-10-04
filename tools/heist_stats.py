#!/usr/bin/env python3
"""Batch heist statistics with the closed-loop bot brain (IS-015b; mimari.md S6 + "S6 eki - kapalı döngü bot beyni").
Python standard library only. Answers "is the store easy alone / as a team?" with numbers.

Usage:
    python tools/heist_stats.py [--strategies rush,window,send,distract,buy] [--players 1] [--seeds 1-20]
        [--cell team:2,3:1-10 ...] [--jobs N] [--latency-ms 0] [--level res://levels/store_a.tscn]
        [--quit-after 240] [--run-timeout SEC] [--player-scene res://...] [--godot-arg ARG ...]
        [--out build/stats] [--dry-run] [-v]

Matrix = strategy cells x player counts x seeds. A strategy token is passed to Godot as a free string (`--brain=TOKEN`), suffixes
(`+bag`, later `+omni`) untouched; Godot validates it. A token with "/" sets one strategy per peer in join order (`rush/team/send`
= host rush, c1 team, c2 send) and fixes the player count to the number of parts. Otherwise every peer of an N-player run gets
the same token (`team` on 2-3 players: roles from join order, 0 lure, 1 thief, 2 bagger).
    --strategies/--players/--seeds   the main grid (every strategy x every player count x every seed)
    --cell STRATS:PLAYERS[:SEEDS]    extra grid (repeatable; ";"-free: e.g. `team:2,3:1-10`, `rush/send:2`); seeds default --seeds
Seeds: "1-50", "1,4,7-9". Every peer of a run gets `--seed=N` (brain RNG; after IS-058b also the NPC session seed on the host).

One run: free UDP port (process-wide allocator, no reuse inside one invocation) -> host `--headless --host --level --brain --seed
--dump --quit-on-heist-end --quit-after` -> wait INSIDERS_READY -> (if --latency-ms > 0 and clients exist: tools/latency_proxy.py
in between) -> clients one by one, each after the previous one printed INSIDERS_READY + JOIN_GAP_SEC (join order = team role) ->
wait for every process; hard per-run timeout (default quit_after + HARD_MARGIN_SEC), then the process tree is killed
(net_smoke.kill_process_tree; no hung Godot remains, also on Ctrl+C / SIGTERM). Process stagger on heist end: clients leave first
(HEIST_END_LINGER), the host last, so two clients never drop in the same host frame (net_smoke LEAVE_STAGGER note).
Parallel pool: --jobs = Godot process slots (default CPU count / 2); an N-player run holds N slots.

Output: build/stats/<YYYYmmdd-HHMMSS>/
    summary.md     Markdown table per (strategy cell, player count): n, outcome distribution %, mean payout, mean/p90 job
                   duration, mean max_alert, stuck runs, brain failures, runs with ERROR/WARNING log lines, harness problems
    runs.csv       one row per run (RUN_FIELDS)
    runs/<id>/     raw dumps (<proc>.json) and Godot logs (<proc>.log, `--log-file`)
The same table is printed to the console. Exit code: 0 = every run finished cleanly (a missing heist result is data, not a
failure); 1 = some run had a harness problem (killed on timeout, no dump, non-zero exit code); 2 = bad arguments.
"""

from __future__ import annotations

import argparse
import csv
import datetime as _dt
import json
import math
import os
import re
import signal
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from typing import Any, Callable, Iterable

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

from latency_proxy import LatencyProxy  # noqa: E402
from net_smoke import ERROR_LINE, HOST_READY_TIMEOUT, WARNING_LINE, Proc, find_godot, free_udp_port  # noqa: E402

DEFAULT_LEVEL = "res://levels/store_a.tscn"
DEFAULT_STRATEGIES = "rush,window,send,distract,buy"
DEFAULT_SEEDS = "1-10"
DEFAULT_OUT = os.path.join("build", "stats")
DEFAULT_QUIT_AFTER = 240.0
# Hard per-run limit beyond quit_after (startup, linger, client join).
HARD_MARGIN_SEC = 30.0
# Wait for a client's INSIDERS_READY before starting the next one (join order = team role).
CLIENT_READY_TIMEOUT = 20.0
JOIN_GAP_SEC = 0.5
# --quit-on-heist-end per process (s after the job ends): clients first, staggered, the host last.
HEIST_END_LINGER = {"host": 2.5, "c1": 1.0, "c2": 1.3, "c3": 1.6}
MAX_PLAYERS = 4
# Brain stuck time (s) from which a run counts as "stuck" in the summary (brain_* scenarios accept up to 3 s).
STUCK_LIMIT_S = 3.0
KNOWN_OUTCOMES = ["clean", "shouted", "hot", "caught_all", "police", "aborted"]
NO_RESULT = "none"
STRATEGY_TOKEN = re.compile(r"^[A-Za-z0-9_+\-]+$")
RUN_FIELDS = [
    "run_id", "cell", "players", "seed", "latency_ms", "status", "outcome", "outcome_same", "payout", "loot_total",
    "duration_s", "max_alert", "heat", "caught", "escaped", "strategy_class", "stuck_s", "unsticks", "failures",
    "wait_timeouts", "retreats", "error_lines", "warning_lines", "exit_codes", "exit_reasons", "session_seed", "wall_s",
    "problem",
]


# --- argument parsing and the matrix ---


def parse_seeds(text: str) -> list[int]:
    """"1-5,8,10-12" -> sorted unique ints. ValueError on a bad range."""
    out: set[int] = set()
    for part in text.split(","):
        part = part.strip()
        if not part:
            continue
        m = re.fullmatch(r"(-?\d+)\s*-\s*(-?\d+)", part)
        if m:
            lo, hi = int(m.group(1)), int(m.group(2))
            if hi < lo:
                raise ValueError(f"tohum aralığı ters: {part!r}")
            if hi - lo > 100000:
                raise ValueError(f"tohum aralığı çok büyük: {part!r}")
            out.update(range(lo, hi + 1))
        elif re.fullmatch(r"-?\d+", part):
            out.add(int(part))
        else:
            raise ValueError(f"tohum anlaşılmadı: {part!r} (ör. 1-50 ya da 1,3,5-7)")
    if not out:
        raise ValueError("tohum listesi boş")
    return sorted(out)


def parse_players(text: str) -> list[int]:
    out: list[int] = []
    for part in text.split(","):
        part = part.strip()
        if not part:
            continue
        if not part.isdigit() or not (1 <= int(part) <= MAX_PLAYERS):
            raise ValueError(f"oyuncu sayısı 1..{MAX_PLAYERS} olmalı: {part!r}")
        if int(part) not in out:
            out.append(int(part))
    if not out:
        raise ValueError("oyuncu sayısı listesi boş")
    return out


def parse_strategy(token: str) -> tuple[str, ...]:
    """"rush" -> ("rush",); "rush/team" -> ("rush", "team") (per peer, join order). Free strings: Godot validates them."""
    parts = tuple(p.strip() for p in token.strip().split("/"))
    if not parts or any(not STRATEGY_TOKEN.match(p) for p in parts):
        raise ValueError(f"strateji adı geçersiz: {token!r} (harf, rakam, _ + -; peer başına ayırıcı /)")
    if len(parts) > MAX_PLAYERS:
        raise ValueError(f"en çok {MAX_PLAYERS} peer: {token!r}")
    return parts


def parse_strategies(text: str) -> list[tuple[str, ...]]:
    out = [parse_strategy(t) for t in text.split(",") if t.strip()]
    return out


@dataclass(frozen=True)
class RunSpec:
    run_id: str
    cell: str                 # strategy token as given ("team", "rush/send")
    peers: tuple[str, ...]    # strategy per peer in join order (host first)
    seed: int

    @property
    def players(self) -> int:
        return len(self.peers)


def cells_for(strategies: list[tuple[str, ...]], players: list[int]) -> list[tuple[str, tuple[str, ...]]]:
    """(cell label, per-peer strategies). A per-peer token fixes its own player count; others multiply with `players`."""
    out: list[tuple[str, tuple[str, ...]]] = []
    for parts in strategies:
        if len(parts) > 1:
            out.append(("/".join(parts), parts))
            continue
        for n in players:
            out.append((parts[0], parts * n))
    return out


def parse_cell(text: str, default_seeds: list[int]) -> tuple[list[tuple[str, tuple[str, ...]]], list[int]]:
    """"team:2,3:1-10" -> cells + seeds. "rush/send" (no player part) -> 2 players; "team:2" -> default seeds."""
    pieces = text.split(":")
    if not 1 <= len(pieces) <= 3 or not pieces[0].strip():
        raise ValueError(f"--cell biçimi STRATEJİLER[:OYUNCULAR[:TOHUMLAR]]: {text!r}")
    strategies = parse_strategies(pieces[0])
    if not strategies:
        raise ValueError(f"--cell stratejisi boş: {text!r}")
    players = parse_players(pieces[1]) if len(pieces) > 1 and pieces[1].strip() else [1]
    seeds = parse_seeds(pieces[2]) if len(pieces) > 2 and pieces[2].strip() else default_seeds
    return cells_for(strategies, players), seeds


def build_matrix(groups: Iterable[tuple[list[tuple[str, tuple[str, ...]]], list[int]]]) -> list[RunSpec]:
    """Every (cell, seed) of every group once (duplicates dropped, first order kept); run ids are stable and file-name safe."""
    seen: set[tuple[tuple[str, ...], int]] = set()
    out: list[RunSpec] = []
    for cells, seeds in groups:
        for label, peers in cells:
            for seed in seeds:
                key = (peers, seed)
                if key in seen:
                    continue
                seen.add(key)
                safe = re.sub(r"[^A-Za-z0-9_-]", "_", label.replace("+", "p").replace("/", "-"))
                out.append(RunSpec(f"{safe}_{len(peers)}p_s{seed}", label, peers, seed))
    return out


def proc_names(players: int) -> list[str]:
    return ["host"] + [f"c{i}" for i in range(1, players)]


def peer_args(
    name: str,
    strategy: str,
    seed: int,
    port: int,
    level: str,
    dump: str,
    quit_after: float,
    player_scene: str | None = None,
    extra: Iterable[str] = (),
) -> list[str]:
    """Godot user arguments (after `--`) of one peer (S6 + S6 eki)."""
    user = [f"--name={name}"]
    if name == "host":
        user += ["--host", f"--port={port}", f"--level={level}"]
    else:
        user += ["--join=127.0.0.1", f"--port={port}"]
    if player_scene:
        user.append(f"--player-scene={player_scene}")
    linger = HEIST_END_LINGER.get(name, 1.0)
    qa = quit_after if name == "host" else quit_after + 5.0  # clients normally leave on heist end or host loss
    user += [f"--brain={strategy}", f"--seed={seed}", f"--dump={dump}", f"--quit-on-heist-end={linger:g}",
             f"--quit-after={qa:g}"]
    user += list(extra)
    return user


# --- dump reading ---


def dig(data: Any, path: str, default: Any = None) -> Any:
    for part in path.split("."):
        if isinstance(data, dict) and part in data:
            data = data[part]
        else:
            return default
    return data


def num(value: Any) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    if isinstance(value, float) and math.isnan(value):
        return None
    return float(value)


def count_log_lines(lines: Iterable[str]) -> tuple[int, int]:
    """(ERROR lines, WARNING lines) as net_smoke counts them."""
    err = warn = 0
    for ln in lines:
        if ERROR_LINE.match(ln):
            err += 1
        elif WARNING_LINE.match(ln):
            warn += 1
    return err, warn


def record_from(
    spec: RunSpec,
    dumps: dict[str, dict | None],
    exit_codes: dict[str, int | None],
    killed: list[str],
    logs: dict[str, list[str]],
    latency_ms: float,
    wall_s: float,
    problems: list[str] | None = None,
) -> dict[str, Any]:
    """One runs.csv row from a run's dumps (host first). Pure: tests feed fake dumps."""
    problems = list(problems or [])
    host = dumps.get("host") or {}
    result = dig(host, "heist.result", {}) or {}
    outcome = str(result.get("outcome", "")) or NO_RESULT
    outcomes = [str(dig(d, "heist.result.outcome", "") or NO_RESULT) for d in dumps.values() if d is not None]
    brains = [d.get("brain") for d in dumps.values() if isinstance(d, dict) and isinstance(d.get("brain"), dict)]
    players = result.get("players") if isinstance(result.get("players"), dict) else {}
    max_alert = num(dig(host, "heist.max_alert"))
    if max_alert is None:
        max_alert = num(result.get("max_alert"))
    err = warn = 0
    for lines in logs.values():
        e, w = count_log_lines(lines)
        err += e
        warn += w
    for name in proc_names(spec.players):
        if name in killed:
            problems.append(f"{name} zaman aşımında öldürüldü")
        elif dumps.get(name) is None:
            problems.append(f"{name} döküm yazmadı")
        elif exit_codes.get(name) not in (0, None):
            problems.append(f"{name} çıkış kodu {exit_codes.get(name)}")
    if killed:
        status = "timeout"
    elif problems:
        status = "error"
    elif outcome == NO_RESULT:
        status = "no_result"
    else:
        status = "ok"

    def brain_sum(key: str) -> float:
        return sum(num(b.get(key)) or 0.0 for b in brains)

    session = host.get("session_seed")
    return {
        "run_id": spec.run_id,
        "cell": spec.cell,
        "players": spec.players,
        "seed": spec.seed,
        "latency_ms": latency_ms,
        "status": status,
        "outcome": outcome,
        "outcome_same": len(set(outcomes)) <= 1,
        "payout": num(result.get("payout")),
        "loot_total": num(result.get("loot_total")),
        "duration_s": num(result.get("duration_s")),
        "max_alert": max_alert,
        "heat": num(result.get("heat")),
        "caught": sum(1 for p in players.values() if isinstance(p, dict) and p.get("caught")),
        "escaped": sum(1 for p in players.values() if isinstance(p, dict) and p.get("escaped")),
        "strategy_class": str(dig(result, "strategy.class", "") or ""),
        "stuck_s": max((num(b.get("stuck_s")) or 0.0 for b in brains), default=None),
        "unsticks": int(brain_sum("unsticks")),
        "failures": int(brain_sum("failures")),
        "wait_timeouts": int(brain_sum("wait_timeouts")),
        "retreats": int(brain_sum("retreats")),
        "error_lines": err,
        "warning_lines": warn,
        "exit_codes": " ".join(f"{n}={exit_codes.get(n)}" for n in proc_names(spec.players)),
        "exit_reasons": " ".join(f"{n}={(dumps.get(n) or {}).get('exit_reason', '-')}" for n in proc_names(spec.players)),
        "session_seed": session if isinstance(session, (int, float, str)) and not isinstance(session, bool) else "",
        "wall_s": round(wall_s, 1),
        "problem": "; ".join(problems),
    }


# --- summary ---


def percentile(values: list[float], q: float) -> float | None:
    """Nearest-rank percentile (q in 0..100); None for an empty list."""
    if not values:
        return None
    s = sorted(values)
    k = max(1, math.ceil(q / 100.0 * len(s)))
    return s[min(k, len(s)) - 1]


def mean(values: list[float]) -> float | None:
    return sum(values) / len(values) if values else None


def outcome_columns(rows: list[dict]) -> list[str]:
    seen = {str(r["outcome"]) for r in rows}
    extra = sorted(seen - set(KNOWN_OUTCOMES) - {NO_RESULT})
    return KNOWN_OUTCOMES + extra + [NO_RESULT]


def summarize(rows: list[dict]) -> tuple[list[str], list[list[str]]]:
    """Header + one row per (cell, players) in first-seen order."""
    cols = outcome_columns(rows)
    groups: dict[tuple[str, int], list[dict]] = {}
    for r in rows:
        groups.setdefault((str(r["cell"]), int(r["players"])), []).append(r)
    header = ["strateji", "oyuncu", "n"] + [f"% {c}" for c in cols] + [
        "ort. ödeme", "ort. süre", "p90 süre", "ort. max_alert", "takılma", "başarısız", "hatalı koşu", "sorun",
    ]
    table: list[list[str]] = []
    for (cell, players), rs in groups.items():
        n = len(rs)
        dist = [f"{100.0 * sum(1 for r in rs if r['outcome'] == c) / n:.0f}" for c in cols]
        pay = [v for v in (num(r["payout"]) for r in rs) if v is not None]
        dur = [v for v in (num(r["duration_s"]) for r in rs) if v is not None]
        alert = [v for v in (num(r["max_alert"]) for r in rs) if v is not None]
        stuck = sum(1 for r in rs if (num(r["stuck_s"]) or 0.0) >= STUCK_LIMIT_S)
        failures = sum(int(r["failures"] or 0) for r in rs)
        err_runs = sum(1 for r in rs if int(r["error_lines"] or 0) + int(r["warning_lines"] or 0) > 0)
        err_lines = sum(int(r["error_lines"] or 0) + int(r["warning_lines"] or 0) for r in rs)
        trouble = sum(1 for r in rs if r["status"] in ("timeout", "error") or not r["outcome_same"])
        table.append([cell, str(players), str(n)] + dist + [
            fmt(mean(pay), "{:.0f}"), fmt(mean(dur), "{:.1f}"), fmt(percentile(dur, 90), "{:.1f}"),
            fmt(mean(alert), "{:.2f}"), str(stuck), str(failures), f"{err_runs} ({err_lines})", str(trouble),
        ])
    return header, table


def fmt(value: float | None, spec: str) -> str:
    return "-" if value is None else spec.format(value)


def markdown_table(header: list[str], rows: list[list[str]]) -> str:
    out = ["| " + " | ".join(header) + " |", "|" + "|".join("---" for _ in header) + "|"]
    out += ["| " + " | ".join(r) + " |" for r in rows]
    return "\n".join(out)


def text_table(header: list[str], rows: list[list[str]]) -> str:
    widths = [max(len(header[i]), *(len(r[i]) for r in rows)) if rows else len(header[i]) for i in range(len(header))]
    lines = ["  ".join(h.ljust(w) for h, w in zip(header, widths))]
    lines += ["  ".join(c.ljust(w) for c, w in zip(r, widths)) for r in rows]
    return "\n".join(lines)


LEGEND = (
    "Sütunlar: `% <sonuç>` koşuların sonuç dağılımı (`none` = iş sonuçlanmadı: --quit-after doldu); ödeme `heist.result.payout`; "
    "süre `heist.result.duration_s` (iş süresi, sn; sonuçsuz koşu sayılmaz); max_alert host `heist.max_alert`; "
    f"takılma = beyin `stuck_s` >= {STUCK_LIMIT_S:g} sn olan koşu; başarısız = beyin `failures` toplamı; "
    "hatalı koşu = günlüğünde ERROR/WARNING satırı olan koşu (parantezde satır sayısı); "
    "sorun = zaman aşımı / döküm yok / çıkış kodu ≠ 0 / peer'lar arasında farklı sonuç."
)


def write_outputs(out_dir: str, rows: list[dict], meta: dict[str, Any]) -> str:
    header, table = summarize(rows)
    with open(os.path.join(out_dir, "runs.csv"), "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=RUN_FIELDS)
        w.writeheader()
        for r in rows:
            w.writerow({k: ("" if r.get(k) is None else r.get(k)) for k in RUN_FIELDS})
    md = [f"# Soygun istatistiği — {meta.get('started', '')}", ""]
    for k, v in meta.items():
        if k != "started":
            md.append(f"- {k}: {v}")
    md += ["", markdown_table(header, table), "", LEGEND, ""]
    path = os.path.join(out_dir, "summary.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(md))
    return text_table(header, table)


# --- running ---


class PortAllocator:
    """Free UDP ports, never handing out the same port twice in one invocation (parallel runs)."""

    def __init__(self, probe: Callable[[], int] = free_udp_port) -> None:
        self._probe = probe
        self._used: set[int] = set()
        self._lock = threading.Lock()

    def take(self) -> int:
        with self._lock:
            for _ in range(200):
                p = self._probe()
                if p not in self._used:
                    self._used.add(p)
                    return p
        raise RuntimeError("boş UDP portu bulunamadı")


class SlotPool:
    """Weighted semaphore: a run of N players holds min(N, capacity) Godot process slots."""

    def __init__(self, capacity: int) -> None:
        self.capacity = max(1, capacity)
        self._free = self.capacity
        self._cond = threading.Condition()

    def acquire(self, n: int, cancel: threading.Event | None = None) -> int:
        n = max(1, min(n, self.capacity))
        with self._cond:
            while self._free < n:
                if cancel is not None and cancel.is_set():
                    raise InterruptedError
                self._cond.wait(0.2)
            self._free -= n
        return n

    def release(self, n: int) -> None:
        with self._cond:
            self._free += n
            self._cond.notify_all()


@dataclass
class Context:
    godot: str
    level: str
    quit_after: float
    run_timeout: float
    latency_ms: float
    player_scene: str | None
    extra: list[str]
    runs_dir: str
    ports: PortAllocator
    cancel: threading.Event = field(default_factory=threading.Event)
    live: dict = field(default_factory=dict)  # id(Proc) -> Proc (Proc is an unhashable dataclass)
    lock: threading.Lock = field(default_factory=threading.Lock)

    def track(self, proc: Proc, alive: bool) -> None:
        with self.lock:
            if alive:
                self.live[id(proc)] = proc
            else:
                self.live.pop(id(proc), None)

    def kill_all(self) -> None:
        with self.lock:
            procs = list(self.live.values())
        for p in procs:
            p.kill()


def wait_ready(proc: Proc, timeout: float, cancel: threading.Event) -> bool:
    t0 = time.monotonic()
    while not proc.ready.wait(0.05):
        if cancel.is_set() or (proc.popen is not None and proc.popen.poll() is not None):
            return False
        if time.monotonic() - t0 > timeout:
            return False
    return True


def run_one(spec: RunSpec, ctx: Context) -> dict[str, Any]:
    """Runs one matrix cell; never raises for a game failure (it becomes the row's status/problem)."""
    t_begin = time.monotonic()
    run_dir = os.path.join(ctx.runs_dir, spec.run_id)
    os.makedirs(run_dir, exist_ok=True)
    names = proc_names(spec.players)
    host_port = ctx.ports.take()
    proxy: LatencyProxy | None = None
    procs: dict[str, Proc] = {}
    problems: list[str] = []

    def make(name: str, port: int) -> Proc:
        dump = os.path.join(run_dir, f"{name}.json")
        strategy = spec.peers[names.index(name)]
        user = peer_args(name, strategy, spec.seed, port, ctx.level, dump, ctx.quit_after, ctx.player_scene, ctx.extra)
        log = os.path.join(run_dir, f"{name}.log")  # Godot's own log (no shared user:// log rotation between parallel runs)
        cmd = [ctx.godot, "--headless", "--path", ROOT, "--log-file", log, "--"] + user
        return Proc(name=name, cmd=cmd, dump_path=dump, quit_after=ctx.quit_after)

    def launch(proc: Proc) -> None:
        procs[proc.name] = proc
        ctx.track(proc, True)
        proc.start()

    try:
        join_port = host_port
        if ctx.latency_ms > 0 and spec.players > 1:
            proxy = LatencyProxy(target=("127.0.0.1", host_port), delay_ms=ctx.latency_ms / 2.0)
            join_port = proxy.start()
        launch(make("host", host_port))
        if not wait_ready(procs["host"], HOST_READY_TIMEOUT, ctx.cancel):
            problems.append(f"host {HOST_READY_TIMEOUT:g} sn içinde hazır olmadı")
        else:
            for name in names[1:]:
                proc = make(name, join_port)
                launch(proc)
                if not wait_ready(proc, CLIENT_READY_TIMEOUT, ctx.cancel):
                    problems.append(f"{name} {CLIENT_READY_TIMEOUT:g} sn içinde bağlanmadı")
                    break
                time.sleep(JOIN_GAP_SEC)
        deadline = t_begin + ctx.run_timeout if not problems else time.monotonic()  # startup failed: stop now
        for proc in procs.values():
            assert proc.popen is not None
            while proc.popen.poll() is None and time.monotonic() < deadline and not ctx.cancel.is_set():
                try:
                    proc.popen.wait(timeout=0.5)
                except subprocess.TimeoutExpired:
                    pass
    finally:
        for proc in procs.values():
            proc.kill()
            proc.finish()
            ctx.track(proc, False)
        if proxy is not None:
            proxy.stop()

    dumps: dict[str, dict | None] = {}
    logs: dict[str, list[str]] = {}
    for name in names:
        proc = procs.get(name)
        if proc is None:
            dumps[name] = None
            continue
        logs[name] = proc.lines  # stdout (counted); the same text is in <name>.log
        d: dict | None = None
        if os.path.exists(proc.dump_path):
            try:
                with open(proc.dump_path, encoding="utf-8") as f:
                    d = json.load(f)
            except (OSError, json.JSONDecodeError) as e:
                problems.append(f"{name} dökümü okunamadı: {e}")
        dumps[name] = d
    if ctx.cancel.is_set():
        problems.append("iptal edildi")
    killed = [p.name for p in procs.values() if p.killed]
    exit_codes = {p.name: p.exit_code for p in procs.values()}
    return record_from(spec, dumps, exit_codes, killed, logs, ctx.latency_ms, time.monotonic() - t_begin, problems)


def default_jobs() -> int:
    return max(1, (os.cpu_count() or 2) // 2)


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(description="Kapalı döngü bot beyniyle toplu soygun istatistiği (IS-015b)")
    ap.add_argument("--strategies", default=DEFAULT_STRATEGIES,
                    help=f"virgüllü strateji listesi; peer başına ayrı: a/b/c (boş = yalnız --cell) [{DEFAULT_STRATEGIES}]")
    ap.add_argument("--players", default="1", help="oyuncu sayıları, ör. 1,2,3 [1]")
    ap.add_argument("--seeds", default=DEFAULT_SEEDS, help=f"tohumlar, ör. 1-50 ya da 1,3,5-7 [{DEFAULT_SEEDS}]")
    ap.add_argument("--cell", action="append", default=[], metavar="STRATEJİLER[:OYUNCULAR[:TOHUMLAR]]",
                    help="ek ızgara (tekrar edilebilir), ör. team:2,3:1-10")
    ap.add_argument("--jobs", type=int, default=default_jobs(), help="aynı anda Godot süreci yuvası [CPU/2]")
    ap.add_argument("--latency-ms", type=float, default=0.0, help="RTT; >0 ve istemci varsa araya latency_proxy konur")
    ap.add_argument("--level", default=DEFAULT_LEVEL)
    ap.add_argument("--player-scene", default=None, help="--player-scene (varsayılan: oyunun kendi oyuncusu)")
    ap.add_argument("--quit-after", type=float, default=DEFAULT_QUIT_AFTER, help="oyun içi üst sınır (sn) [240]")
    ap.add_argument("--run-timeout", type=float, default=None,
                    help=f"koşu başına sert sınır (sn); sonra süreç ağacı öldürülür [quit-after + {HARD_MARGIN_SEC:g}]")
    ap.add_argument("--godot-arg", action="append", default=[], metavar="ARG",
                    help="her peer'a eklenen Godot kullanıcı argümanı (ör. --godot-arg=--brain-loop=60)")
    ap.add_argument("--out", default=DEFAULT_OUT, help="çıktı kökü [build/stats]")
    ap.add_argument("--dry-run", action="store_true", help="matrisi ve komutları yaz, Godot başlatma")
    ap.add_argument("-v", "--verbose", action="store_true", help="her koşu için bir satır")
    return ap


def parse_args(argv: list[str] | None) -> tuple[argparse.Namespace, list[RunSpec]]:
    """argparse + matrix; ValueError for a bad matrix."""
    args = build_parser().parse_args(argv)
    args.argv_text = " ".join(sys.argv[1:] if argv is None else argv)
    seeds = parse_seeds(args.seeds)
    groups: list[tuple[list[tuple[str, tuple[str, ...]]], list[int]]] = []
    strategies = parse_strategies(args.strategies)
    if strategies:
        groups.append((cells_for(strategies, parse_players(args.players)), seeds))
    for text in args.cell:
        groups.append(parse_cell(text, seeds))
    specs = build_matrix(groups)
    if not specs:
        raise ValueError("matris boş (--strategies ya da --cell gerekli)")
    if args.jobs < 1:
        raise ValueError("--jobs >= 1 olmalı")
    if args.quit_after <= 0:
        raise ValueError("--quit-after > 0 olmalı")
    if args.run_timeout is None:
        args.run_timeout = args.quit_after + HARD_MARGIN_SEC
    if args.latency_ms < 0:
        raise ValueError("--latency-ms >= 0 olmalı")
    return args, specs


def git_rev() -> str:
    try:
        out = subprocess.run(["git", "-C", ROOT, "rev-parse", "--short", "HEAD"], capture_output=True, text=True, check=False)
        return out.stdout.strip() or "?"
    except OSError:
        return "?"


def run(args: argparse.Namespace, specs: list[RunSpec]) -> int:
    if args.dry_run:
        for s in specs:
            names = proc_names(s.players)
            parts = [f"{n}: {' '.join(peer_args(n, s.peers[i], s.seed, 0, args.level, f'<{n}.json>', args.quit_after, args.player_scene, args.godot_arg))}"
                     for i, n in enumerate(names)]
            print(f"{s.run_id}\n  " + "\n  ".join(parts))
        print(f"{len(specs)} koşu, {sum(s.players for s in specs)} Godot süreci (--dry-run)")
        return 0
    stamp = _dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    out_root = args.out if os.path.isabs(args.out) else os.path.join(ROOT, args.out)
    out_dir = os.path.join(out_root, stamp)
    runs_dir = os.path.join(out_dir, "runs")
    os.makedirs(runs_dir, exist_ok=True)
    # Keep Godot from importing the stats (runs.csv would become translation files inside the project).
    open(os.path.join(out_root, ".gdignore"), "a").close()
    ctx = Context(
        godot=find_godot(), level=args.level, quit_after=args.quit_after, run_timeout=args.run_timeout,
        latency_ms=args.latency_ms, player_scene=args.player_scene, extra=list(args.godot_arg), runs_dir=runs_dir,
        ports=PortAllocator(),
    )
    pool = SlotPool(args.jobs)
    total = len(specs)
    print(f"{total} koşu, {args.jobs} yuva, çıktı {out_dir}", flush=True)
    t0 = time.monotonic()
    rows: list[dict] = []
    done = 0

    def task(spec: RunSpec) -> dict:
        n = pool.acquire(spec.players, ctx.cancel)
        try:
            if ctx.cancel.is_set():
                raise InterruptedError
            try:
                return run_one(spec, ctx)
            except Exception as e:  # a harness bug in one run becomes that run's row, the batch goes on
                return record_from(spec, {}, {}, [], {}, ctx.latency_ms, 0.0, [f"düzenek istisnası: {e!r}"])
        finally:
            pool.release(n)

    executor = ThreadPoolExecutor(max_workers=args.jobs)
    try:
        futures = {executor.submit(task, s): s for s in specs}
        for fut in as_completed(futures):
            spec = futures[fut]
            try:
                row = fut.result()
            except InterruptedError:
                continue
            rows.append(row)
            done += 1
            if args.verbose or row["status"] in ("timeout", "error"):
                extra = f" — {row['problem']}" if row["problem"] else ""
                print(f"[{done}/{total}] {spec.run_id}: {row['outcome']} ({row['status']}, {row['wall_s']:g} sn){extra}",
                      flush=True)
            elif done % 10 == 0 or done == total:
                print(f"[{done}/{total}] {time.monotonic() - t0:.0f} sn", flush=True)
    except BaseException:
        ctx.cancel.set()
        ctx.kill_all()
        executor.shutdown(wait=True, cancel_futures=True)
        raise
    executor.shutdown(wait=True)
    order = {s.run_id: i for i, s in enumerate(specs)}
    rows.sort(key=lambda r: order[r["run_id"]])
    meta = {
        "started": stamp,
        "komut": ("python tools/heist_stats.py " + getattr(args, "argv_text", "")).strip(),
        "commit": git_rev(),
        "seviye": args.level,
        "gecikme": f"{args.latency_ms:g} ms RTT",
        "koşu": f"{len(rows)} ({time.monotonic() - t0:.0f} sn, {args.jobs} yuva)",
    }
    table = write_outputs(out_dir, rows, meta)
    print(table)
    print(f"özet: {os.path.join(out_dir, 'summary.md')}")
    bad = [r for r in rows if r["status"] in ("timeout", "error")]
    if bad:
        print(f"UYARI: {len(bad)} koşuda düzenek sorunu (runs.csv 'problem' sütunu)")
    return 1 if bad else 0


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):  # Turkish output on a cp125x Windows console
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8", errors="replace")
            except (OSError, ValueError):
                pass
    try:
        args, specs = parse_args(argv)
    except ValueError as e:
        print(f"heist_stats: {e}", file=sys.stderr)
        return 2
    # SIGTERM (e.g. a CI cancel) becomes SystemExit: the except/finally blocks kill every Godot process tree.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    if hasattr(signal, "SIGBREAK"):  # Windows: CTRL_BREAK_EVENT
        signal.signal(signal.SIGBREAK, lambda *_: sys.exit(143))
    return run(args, specs)


if __name__ == "__main__":
    sys.exit(main())
