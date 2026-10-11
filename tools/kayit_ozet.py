#!/usr/bin/env python3
"""Playtest log summary (IS-111; test-2). Python standard library only.

Usage:
    python tools/kayit_ozet.py kayit-host.json [kayit-*.json ...] [--md out.md]

Input: the `--log-on-exit` files every peer writes (S6 dump + "log_reason"; IS-102). The host file is found by `is_host`; client
files fill in player names, ping, `host_lost` and their own `log_reason`. Several host files (e.g. one per run copy) give one section
each. Output (Turkish Markdown, stdout or --md): session summary, then per run (host `events` split by `level_started {run}`, results
from `heist.history[]`) the result, strategy, per-player state and cover, the time-free event order and - for the run whose level
was loaded when the file was written (owner/chasers/population data belong to that level only) - a merged, time-sorted timeline
(owner.log + detections + discoveries + hold windows + rescues + chasers.ladder + arrivals + register/bag moments + questions),
questions, shop/order and door/bell lines; finally a short answer table for the observation form rows with a dump source
(docs/tasarim/danisma/test-2-protokol.md §2 "D", §4). Missing or older fields (58aaaa4 .. eb5989e dumps) are skipped, never fatal;
unknown answers read "kayıtta yok".
Times: seconds from the level start (the owner brain clock; heist times such as register_emptied_at_s use the same origin).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from typing import Any

NONE = "kayıtta yok"
OUTCOMES = {
    "clean": "temiz",
    "shouted": "bağırdı",
    "hot": "sıcak",
    "caught_all": "hepsi yakalandı",
    "police": "polis",
    "aborted": "eli boş çekildi",
}
ALERT_TIERS = {0: "sakin", 1: "şüphe", 2: "bağırdı", 3: "mahalle geldi", 4: "kademe 4", 5: "polis"}
COVER_REASONS = {
    "mask": "maske",
    "bag": "çanta",
    "cash": "kasa/nakit",
    "staff": "personel bölgesi",
    "run": "koşma",
    "sneak": "sızma",
    "seen_with": "arkadaşla görüldü",
}
ZONES = {"outside": "dış", "customer": "müşteri", "staff": "personel", "backroom": "arka oda"}
SOURCES = {"register": "kasanın boş olduğunu", "cash": "arka oda nakdinin eksik olduğunu"}
SOURCES_SHORT = {"register": "kasa", "cash": "arka oda nakdi"}
TRIGGERS = {
    "return": "dönüş kontrolü",
    "serve": "servis sırasında",
    "backroom": "arka oda kontrolü",
    "idle": "boş tezgâhta",
    "bell": "zil üzerine arka oda",
}
CATCHERS = {"owner": "sahip", "chaser": "mahalleli"}
NOTES = {
    "ghost_crew": "hayalet ekip",
    "shadow": "gölge",
    "window_star": "pencere yıldızı",
    "marathon": "maraton",
    "bail": "kefalet",
    "porter": "hamal",
    "door_slammer": "kapı çarpan",
    "owner_favourite": "sahibin gözdesi",
    "slipper": "sıyrılan",
    "pulled_free": "çekip kurtardı",
}
RUN_EVENT = "level_started"
PEER_IN_TEXT = re.compile(r"\bp(\d+)\b")
VERSION_KEYS = ("version", "game_version", "build", "protocol", "protocol_version")


# --------------------------------------------------------------------------------------------------------------------------------
# Safe access


def as_dict(v: Any) -> dict:
    return v if isinstance(v, dict) else {}


def as_list(v: Any) -> list:
    return v if isinstance(v, list) else []


def get(d: Any, *keys: Any, default: Any = None) -> Any:
    """d[k1][k2]... through dicts (keys) and lists (int indices); default when any step is missing or None."""
    cur = d
    for k in keys:
        if isinstance(cur, dict):
            cur = cur.get(k)
        elif isinstance(cur, list) and isinstance(k, int) and -len(cur) <= k < len(cur):
            cur = cur[k]
        else:
            return default
        if cur is None:
            return default
    return cur


def num(v: Any) -> float | None:
    if isinstance(v, bool):
        return None
    if isinstance(v, (int, float)):
        return float(v)
    try:
        return float(str(v))
    except (TypeError, ValueError):
        return None


def sec(v: Any, digits: int = 1) -> str:
    """Seconds with a decimal comma, half up (129.35 -> "129,4")."""
    x = num(v)
    if x is None:
        return "?"
    return f"{x + (1e-9 if x >= 0 else -1e-9):.{digits}f}".replace(".", ",")


def money(v: Any) -> str:
    x = num(v)
    return str(int(x)) if x is not None else "?"


def yes_no(v: Any) -> str:
    return "evet" if v else "hayır"


def peer_key(v: Any) -> str:
    x = num(v)
    return str(int(x)) if x is not None else str(v)


# --------------------------------------------------------------------------------------------------------------------------------
# Names


def accusative(name: str) -> str:
    """Turkish accusative with apostrophe: Ikinci -> Ikinci'yi, Mustafa -> Mustafa'yı, Ali -> Ali'yi, Can -> Can'ı."""
    lower = name.replace("I", "ı").replace("İ", "i").lower()
    harmony = {"a": "ı", "ı": "ı", "o": "u", "u": "u", "e": "i", "i": "i", "ö": "ü", "ü": "ü"}
    last_vowel = next((c for c in reversed(lower) if c in harmony), "e")
    buffer = "y" if lower and lower[-1] in harmony else ""
    return f"{name}'{buffer}{harmony[last_vowel]}"


class Names:
    def __init__(self) -> None:
        self.by_peer: dict[str, str] = {}

    def add(self, peer: Any, name: Any) -> None:
        if isinstance(name, str) and name and peer_key(peer) not in self.by_peer:
            self.by_peer[peer_key(peer)] = name

    def of(self, peer: Any) -> str:
        key = peer_key(peer)
        return self.by_peer.get(key, f"p{key}")

    def in_text(self, text: str) -> str:
        """"p78313522" in an owner.log line -> the player's name (only known peers)."""
        return PEER_IN_TEXT.sub(lambda m: self.by_peer.get(m.group(1), m.group(0)), text)

    def observer(self, who: Any) -> str:
        s = str(who)
        return "sahip" if s == "Owner" else s

    @staticmethod
    def collect(dumps: list[dict]) -> "Names":
        n = Names()
        for d in dumps:
            for peer, p in as_dict(d.get("players")).items():
                n.add(peer, get(p, "name"))
            for run in as_list(get(d, "heist", "history")):
                for peer, p in as_dict(get(run, "players")).items():
                    n.add(peer, get(p, "name"))
            for peer, p in as_dict(get(d, "heist", "result", "players")).items():
                n.add(peer, get(p, "name"))
        return n


# --------------------------------------------------------------------------------------------------------------------------------
# Runs


class Run:
    def __init__(self, index: int) -> None:
        self.index = index  # 1-based
        self.marker: dict = {}
        self.events: list[dict] = []
        self.result: dict = {}
        self.finished = True
        self.live = False  # the level of this run was loaded when the file was written (owner/chasers/... belong to it)


def split_runs(host: dict) -> tuple[list[Run], str]:
    """Runs of a host dump and a note ("" if the split is clean)."""
    events = [e for e in as_list(host.get("events")) if isinstance(e, dict)]
    history = [h for h in as_list(get(host, "heist", "history")) if isinstance(h, dict)]
    if not history and as_dict(get(host, "heist", "result")):
        history = [as_dict(get(host, "heist", "result"))]
    markers = [i for i, e in enumerate(events) if e.get("kind") == RUN_EVENT]
    note = ""
    runs: list[Run] = []
    if markers:
        if markers[0] > 0:
            note = f"ilk `level_started` öncesinde {markers[0]} olay var (ilk koşuya eklendi)"
        count = max(len(markers), len(history))
        for k in range(count):
            r = Run(k + 1)
            if k < len(markers):
                r.marker = as_dict(events[markers[k]].get("data"))
                lo = 0 if k == 0 else markers[k] + 1
                hi = markers[k + 1] if k + 1 < len(markers) else len(events)
                r.events = [e for e in events[lo:hi] if e.get("kind") != RUN_EVENT]
            r.result = history[k] if k < len(history) else {}
            r.finished = bool(r.result)
            runs.append(r)
        runs[min(len(markers), len(runs)) - 1].live = True
    else:
        count = max(1, len(history))
        for k in range(count):
            r = Run(k + 1)
            r.result = history[k] if k < len(history) else {}
            r.finished = bool(r.result)
            runs.append(r)
        runs[-1].events = [e for e in events if e.get("kind") != RUN_EVENT]
        runs[-1].live = True
        if count > 1:
            note = "dosyada `level_started` işareti yok: olaylar koşulara bölünemedi (hepsi son koşuda)"
    return runs, note


# --------------------------------------------------------------------------------------------------------------------------------
# Text helpers


def event_text(e: dict, names: Names) -> str:
    kind = str(e.get("kind", "?"))
    d = as_dict(e.get("data"))
    who = names.of(d.get("peer")) if "peer" in d else ""
    if kind == "cover_broken":
        reason = COVER_REASONS.get(str(d.get("reason")), str(d.get("reason", "?")))
        seen = f"; gören {names.observer(d['by'])}" if d.get("by") else ""
        return f"örtü bozuldu: {who} ({reason}{seen})"
    if kind == "owner_distracted":
        return f"sahibin dikkati dağıldı ({d.get('kind', '?')})"
    if kind == "owner_sent":
        return f"GÖNDER: {who} sahibi arka odaya yolladı"
    if kind == "owner_discover":
        what = {"register": "kasa boş", "cash": "arka oda nakdi eksik"}.get(str(d.get("source")), str(d.get("source", "?")))
        return f"sahip keşfetti: {what}"
    if kind == "player_held":
        return f"{who} tutuldu (pencere {sec(d.get('window'))} sn)"
    if kind == "player_caught":
        return f"{who} yakalandı ({CATCHERS.get(str(d.get('by')), str(d.get('by', '?')))})"
    if kind == "player_rescued":
        by = f", kurtaran {names.of(d['by'])}" if "by" in d else ""
        return f"{who} kurtarıldı{by}"
    if kind == "police_arrived":
        return "polis geldi"
    if kind == "shout":
        return "bağırış"
    if kind == "alert_level":
        lv = int(num(d.get("level")) or 0)
        return f"uyarı kademesi {lv} ({ALERT_TIERS.get(lv, '?')})"
    if kind == "purchase":
        rest = ", ".join(f"{k}={v}" for k, v in d.items() if k != "peer")
        return f"satın alma: {who}" + (f" ({rest})" if rest else "")
    if kind == "misdirect":
        return f"yanlış yönlendirme: {who}"
    if kind == "phone_found":
        return "sahip telefonu buldu"
    if kind == "npc_pushed":
        return f"itme: {who} → {d.get('npc', '?')}" + (" (sakin)" if d.get("calm") else "")
    rest = ", ".join(f"{k}={names.of(v) if k == 'peer' else v}" for k, v in d.items())
    return f"{kind}" + (f" ({rest})" if rest else "")


def events_of(run: Run, kind: str) -> list[dict]:
    return [as_dict(e.get("data")) for e in run.events if e.get("kind") == kind]


# --------------------------------------------------------------------------------------------------------------------------------
# Timeline (live run only)


def owner_task_at(owner: dict, t: float) -> dict:
    """The owner.log row in force at time t (the last one with row.t <= t); {} if none."""
    best: dict = {}
    for row in as_list(owner.get("log")):
        rt = num(get(row, "t"))
        if rt is not None and rt <= t + 1e-6:
            best = as_dict(row)
    return best


def timeline(host: dict, run: Run, names: Names) -> list[tuple[float, str]]:
    owner = as_dict(host.get("owner"))
    rows: list[tuple[float, str]] = []
    detections = [as_dict(x) for x in as_list(owner.get("detections"))]
    discoveries = [as_dict(x) for x in as_list(owner.get("discoveries"))]
    rescues = [as_dict(x) for x in as_list(owner.get("rescues"))]
    used_det: set[int] = set()
    used_disc: set[int] = set()
    used_rescue: set[int] = set()
    log = [as_dict(x) for x in as_list(owner.get("log"))]
    end_s = num(run.result.get("duration_s"))
    # Cover intact at the end of the run => intact at every moment of it (a broken cover never heals within a run).
    intact = {peer_key(p): v for p, v in as_dict(get(run.result, "strategy", "cover_intact")).items()}

    def detection_line(i: int) -> str:
        d = detections[i]
        zone = ZONES.get(str(d.get("zone")), str(d.get("zone", "?")))
        extra = []
        if num(d.get("t_question")) is not None:
            extra.append(f"şüphe sorusu {sec(d.get('t_question'))}")
        if d.get("lit") is False:
            extra.append("karanlık")
        if num(d.get("rtt_ms")) is not None:
            extra.append(f"RTT {money(d.get('rtt_ms'))} ms")
        if intact.get(peer_key(d.get("peer"))) is True:
            extra.insert(0, "ÖRTÜSÜ SAĞLAM")
        tail = f" ({', '.join(extra)})" if extra else ""
        return (
            f"sahip {accusative(names.of(d.get('peer')))} tespit etti: {zone} bölgesi, "
            f"{money(d.get('dist_px'))} px, davranış {d.get('behaviour', '?')}{tail}"
        )

    def discovery_line(i: int) -> str:
        d = discoveries[i]
        what = SOURCES.get(str(d.get("source")), f"{d.get('source', '?')} eksikliğini")
        trig = TRIGGERS.get(str(d.get("trigger")), str(d.get("trigger", "?")))
        partial = "" if d.get("full", True) else "; zaten alarmda, yalnız balon"
        return f"sahip {what} fark etti ({trig}{partial})"

    def ref_index(ref: Any, field: str) -> int | None:
        m = re.fullmatch(rf"{field}\[(\d+)\]", str(ref or ""))
        return int(m.group(1)) if m else None

    skip: set[int] = set()
    for i, row in enumerate(log):
        if i in skip:
            continue
        t = num(row.get("t"))
        if t is None:
            continue
        state = str(row.get("state", ""))
        why = str(row.get("why", ""))
        ref = row.get("ref")
        di = ref_index(ref, "detections")
        if di is not None and di < len(detections):
            used_det.add(di)
            rows.append((t, detection_line(di)))
            continue
        ci = ref_index(ref, "discoveries")
        if ci is not None and ci < len(discoveries):
            used_disc.add(ci)
            rows.append((t, discovery_line(ci)))
            continue
        if state == "hold":
            target = row.get("target") or row.get("top_peer")
            end_t, outcome = None, ""
            for j in range(i + 1, len(log)):
                nxt = log[j]
                nwhy = str(nxt.get("why", ""))
                if str(nxt.get("state", "")) != "hold" or nwhy.startswith("tutma bitti"):
                    end_t = num(nxt.get("t"))
                    m = re.search(r"tutma bitti p\d+ \(([^)]*)\)", nwhy)
                    outcome = m.group(1) if m else ""
                    if nwhy.startswith("tutma bitti"):
                        skip.add(j)
                    break
            rescue = ""
            for k, r in enumerate(rescues):
                rt = num(r.get("t"))
                if peer_key(r.get("peer")) == peer_key(target) and rt is not None and rt >= t - 0.5 and (
                    end_t is None or rt <= end_t + 0.5
                ):
                    used_rescue.add(k)
                    rescue = f"kurtarıldı ({names.of(r.get('by'))}, {sec(rt)})"
            span = f"{sec(t)}–{sec(end_t)}" if end_t is not None else f"{sec(t)}–?"
            length = f" ({sec(end_t - t)} sn)" if end_t is not None else ""
            result = f" → {outcome}" if outcome else ""
            rows.append((t, f"{span} — sahip {accusative(names.of(target))} tuttu{length}{result}; {rescue or 'kurtarma yok'}"))
            continue
        tag = f" [{state}]" if state and state != "agenda" and f"({state}/" not in why else ""
        cost = ""
        si = ref_index(ref, "sent_windows")
        if si is not None and si < len(as_list(owner.get("sent_windows"))):
            cost = f" (pencere {sec(owner['sent_windows'][si])} sn)"
        ki = ref_index(ref, "send_costs")
        if ki is not None and ki < len(as_list(owner.get("send_costs"))):
            cost = f" (bedel {money(get(owner, 'send_costs', ki, 'amount'))})"
        rows.append((t, f"sahip: {names.in_text(why)}{cost}{tag}"))
    if not log:  # older dumps: FSM transitions only
        for st in as_list(owner.get("states")):
            if isinstance(st, list) and len(st) >= 2 and num(st[1]) is not None:
                rows.append((float(num(st[1]) or 0.0), f"sahip durumu → {st[0]}"))
    for i, d in enumerate(detections):
        if i not in used_det and num(d.get("t_detect")) is not None:
            rows.append((float(num(d.get("t_detect")) or 0.0), detection_line(i)))
    for i, d in enumerate(discoveries):
        if i not in used_disc and num(d.get("t")) is not None:
            rows.append((float(num(d.get("t")) or 0.0), discovery_line(i)))
    for i, r in enumerate(rescues):
        if i not in used_rescue and num(r.get("t")) is not None:
            rows.append((float(num(r.get("t")) or 0.0), f"{names.of(r.get('peer'))} kurtarıldı ({names.of(r.get('by'))})"))
    for q in as_list(owner.get("search_questions")):
        q = as_dict(q)
        if num(q.get("t")) is not None:
            rows.append(
                (float(num(q.get("t")) or 0.0), f"SORGU (aramada): sahip {accusative(names.of(q.get('peer')))} sorguladı (şüphe {money(q.get('value'))})")
            )
    for step in as_list(get(host, "chasers", "ladder")):
        if isinstance(step, list) and len(step) >= 2 and num(step[1]) is not None and (num(step[0]) or num(step[1])):
            lv = int(num(step[0]) or 0)
            rows.append((float(num(step[1]) or 0.0), f"uyarı kademesi → {lv} ({ALERT_TIERS.get(lv, '?')})"))
    for arr in as_list(get(host, "population", "arrivals")):
        if isinstance(arr, list) and len(arr) >= 2 and num(arr[1]) is not None:
            kind = {"customer": "müşteri geldi", "passerby": "yoldan geçen"}.get(str(arr[0]), f"{arr[0]} geldi")
            rows.append((float(num(arr[1]) or 0.0), f"nüfus: {kind}"))
    strat = as_dict(run.result.get("strategy")) or as_dict(get(host, "heist", "strategy"))
    if num(strat.get("register_emptied_at_s")) is not None:
        t = float(num(strat.get("register_emptied_at_s")) or 0.0)
        o = owner_task_at(owner, t)
        at = f" (sahip o an: {o.get('state', '?')}/{o.get('task', '?')})" if o else ""
        rows.append((t, f"OYUNCU: kasa boşaltıldı{at}"))
    if num(strat.get("cash_bag_taken_at_s")) is not None:
        rows.append((float(num(strat.get("cash_bag_taken_at_s")) or 0.0), "OYUNCU: arka oda nakit çantası alındı"))
    if end_s is not None:
        rows.append((end_s, f"İŞ BİTTİ: {OUTCOMES.get(str(run.result.get('outcome')), str(run.result.get('outcome', '?')))}"))
    rows.sort(key=lambda r: r[0])
    if end_s is not None:
        rows = [(t, text + (" (iş sonrası)" if t > end_s + 0.05 else "")) for t, text in rows]
    return rows


# --------------------------------------------------------------------------------------------------------------------------------
# Report


class Report:
    def __init__(self, host: dict, host_path: str, clients: list[tuple[str, dict]]) -> None:
        self.host = host
        self.host_path = host_path
        self.clients = clients
        self.names = Names.collect([host] + [c for _, c in clients])
        self.runs, self.split_note = split_runs(host)
        self.out: list[str] = []

    def w(self, line: str = "") -> None:
        self.out.append(line)

    # -- session ------------------------------------------------------------------------------------------------------------

    def session(self) -> None:
        h, n = self.host, self.names
        self.w(f"# Kayıt özeti — {os.path.basename(self.host_path)}")
        self.w()
        self.w("## Oturum")
        files = [f"host `{os.path.basename(self.host_path)}` ({n.of(h.get('peer_id', 1))})"]
        files += [f"istemci `{os.path.basename(p)}` ({n.of(c.get('peer_id'))})" for p, c in self.clients]
        self.w(f"- Dosyalar: {', '.join(files)}")
        players = []
        for peer, name in n.by_peer.items():
            role = "host" if peer == peer_key(h.get("peer_id", 1)) else "istemci"
            players.append(f"{name} (p{peer}, {role})")
        self.w(f"- Oyuncular: {', '.join(players) if players else NONE}")
        level = str(h.get("level") or get(self.runs[0].marker, "level") or "?")
        seed = h.get("session_seed", get(self.runs[0].marker, "seed"))
        self.w(f"- Harita: `{level}` · tohum {seed if seed is not None else NONE} · koşu sayısı {len(self.runs)}")
        versions = [f"{k} {h[k]}" for k in VERSION_KEYS if k in h]
        if versions:
            self.w(f"- Sürüm: {', '.join(versions)}")
        reasons = [f"{n.of(h.get('peer_id', 1))} {h.get('log_reason', NONE)}"]
        for _, c in self.clients:
            lost = " (host kayboldu)" if c.get("host_lost") else ""
            reasons.append(f"{n.of(c.get('peer_id'))} {c.get('log_reason', NONE)}{lost}")
        self.w(f"- Kayıt nedeni: {', '.join(reasons)}")
        self.w(f"- Ping: {self.ping_text()}")
        modes = {as_dict(d.get('vision')).get('mode') for d in [h] + [c for _, c in self.clients]} - {None}
        self.w(f"- Görüş kipi: {', '.join(sorted(str(m) for m in modes)) if modes else NONE}")
        self.w(f"- Ekip nakdi (kayıt anı): {money(h.get('team_cash')) if 'team_cash' in h else NONE}")
        if self.split_note:
            self.w(f"- Not: {self.split_note}")
        self.w()

    def ping_text(self) -> str:
        n = self.names
        parts: list[str] = []
        host_peer = peer_key(self.host.get("peer_id", 1))
        for peer, ms in as_dict(self.host.get("ping_ms")).items():
            parts.append(f"host→{n.of(peer)} {money(ms)} ms")
        for _, c in self.clients:
            for peer, ms in as_dict(c.get("ping_ms")).items():
                if peer_key(peer) != host_peer:
                    continue
                samples = get(c, "ping", peer, "samples")
                extra = f" ({samples} örnek)" if samples is not None else ""
                parts.append(f"{n.of(c.get('peer_id'))}→host {money(ms)} ms{extra}")
        rtts = [
            f"{n.of(d.get('peer'))} {money(d.get('rtt_ms'))} ms"
            for d in map(as_dict, as_list(get(self.host, "owner", "detections")))
            if num(d.get("rtt_ms")) is not None and peer_key(d.get("peer")) != host_peer
        ]
        if rtts:
            parts.append(f"tespit anı RTT: {', '.join(rtts)}")
        return "; ".join(parts) if parts else NONE

    # -- runs ---------------------------------------------------------------------------------------------------------------

    def run_section(self, run: Run) -> None:
        h, n = self.host, self.names
        r = run.result
        level = str(run.marker.get("level") or h.get("level") or "?")
        seed = run.marker.get("seed")
        head = f"## Koşu {run.index} — `{os.path.basename(level)}`" + (f" (tohum {seed})" if seed is not None else "")
        self.w(head)
        if not run.finished:
            el = get(h, "heist", "elapsed")
            self.w(f"**Sonuç:** bitmedi (kayıt anında sürüyordu{', ' + sec(el) + ' sn' if el else ''})")
        else:
            outcome = str(r.get("outcome", "?"))
            parts = [f"{OUTCOMES.get(outcome, outcome)} (`{outcome}`)"]
            if "duration_s" in r:
                parts.append(f"{sec(r.get('duration_s'))} sn")
            if "loot_total" in r:
                parts.append(f"ganimet {money(r.get('loot_total'))}")
            if "payout" in r:
                ratio = f" (oran {r['payout_ratio']})" if "payout_ratio" in r else ""
                parts.append(f"ödeme {money(r.get('payout'))}{ratio}")
            if "bail" in r:
                parts.append(f"kefalet {money(r.get('bail'))}")
            if "cash_before" in r or "cash_after" in r:
                parts.append(f"ekip nakdi {money(r.get('cash_before'))} → {money(r.get('cash_after'))}")
            if "heat" in r:
                parts.append(f"ısı +{money(r.get('heat'))}")
            if "max_alert" in r:
                parts.append(f"en yüksek uyarı {money(r.get('max_alert'))}")
            self.w("**Sonuç:** " + " · ".join(parts))
        strat = as_dict(r.get("strategy")) or (as_dict(get(h, "heist", "strategy")) if run.live else {})
        if strat:
            sp = [f"sınıf {strat.get('class', '?')}"]
            if "back_door_used" in strat:
                sp.append(f"arka kapı {yes_no(strat.get('back_door_used'))}")
            if "interactions" in strat:
                sp.append(f"{strat.get('interactions')} etkileşim")
            if num(strat.get("register_emptied_at_s")) is not None:
                sp.append(f"kasa boşaltıldı {sec(strat.get('register_emptied_at_s'))} sn")
            if num(strat.get("cash_bag_taken_at_s")) is not None:
                sp.append(f"çanta alındı {sec(strat.get('cash_bag_taken_at_s'))} sn")
            ci = as_dict(strat.get("cover_intact"))
            if ci:
                sp.append("örtü sağlam: " + ", ".join(f"{n.of(p)} {yes_no(v)}" for p, v in ci.items()))
            self.w("**Strateji:** " + " · ".join(sp))
        notes = [as_dict(x) for x in as_list(r.get("notes"))]
        if notes:
            self.w("**Notlar:** " + ", ".join(f"{NOTES.get(str(x.get('kind')), x.get('kind'))} ({n.of(x.get('peer'))})" for x in notes))
        self.w()
        self.players_table(run)
        if run.events:
            self.w("**Olay sırası** (olaylarda zaman yok; sırayla):")
            for i, e in enumerate(run.events, 1):
                self.w(f"{i}. {event_text(as_dict(e), n)}")
            self.w()
        elif run.marker or len(self.runs) == 1:
            self.w("**Olay sırası:** olay yok")
            self.w()
        if run.live:
            self.live_sections(run)

    def players_table(self, run: Run) -> None:
        n, h = self.names, self.host
        players = as_dict(run.result.get("players"))
        peers = list(players.keys())
        if not peers and run.live:
            peers = list(as_dict(h.get("players")).keys())
        if not peers:
            return
        covers = {peer_key(d.get("peer")): d for d in events_of(run, "cover_broken")}
        if run.live:
            for peer, reason in as_dict(get(h, "heist", "cover_reason")).items():
                covers.setdefault(peer_key(peer), {"reason": reason, "by": get(h, "heist", "seen_by", peer)})
        intact = as_dict(get(run.result, "strategy", "cover_intact"))
        if not intact and run.live:
            intact = as_dict(get(h, "heist", "cover"))
        held = [peer_key(d.get("peer")) for d in events_of(run, "player_held")]
        caught_by = {peer_key(d.get("peer")): CATCHERS.get(str(d.get("by")), str(d.get("by"))) for d in events_of(run, "player_caught")}
        self.w("| Oyuncu | Durum | Tutulma | Ganimet | Kefalet | Tanınma | Örtü |")
        self.w("|---|---|---|---|---|---|---|")
        for peer in peers:
            p = as_dict(players.get(peer))
            key = peer_key(peer)
            if p.get("caught"):
                state = "yakalandı" + (f" ({caught_by[key]})" if key in caught_by else "")
            elif p.get("escaped"):
                state = "kaçtı"
            elif p.get("left"):
                state = "ayrıldı"
            elif p.get("witness_released"):
                state = "tanık olarak salındı"
            elif p:
                state = "serbest"
            else:
                state = "bitmedi"
            if key in covers:
                c = covers[key]
                reason = COVER_REASONS.get(str(c.get("reason")), str(c.get("reason", "?")))
                seen = f", gören {n.observer(c['by'])}" if c.get("by") else ""
                cover = f"bozuk: {reason}{seen}"
            elif key in intact:
                cover = "sağlam" if intact[key] else "bozuk"
            else:
                cover = NONE
            rec = p.get("recognized")
            self.w(
                f"| {n.of(peer)} | {state} | {held.count(key)} | {money(p.get('loot')) if 'loot' in p else '-'} | "
                f"{money(p.get('bail')) if 'bail' in p else '-'} | {rec if rec is not None else '-'} | {cover} |"
            )
        self.w()

    def live_sections(self, run: Run) -> None:
        h, n = self.host, self.names
        owner = as_dict(h.get("owner"))
        rows = timeline(h, run, n)
        self.w("**Zaman çizelgesi** (sn, seviye başından; sahip günlüğü + tespit/keşif/tutma + uyarı merdiveni + nüfus):")
        if rows:
            for t, text in rows:
                self.w(f"- {text}" if re.match(r"^\d+,\d–", text) else f"- {sec(t)} — {text}")
        else:
            self.w(f"- {NONE}")
        alert_hist = as_list(get(h, "alert", "history"))
        if alert_hist:
            self.w(f"- uyarı sırası (zamansız): {' → '.join(str(x) for x in alert_hist)}")
        if num(owner.get("log_dropped")):
            self.w(f"- (sahip günlüğünden {money(owner.get('log_dropped'))} eski satır düştü)")
        self.w()
        # Questions
        qs = [as_dict(q) for q in as_list(owner.get("search_questions"))]
        wq = as_list(owner.get("window_questions"))
        if "search_questions" in owner or "window_questions" in owner:
            parts = []
            parts.append(
                "aramada sorgu: " + (", ".join(f"{n.of(q.get('peer'))} {sec(q.get('t'))} sn (şüphe {money(q.get('value'))})" for q in qs) or "yok")
                if "search_questions" in owner
                else "aramada sorgu: " + NONE
            )
            parts.append("pencere sorusu: " + (", ".join(n.of(p) for p in wq) or "yok"))
            self.w("**Sorgular:** " + " · ".join(parts))
        # Shop / order
        shop = as_dict(h.get("shop"))
        sp = []
        if shop:
            sp.append(
                f"raf: alınan {shop.get('taken', '?')}, ödenen {shop.get('paid', '?')}, bırakılan {shop.get('dropped', '?')}"
            )
            if "order" in shop:
                who = f" ({n.of(shop.get('order_peer'))})" if num(shop.get("order_peer")) else ""
                sp.append(f"sipariş {shop.get('order')}{who}")
        sent = events_of(run, "owner_sent")
        if sent:
            sp.append("GÖNDER: " + ", ".join(n.of(d.get("peer")) for d in sent))
        if as_list(owner.get("sent_windows")):
            sp.append("pencere " + ", ".join(f"{sec(x)} sn" for x in owner["sent_windows"]))
        if "send_costs" in owner:
            costs = [as_dict(c) for c in as_list(owner.get("send_costs"))]
            sp.append("dönüş bedeli " + (", ".join(f"{n.of(c.get('peer'))} {money(c.get('amount'))}" for c in costs) or "yok"))
        purchases = events_of(run, "purchase")
        if purchases:
            sp.append(f"satın alma {len(purchases)}")
        if sp:
            self.w("**Alışveriş / sipariş:** " + " · ".join(sp))
        # Doors / bell
        dp = []
        for name, prop in as_dict(h.get("props")).items():
            if "door" not in name.lower():
                continue
            prop = as_dict(prop)
            it = as_dict(prop.get("interact"))
            dp.append(
                f"{name}: oyuncu {it.get('completed', '?')} kez, NPC {it.get('npc_uses', '?')} kez, "
                f"{prop.get('flips', '?')} değişim, kendiliğinden kapanma {prop.get('autocloses', '?')}"
            )
        bells = num(get(owner, "agenda_noises", "bell"))
        log_whys = [str(as_dict(r).get("why", "")) for r in as_list(owner.get("log"))]
        if bells is not None or log_whys:
            looks = sum(1 for w in log_whys if w.startswith("zil -> "))
            ignored = sum(1 for w in log_whys if w.startswith("zil, tepki yok") or w.startswith("zil duyulmadı"))
            listens = sum(1 for w in log_whys if "DİNLE" in w)
            dp.append(f"zil {money(bells) if bells is not None else '?'} (bakış {looks}, tepkisiz/duymadı {ignored}); DİNLE {listens}")
        if dp:
            self.w("**Kapı / zil:** " + " · ".join(dp))
        pop = as_dict(h.get("population"))
        if pop:
            self.w(
                f"**Nüfus:** müşteri {pop.get('customers_spawned', '?')}, yoldan geçen {pop.get('passersby_spawned', '?')}, "
                f"servis {pop.get('served', '?')}, kaçan {pop.get('flees', '?')}, bakış {pop.get('looks', '?')}, "
                f"ihbar {pop.get('tells', '?')}"
            )
        self.w()

    # -- protocol answers ---------------------------------------------------------------------------------------------------

    def answers(self) -> None:
        rows = [
            ("A1", "Sonuç ve süre", self.a_a1),
            ("A2", "En yüksek uyarı, ganimet/ödeme", self.a_a2),
            ("B2", "Kasa / arka oda nakdi zamanı", self.a_b2),
            ("C1", "Strateji; kasa boşalırken sahip", self.a_c1),
            ("C2", "Keşif/bağırış ↔ iş sonu", self.a_c2),
            ("D2", "Kaçış geri sayımı", self.a_d2),
            ("E1", "Kapılar", self.a_e1),
            ("E2", "Zil → sahip tepkisi", self.a_e2),
            ("F1", "Kasa sahibin gözü önünde mi", self.a_f1),
            ("F3", "Keşif (kaynak, zaman)", self.a_f3),
            ("G1", "Raf alışverişi", self.a_g1),
            ("G2", "Damacana / GÖNDER", self.a_g2),
            ("G3", "Örtü (neden, gören, tanınma)", self.a_g3),
            ("H1", "Kim, kim tarafından yakalandı", self.a_h1),
            ("J1", "Ağ (ping, kopma, kayıt nedeni)", self.a_j1),
        ]
        self.w("## Protokol §2 — kayıttan cevaplar (D kaynaklı satırlar)")
        self.w()
        self.w("| # | Satır | " + " | ".join(f"T{r.index}" for r in self.runs) + " |")
        self.w("|---|---|" + "---|" * len(self.runs))
        for rid, label, fn in rows:
            cells = []
            for run in self.runs:
                try:
                    cell = fn(run) or NONE
                except (KeyError, TypeError, ValueError, IndexError, AttributeError):
                    cell = NONE
                cells.append(cell.replace("|", "/"))
            self.w(f"| {rid} | {label} | " + " | ".join(cells) + " |")
        self.w()

    def owner_live(self, run: Run) -> dict:
        return as_dict(self.host.get("owner")) if run.live else {}

    def a_a1(self, run: Run) -> str:
        r = run.result
        if not r:
            return "bitmedi"
        outcome = str(r.get("outcome", "?"))
        return f"{OUTCOMES.get(outcome, outcome)}, {sec(r.get('duration_s'))} sn"

    def a_a2(self, run: Run) -> str:
        r = run.result
        if not r:
            return ""
        return f"uyarı {money(r.get('max_alert'))}; ganimet {money(r.get('loot_total'))}; ödeme {money(r.get('payout'))}"

    def strategy(self, run: Run) -> dict:
        return as_dict(run.result.get("strategy")) or (as_dict(get(self.host, "heist", "strategy")) if run.live else {})

    def a_b2(self, run: Run) -> str:
        s = self.strategy(run)
        parts = []
        if num(s.get("register_emptied_at_s")) is not None:
            parts.append(f"kasa {sec(s['register_emptied_at_s'])} sn")
        if num(s.get("cash_bag_taken_at_s")) is not None:
            parts.append(f"çanta {sec(s['cash_bag_taken_at_s'])} sn")
        return "; ".join(parts)

    def a_c1(self, run: Run) -> str:
        s = self.strategy(run)
        if not s:
            return ""
        out = f"{s.get('class', '?')}"
        owner = self.owner_live(run)
        t = num(s.get("register_emptied_at_s"))
        if owner and t is not None:
            o = owner_task_at(owner, t)
            if o:
                out += f"; kasa boşalırken sahip {o.get('state', '?')}/{o.get('task', '?')}"
        return out

    def a_c2(self, run: Run) -> str:
        owner = self.owner_live(run)
        end = num(run.result.get("duration_s"))
        parts = []
        disc = [as_dict(d) for d in as_list(owner.get("discoveries"))]
        if disc and num(disc[0].get("t")) is not None:
            t = float(num(disc[0].get("t")) or 0.0)
            parts.append(f"keşif {sec(t)} ({SOURCES_SHORT.get(str(disc[0].get('source')), '?')})")
        shout_t = None
        for step in as_list(get(self.host, "chasers", "ladder")) if run.live else []:
            if isinstance(step, list) and len(step) >= 2 and (num(step[0]) or 0) >= 2:
                shout_t = num(step[1])
                break
        if shout_t is not None:
            parts.append(f"bağırış {sec(shout_t)}")
            if end is not None:
                parts.append(f"iş sonundan {sec(end - shout_t)} sn önce")
        if not parts:
            kinds = [str(e.get("kind")) for e in run.events]
            if "owner_discover" in kinds or "shout" in kinds:
                return "keşif/bağırış var (zaman yalnız son koşuda)"
            return "keşif/bağırış yok" if run.events else ""
        return "; ".join(parts)

    def a_d2(self, run: Run) -> str:
        if not run.live:
            return ""
        heist = as_dict(self.host.get("heist"))
        parts = []
        if num(heist.get("settle_peak_s")) is not None:
            parts.append(f"geri sayım tepe {sec(heist.get('settle_peak_s'))} sn")
        if num(heist.get("abort_peak_s")) is not None:
            parts.append(f"çekilme tepe {sec(heist.get('abort_peak_s'))} sn")
        return "; ".join(parts)

    def a_e1(self, run: Run) -> str:
        if not run.live:
            return ""
        parts = []
        for name, prop in as_dict(self.host.get("props")).items():
            if "door" in name.lower():
                prop = as_dict(prop)
                parts.append(
                    f"{name} oyuncu {get(prop, 'interact', 'completed', default='?')}, "
                    f"kendiliğinden kapanma {prop.get('autocloses', '?')}"
                )
        return "; ".join(parts)

    def a_e2(self, run: Run) -> str:
        owner = self.owner_live(run)
        whys = [str(as_dict(r).get("why", "")) for r in as_list(owner.get("log"))]
        if not whys:
            return ""
        looks = sum(1 for w in whys if w.startswith("zil -> "))
        ignored = sum(1 for w in whys if w.startswith("zil, tepki yok") or w.startswith("zil duyulmadı"))
        listens = sum(1 for w in whys if "DİNLE" in w)
        door = sum(1 for w in whys if "'door'" in w)
        return f"zile bakış {looks}, tepkisiz {ignored}; DİNLE {listens}; kapı sesi {door}"

    def a_f1(self, run: Run) -> str:
        owner = self.owner_live(run)
        t = num(self.strategy(run).get("register_emptied_at_s"))
        if not owner or t is None:
            return ""
        o = owner_task_at(owner, t)
        near = [
            as_dict(d)
            for d in as_list(owner.get("detections"))
            if num(as_dict(d).get("t_detect")) is not None and abs(float(num(as_dict(d).get("t_detect")) or 0.0) - t) <= 2.0
        ]
        seen = f"±2 sn'de tespit {len(near)}" if near else "±2 sn'de tespit yok"
        return f"kasa {sec(t)}: sahip {o.get('state', '?')}/{o.get('task', '?')}; {seen}"

    def a_f3(self, run: Run) -> str:
        owner = self.owner_live(run)
        disc = [as_dict(d) for d in as_list(owner.get("discoveries"))]
        if disc:
            return "; ".join(
                f"{SOURCES_SHORT.get(str(d.get('source')), '?')} {sec(d.get('t'))} ({TRIGGERS.get(str(d.get('trigger')), d.get('trigger', '?'))})"
                for d in disc
            )
        ev = events_of(run, "owner_discover")
        if ev:
            return ", ".join(SOURCES_SHORT.get(str(d.get("source")), "?") for d in ev) + " (zaman yalnız son koşuda)"
        return "keşif yok" if run.events or owner else ""

    def a_g1(self, run: Run) -> str:
        if not run.live:
            p = events_of(run, "purchase")
            return f"satın alma {len(p)}" if p else ""
        shop = as_dict(self.host.get("shop"))
        if not shop:
            return ""
        return f"alınan {shop.get('taken', '?')}, ödenen {shop.get('paid', '?')}, bırakılan {shop.get('dropped', '?')}"

    def a_g2(self, run: Run) -> str:
        n = self.names
        parts = []
        sent = events_of(run, "owner_sent")
        if sent:
            parts.append("GÖNDER " + ", ".join(n.of(d.get("peer")) for d in sent))
        owner = self.owner_live(run)
        if as_list(owner.get("sent_windows")):
            parts.append("pencere " + ", ".join(f"{sec(x)} sn" for x in owner["sent_windows"]))
        if "send_costs" in owner:
            costs = as_list(owner.get("send_costs"))
            parts.append("bedel " + (", ".join(money(as_dict(c).get("amount")) for c in costs) or "yok"))
        shop = as_dict(self.host.get("shop")) if run.live else {}
        if "order" in shop:
            parts.append(f"sipariş {shop.get('order')}")
        if not parts and run.events:
            return "GÖNDER yok"
        return "; ".join(parts)

    def a_g3(self, run: Run) -> str:
        n = self.names
        covers = events_of(run, "cover_broken")
        parts = [
            f"{n.of(d.get('peer'))} {COVER_REASONS.get(str(d.get('reason')), d.get('reason', '?'))}"
            + (f" (gören {n.observer(d['by'])})" if d.get("by") else "")
            for d in covers
        ]
        intact = as_dict(get(run.result, "strategy", "cover_intact"))
        ok = [n.of(p) for p, v in intact.items() if v]
        if ok:
            parts.append("sağlam: " + ", ".join(ok))
        rec = [f"{n.of(p)} {as_dict(v).get('recognized')}" for p, v in as_dict(run.result.get("players")).items() if as_dict(v).get("recognized")]
        if rec:
            parts.append("tanınma: " + ", ".join(rec))
        if not parts and run.events:
            return "örtü bozulmadı"
        return "; ".join(parts)

    def a_h1(self, run: Run) -> str:
        n = self.names
        caught = events_of(run, "player_caught")
        parts = [f"{n.of(d.get('peer'))} ← {CATCHERS.get(str(d.get('by')), d.get('by', '?'))}" for d in caught]
        rescued = events_of(run, "player_rescued")
        if rescued:
            parts.append("kurtarılan: " + ", ".join(n.of(d.get("peer")) for d in rescued))
        owner = self.owner_live(run)
        if "detections" in owner:
            parts.append(f"tespit {len(as_list(owner.get('detections')))}")
        if not parts and run.events:
            return "yakalanan yok"
        return "; ".join(parts)

    def a_j1(self, run: Run) -> str:
        if not run.live:
            return ""
        lost = [self.names.of(c.get("peer_id")) for _, c in self.clients if c.get("host_lost")]
        out = f"ping: {self.ping_text()}; kayıt {self.host.get('log_reason', '?')}"
        if lost:
            out += "; host kaybı: " + ", ".join(lost)
        return out

    def render(self) -> str:
        self.session()
        for run in self.runs:
            self.run_section(run)
        self.answers()
        return "\n".join(self.out).rstrip() + "\n"


# --------------------------------------------------------------------------------------------------------------------------------
# CLI


def load(path: str) -> tuple[dict | None, str]:
    try:
        with open(path, encoding="utf-8-sig") as f:
            d = json.load(f)
    except (OSError, ValueError) as e:
        return None, f"{path}: okunamadı ({e})"
    if not isinstance(d, dict):
        return None, f"{path}: döküm sözlük değil"
    return d, ""


def summarize(paths: list[str]) -> tuple[str, list[str]]:
    """Markdown summary of the given log files and the problems met (unreadable files, no host)."""
    problems: list[str] = []
    loaded: list[tuple[str, dict]] = []
    for p in paths:
        d, err = load(p)
        if d is None:
            problems.append(err)
        else:
            loaded.append((p, d))
    hosts = [(p, d) for p, d in loaded if d.get("is_host") is True]
    clients = [(p, d) for p, d in loaded if d.get("is_host") is not True]
    if not hosts and loaded:
        # No host file: summarise the richest dump (host-only fields are then mostly missing).
        best = max(loaded, key=lambda pd: len(as_list(get(pd[1], "owner", "log"))) + len(as_list(pd[1].get("events"))))
        problems.append(f"host dosyası yok (is_host); {os.path.basename(best[0])} özetlendi")
        hosts = [best]
        clients = [pd for pd in loaded if pd is not best]
    parts = [Report(d, p, clients).render() for p, d in hosts]
    return "\n".join(parts), problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Test kayıt dosyalarını (--log-on-exit) okunur Markdown özete çevirir (IS-111)")
    ap.add_argument("files", nargs="+", help="kayit-*.json (host + istemciler, sıra önemsiz)")
    ap.add_argument("--md", help="özeti bu dosyaya yaz (UTF-8); yoksa stdout")
    args = ap.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")  # Windows console: owner.log lines and messages are UTF-8 Turkish
    text, problems = summarize(args.files)
    for p in problems:
        print(f"UYARI: {p}", file=sys.stderr)
    if not text:
        print("Okunabilir kayıt yok.", file=sys.stderr)
        return 1
    if args.md:
        os.makedirs(os.path.dirname(os.path.abspath(args.md)), exist_ok=True)
        with open(args.md, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print(f"Özet yazıldı: {args.md}")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
