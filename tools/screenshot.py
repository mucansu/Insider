#!/usr/bin/env python3
"""Ekran görüntüsü aracı (IS-022; mimari.md S6). Yalnız Python standart kütüphanesi.

Kullanım:
    python tools/screenshot.py --at 3,6,9 [--name ad] [--scenario tests/net/<senaryo>.json]
        [--level res://levels/store_a.tscn] [--clients 2] [--bot host=res://... --bot c1=...]
        [--start-delay c2=1.0] [--player-scene res://...] [--peers host,c1|all] [--window-size 1280x720]
        [--out build/screens] [--godot-gui PATH] [--min-stddev 8] [--force] [--verbose]

Seviye + botlarla host ve istemciler açılır (tools/net_smoke.py ile aynı düzen: boş UDP portu, host'un
`INSIDERS_READY` satırı beklenir, istemciler `start_delay` sonra başlar, herkes `--quit-after` ile kapanır,
sert zaman aşımında süreç ağaçları öldürülür). Görüntüsü istenen peer'lar (`--peers`) GPU'lu pencerede
(GUI exe, `--window-size`), diğerleri `--headless` koşar. `--at` anları host'un saatine göre saniyedir (host
main.gd açılışı ≈ READY satırı); her sürece kendi saatine çevrilip `--screenshot-at` olarak verilir (saat kayması
= Popen farkı + açılış süresi farkı, bkz. clock_offset; peer'lar arası hizalama ~±0,5 sn; süreç başlamadan önceki an
o peer için atlanır). Çıktı: `<out>/<ad>/<peer>_<an>.png` (ör. build/screens/store_walk/c1_6.png); eski PNG'ler silinir.
Doğrulama: her PNG pencere boyutunda ve boş/siyah değil (parlaklık std sapması >= --min-stddev ve en az
MIN_COLORS farklı renk); geçersiz olan `<peer>_<an>_INVALID.png` adıyla ayrılır ve FAIL'dir. Log'da ERROR satırı ya
da sıfır olmayan çıkış kodu da başarısızlıktır. O peer'da seviye henüz yüklenmemişken (istemci bağlanıyor; Godot
`INSIDERS_SCREENSHOT skipped ... reason=level_not_loaded` basar) ya da süreç başlamadan önceye düşen an FAIL değildir:
"atlandı: <peer> <an> sn: <neden>" satırıyla raporlanır.

`--scenario`: net_smoke senaryosundan level, player_scene, clients, bots, start_delay, names okunur
(beklentiler yok sayılır); komut satırı seçenekleri senaryonun üstüne yazar. Varsayılan seviye store_a,
oyuncu sahnesi gerçek oyuncu (entities/player/player.tscn), 2 istemci, bot yok.

Godot: GUI exe `--godot-gui`, yoksa GODOT_GUI ortam değişkeni, yoksa GODOT `*_console.exe` ise yanındaki
`*.exe` (Windows), yoksa GODOT'un kendisi. Headless süreçler için GODOT (yoksa tools/get_godot.sh).
Ekran yoksa (CI ortam değişkeni, Linux'ta DISPLAY/WAYLAND_DISPLAY yok, Windows'ta masaüstü yok) "atlandı" der ve
0 döner (`--force` bu denetimi kapatır). Çıkış kodu: 0 = bütün görüntüler alındı ve geçerli (ya da atlandı).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import time
import zlib
from dataclasses import dataclass
from typing import Any, Callable

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

from net_smoke import (  # noqa: E402
    ERROR_LINE,
    HOST_READY_TIMEOUT,
    LINGER_SEC,
    WINDOWS,
    Proc,
    find_godot,
    free_udp_port,
)

DEFAULT_LEVEL = "res://levels/store_a.tscn"
DEFAULT_PLAYER_SCENE = "res://entities/player/player.tscn"
DEFAULT_WINDOW = (1280, 720)
DEFAULT_OUT = os.path.join("build", "screens")
# Son andan sonra ortak --quit-after'a kadar pay (son görüntü yazılsın; geç açılan pencerenin saati kayık olabilir).
TAIL_SEC = 2.0
# Popen → main._start süresi tahmini (sn; Windows, RX 6650 XT ölçümü: pencereli 1,2-1,7, headless ~0,45).
# Host'unki ölçülür (READY satırı); istemci host'la aynı türdeyse onunki, değilse bu tahmin kullanılır.
STARTUP_ESTIMATE = {"window": 1.5, "headless": 0.4}
# İstemcilerin ayrılış aralığı (sn); net_smoke'un LEAVE_STAGGER'ından geniş: saatler tahminle hizalı.
LEAVE_GAP = 1.0
# Sürecin başlangıcından önceki ya da bu kadar yakın anlar o süreç için atlanır (pencere henüz çizilmemiş olur).
MIN_LOCAL_SEC = 0.1
DEFAULT_MIN_STDDEV = 8.0
MIN_COLORS = 16
SAMPLE_STEP = 4
# Pencereler basamaklı açılır (biri ötekini tamamen örtmesin).
WINDOW_ORIGIN = (40, 40)
WINDOW_CASCADE = (60, 40)
SCENARIO_KEYS_USED = ("level", "player_scene", "clients", "bots", "start_delay", "names")


# --- saf yardımcılar (tools/test_screenshot.py) ---


def parse_moments(text: str) -> list[float]:
    """"6,2.5,6" → [2.5, 6.0]; 0,01 sn çözünürlükte tekrarsız, artan. Bozuk/negatif öğe ValueError."""
    out: set[float] = set()
    for part in text.split(","):
        s = part.strip()
        if not s:
            raise ValueError(f"boş an: {text!r}")
        t = float(s)
        if not t >= 0.0 or t != t or t == float("inf"):
            raise ValueError(f"geçersiz an: {s!r}")
        out.add(round(t, 2))
    return sorted(out)


def moment_label(t: float) -> str:
    """Dosya adındaki an: 6.0 → "6", 2.5 → "2.5"."""
    return f"{round(t, 2):g}"


def parse_window_size(text: str) -> tuple[int, int]:
    m = re.fullmatch(r"\s*(\d+)[xX](\d+)\s*", text)
    if not m:
        raise ValueError(f"pencere boyutu GxY olmalı: {text!r}")
    w, h = int(m.group(1)), int(m.group(2))
    if not (64 <= w <= 16384 and 64 <= h <= 16384):
        raise ValueError(f"pencere boyutu aralık dışı: {text!r}")
    return w, h


def parse_kv(items: list[str], what: str) -> dict[str, str]:
    """["host=a", "c1=b"] → {"host": "a", "c1": "b"}."""
    out: dict[str, str] = {}
    for item in items:
        key, sep, value = item.partition("=")
        if not sep or not key.strip() or not value.strip():
            raise ValueError(f"{what} PEER=DEĞER biçiminde olmalı: {item!r}")
        out[key.strip()] = value.strip()
    return out


def peer_names(clients: int) -> list[str]:
    return ["host"] + [f"c{i}" for i in range(1, clients + 1)]


def parse_peers(text: str, clients: int) -> list[str]:
    """"all" ya da "host,c2" → geçerli peer adları (sıra korunur); bilinmeyen ad ValueError."""
    names = peer_names(clients)
    if text.strip().lower() == "all":
        return names
    out: list[str] = []
    for part in text.split(","):
        p = part.strip()
        if p not in names:
            raise ValueError(f"bilinmeyen peer {p!r} (geçerli: {', '.join(names)}, all)")
        if p not in out:
            out.append(p)
    if not out:
        raise ValueError("en az bir peer gerekir")
    return out


def local_moments(moments: list[float], offset: float) -> list[tuple[float, float]]:
    """Host başlangıcına göre anları, host'tan `offset` sn sonra başlayan sürecin saatine çevirir:
    [(küresel an, yerel an)]; yerel an MIN_LOCAL_SEC'ten küçükse (süreç henüz yok/çizmedi) atlanır."""
    out: list[tuple[float, float]] = []
    for t in moments:
        local = round(t - offset, 2)
        if local >= MIN_LOCAL_SEC:
            out.append((t, local))
    return out


def clock_offset(launched_at: float, host_startup: float, kind: str, host_kind: str) -> float:
    """Host saatinin sıfırına göre, host başlatılmasından `launched_at` sn sonra Popen'lanan sürecin saat sıfırı.
    Host'un sıfırı ≈ Popen + host_startup (ölçülen, READY); sürecinki ≈ Popen + kendi açılış süresi (host'la aynı
    türdeyse host_startup, değilse STARTUP_ESTIMATE). Pencereli açılış headless'tan ~1 sn yavaştır."""
    startup = host_startup if kind == host_kind else STARTUP_ESTIMATE[kind]
    return round(launched_at - host_startup + startup, 2)


def quit_after_for(name: str, duration: float, offset: float, clients: int) -> float:
    """Ayrılış sırası (host saatiyle): cN `duration + LEAVE_GAP x (N-1)` anında çıkar, host en son
    (`duration + LEAVE_GAP x clients + LINGER_SEC`) — saat tahmini ±0,5 sn şaşsa da iki istemci aynı host karesinde
    kopmaz (net_smoke LEAVE_STAGGER notu: motor "max channels: 0" hatası) ve istemciler host kaybı görmez.
    `offset`: sürecin saat sıfırının host'unkine göre kayması (clock_offset)."""
    if name == "host":
        return duration + (LEAVE_GAP * clients + LINGER_SEC if clients > 0 else 0.0)
    return max(1.0, duration - offset + LEAVE_GAP * (int(name[1:]) - 1))


def display_skip_reason(
    env: dict[str, str] | None = None,
    platform: str | None = None,
    has_desktop: Callable[[], bool] | None = None,
) -> str:
    """Görüntü alınamayacak ortamın nedeni; ekran varsa boş dize."""
    env = dict(os.environ) if env is None else env
    platform = sys.platform if platform is None else platform
    ci = env.get("CI", "").strip().lower()
    if ci and ci not in ("0", "false", "no"):
        return "CI ortamı (CI ortam değişkeni)"
    if platform.startswith("linux") or "bsd" in platform:
        if not env.get("DISPLAY") and not env.get("WAYLAND_DISPLAY"):
            return "ekran yok (DISPLAY/WAYLAND_DISPLAY tanımsız)"
    if platform == "win32" and not (has_desktop or _windows_has_desktop)():
        return "etkileşimli masaüstü yok"
    return ""


def _windows_has_desktop() -> bool:
    if not WINDOWS:
        return True
    try:
        import ctypes

        return int(ctypes.windll.user32.GetSystemMetrics(0)) > 0  # SM_CXSCREEN
    except (AttributeError, OSError):
        return False


def resolve_gui_godot(explicit: str | None, env: dict[str, str] | None = None) -> str:
    """Pencereli Godot: --godot-gui > GODOT_GUI > GODOT'un *_console.exe kardeşi > GODOT (ya da get_godot.sh)."""
    env = dict(os.environ) if env is None else env
    if explicit:
        return explicit
    if env.get("GODOT_GUI"):
        return env["GODOT_GUI"]
    console = env.get("GODOT") or find_godot()
    base, ext = os.path.splitext(console)
    if base.endswith("_console"):
        sibling = base[: -len("_console")] + ext
        if os.path.exists(sibling):
            return sibling
    return console


# --- PNG okuma ve doğrulama (yalnız stdlib) ---


@dataclass
class PngInfo:
    width: int
    height: int
    stddev: float
    colors: int


def _unfilter(raw: bytes, width: int, height: int, bpp: int) -> list[bytes]:
    stride = width * bpp
    rows: list[bytes] = []
    prev = bytearray(stride)
    pos = 0
    for _ in range(height):
        ftype = raw[pos]
        line = bytearray(raw[pos + 1 : pos + 1 + stride])
        pos += 1 + stride
        if ftype == 1:  # Sub
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif ftype == 2:  # Up
            line = bytearray((a + b) & 0xFF for a, b in zip(line, prev))
        elif ftype == 3:  # Average
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif ftype == 4:  # Paeth
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
        elif ftype != 0:
            raise ValueError(f"bilinmeyen PNG süzgeci {ftype}")
        rows.append(bytes(line))
        prev = line
    return rows


def read_png_stats(path: str, step: int = SAMPLE_STEP) -> PngInfo:
    """8 bit gri/RGB/RGBA, taramasız PNG'yi okur; `step` aralıklı örneklerde parlaklık std sapması ve renk sayısı."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("PNG imzası yok")
    pos = 8
    width = height = 0
    bit_depth = color_type = interlace = -1
    idat = bytearray()
    while pos + 8 <= len(data):
        length, ctype = struct.unpack(">I4s", data[pos : pos + 8])
        body = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif ctype == b"IDAT":
            idat += body
        elif ctype == b"IEND":
            break
    channels = {0: 1, 2: 3, 4: 2, 6: 4}.get(color_type)
    if channels is None or bit_depth != 8 or interlace != 0:
        raise ValueError(f"desteklenmeyen PNG (renk türü {color_type}, {bit_depth} bit, tarama {interlace})")
    rows = _unfilter(zlib.decompress(bytes(idat)), width, height, channels)
    n = 0
    total = 0.0
    total_sq = 0.0
    colors: set[bytes] = set()
    for y in range(0, height, step):
        row = rows[y]
        for x in range(0, width, step):
            px = row[x * channels : x * channels + channels]
            if channels >= 3:
                lum = 0.299 * px[0] + 0.587 * px[1] + 0.114 * px[2]
                colors.add(px[:3])
            else:
                lum = float(px[0])
                colors.add(px[:1])
            n += 1
            total += lum
            total_sq += lum * lum
    mean = total / n if n else 0.0
    var = max(0.0, total_sq / n - mean * mean) if n else 0.0
    return PngInfo(width, height, var**0.5, len(colors))


def check_png(path: str, size: tuple[int, int], min_stddev: float) -> str:
    """Geçerliyse boş dize, değilse sorun."""
    if not os.path.exists(path):
        return "dosya yok"
    try:
        info = read_png_stats(path)
    except (OSError, ValueError, zlib.error, struct.error) as e:
        return f"okunamadı: {e}"
    if (info.width, info.height) != size:
        return f"boyut {info.width}x{info.height} (beklenen {size[0]}x{size[1]})"
    if info.stddev < min_stddev or info.colors < MIN_COLORS:
        return f"boş/tek renk görünüyor (std {info.stddev:.1f} < {min_stddev:g} ya da {info.colors} renk < {MIN_COLORS})"
    return ""


# --- sonuç toplama ---

SCREENSHOT_MARKER = "INSIDERS_SCREENSHOT"  # main.gd SCREENSHOT_MARKER
_MARKER_LINE = re.compile(rf"^{SCREENSHOT_MARKER} (ok|skipped|failed) at=(\S+)(?: reason=(\S+))?")
SKIP_REASONS = {"level_not_loaded": "seviye henüz yüklenmemişti (istemci bağlanıyor/yüklüyor)"}
INVALID_SUFFIX = "_INVALID"


def parse_markers(lines: list[str]) -> dict[float, tuple[str, str]]:
    """Godot'un `INSIDERS_SCREENSHOT <durum> at=SN [reason=R]` satırları → {yerel an: (durum, neden)}."""
    out: dict[float, tuple[str, str]] = {}
    for line in lines:
        m = _MARKER_LINE.match(line.strip())
        if m:
            try:
                out[round(float(m.group(2)), 2)] = (m.group(1), m.group(3) or "")
            except ValueError:
                continue
    return out


def collect_shots(
    expected: dict[str, list[tuple[float, float]]],
    lines: dict[str, list[str]],
    raw_root: str,
    out_dir: str,
    window: tuple[int, int],
    min_stddev: float,
) -> tuple[list[str], list[str], list[str]]:
    """Ham `shot_NN.png`'leri `<peer>_<an>.png` adına taşır ve doğrular → (geçerli yollar, atlanan anlar, hatalar).
    Godot'un "skipped" dediği an (seviye yüklenmeden önce) hata değildir, açıkça atlandı listesine girer. Geçersiz
    görüntü sonuç sanılmasın diye `<peer>_<an>_INVALID.png` adıyla bırakılır ve hata sayılır."""
    written: list[str] = []
    skipped: list[str] = []
    failures: list[str] = []
    for name, shots in expected.items():
        markers = parse_markers(lines.get(name, []))
        for index, (t, local) in enumerate(shots):
            label = f"{name}_{moment_label(t)}"
            status, reason = markers.get(round(local, 2), ("", ""))
            src = os.path.join(raw_root, name, f"shot_{index:02d}.png")
            dst = os.path.join(out_dir, label + ".png")
            if status == "skipped":
                skipped.append(f"{name} {moment_label(t)} sn: {SKIP_REASONS.get(reason, reason or 'Godot atladı')}")
                continue
            if os.path.exists(src):
                os.replace(src, dst)
            problem = check_png(dst, window, min_stddev)
            if not problem:
                written.append(dst)
                continue
            shown = os.path.relpath(dst, ROOT) if os.path.exists(dst) else label + ".png"
            if os.path.exists(dst):
                bad = os.path.join(out_dir, label + INVALID_SUFFIX + ".png")
                os.replace(dst, bad)
                shown += f" (geçersiz; {os.path.basename(bad)} olarak ayrıldı)"
            if status == "failed":
                problem += f"; Godot: {reason}"
            failures.append(f"{shown}: {problem}")
    return written, skipped, failures


# --- koşu ---


@dataclass
class Plan:
    name: str
    level: str
    player_scene: str
    clients: int
    bots: dict[str, str]
    start_delay: dict[str, float]
    display_names: dict[str, str]
    moments: list[float]
    peers: list[str]
    window: tuple[int, int]
    out_dir: str
    min_stddev: float


def build_plan(args: argparse.Namespace) -> Plan:
    sc: dict[str, Any] = {}
    if args.scenario:
        with open(args.scenario, encoding="utf-8") as f:
            sc = json.load(f)
        if not isinstance(sc, dict):
            raise ValueError("senaryo bir JSON nesnesi olmalı")
    clients = args.clients if args.clients is not None else int(sc.get("clients", 2))
    if clients < 0:
        raise ValueError("istemci sayısı >= 0 olmalı")
    bots = {str(k): str(v) for k, v in sc.get("bots", {}).items()}
    bots.update(parse_kv(args.bot, "--bot"))
    delays = {str(k): float(v) for k, v in sc.get("start_delay", {}).items()}
    delays.update({k: float(v) for k, v in parse_kv(args.start_delay, "--start-delay").items()})
    valid = set(peer_names(clients))
    for what, keys in (("--bot", bots), ("--start-delay", delays)):
        unknown = sorted(set(keys) - valid)
        if unknown:
            raise ValueError(f"{what}: bilinmeyen peer {', '.join(unknown)}")
    if args.name:
        name = args.name
    elif args.scenario:
        name = os.path.splitext(os.path.basename(args.scenario))[0]
    else:
        name = os.path.splitext(os.path.basename(args.level or DEFAULT_LEVEL))[0]
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", name):
        raise ValueError(f"ad yalnız harf, rakam, _ . - içerebilir: {name!r}")
    return Plan(
        name=name,
        level=args.level or sc.get("level", DEFAULT_LEVEL),
        player_scene=args.player_scene or sc.get("player_scene", DEFAULT_PLAYER_SCENE),
        clients=clients,
        bots=bots,
        start_delay=delays,
        display_names={str(k): str(v) for k, v in sc.get("names", {}).items()},
        moments=parse_moments(args.at),
        peers=parse_peers(args.peers, clients),
        window=parse_window_size(args.window_size),
        out_dir=os.path.join(args.out if os.path.isabs(args.out) else os.path.join(ROOT, args.out), name),
        min_stddev=args.min_stddev,
    )


def _prepare_out(out_dir: str) -> str:
    os.makedirs(out_dir, exist_ok=True)
    # Proje içindeki çıktı kökü Godot içe aktarmasına girmesin (PNG'ler .import/.godot önbelleği üretmesin).
    gdignore = os.path.join(os.path.dirname(out_dir), ".gdignore")
    if not os.path.exists(gdignore):
        open(gdignore, "w", encoding="utf-8").close()
    for f in os.listdir(out_dir):
        if f.endswith((".png", ".png.import")):
            os.remove(os.path.join(out_dir, f))
    raw = os.path.join(out_dir, ".raw")
    shutil.rmtree(raw, ignore_errors=True)
    return raw


def run(plan: Plan, gui_godot: str, verbose: bool) -> int:
    t_begin = time.monotonic()
    console_godot = find_godot()
    raw_root = _prepare_out(plan.out_dir)
    tmp = tempfile.mkdtemp(prefix="screenshot_")
    duration = plan.moments[-1] + TAIL_SEC
    host_port = free_udp_port()
    procs: dict[str, Proc] = {}
    expected: dict[str, list[tuple[float, float]]] = {}
    failures: list[str] = []
    notes: list[str] = []
    window_index = 0

    def kind_of(name: str) -> str:
        return "window" if name in plan.peers else "headless"

    def make(name: str, offset: float, quit_after: float) -> Proc:
        nonlocal window_index
        user = [f"--name={plan.display_names.get(name, name)}", f"--player-scene={plan.player_scene}"]
        if name == "host":
            user += ["--host", f"--port={host_port}", f"--level={plan.level}"]
        else:
            user += ["--join=127.0.0.1", f"--port={host_port}"]
        if name in plan.bots:
            user.append(f"--bot={plan.bots[name]}")
        user.append(f"--quit-after={quit_after:.2f}")
        log = ["--log-file", os.path.join(tmp, f"{name}.godot.log")]
        if name in plan.peers:
            shots = local_moments(plan.moments, offset)
            expected[name] = shots
            skipped = [moment_label(t) for t in plan.moments if t not in {g for g, _ in shots}]
            if skipped:
                notes.append(f"{name} {', '.join(skipped)} sn: süreç henüz başlamamıştı")
            if verbose:
                print(f"  {name}: saat kayması {offset:.2f} sn, yerel anlar {[local for _, local in shots]}")
            pos = (WINDOW_ORIGIN[0] + WINDOW_CASCADE[0] * window_index, WINDOW_ORIGIN[1] + WINDOW_CASCADE[1] * window_index)
            window_index += 1
            raw = os.path.join(raw_root, name)
            os.makedirs(raw, exist_ok=True)
            user += [f"--window-size={plan.window[0]}x{plan.window[1]}", f"--screenshot-dir={raw}"]
            if shots:
                user.append("--screenshot-at=" + ",".join(f"{local:.2f}" for _, local in shots))
            cmd = [gui_godot, "--path", ROOT, "--position", f"{pos[0]},{pos[1]}"] + log + ["--"]
        else:
            cmd = [console_godot, "--headless", "--path", ROOT] + log + ["--"]
        return Proc(name=name, cmd=cmd + user, dump_path="", quit_after=quit_after)

    try:
        host = make("host", 0.0, quit_after_for("host", duration, 0.0, plan.clients))
        procs["host"] = host
        host.start()
        t0 = host.started_at
        while not host.ready.wait(0.05):
            if host.popen is not None and host.popen.poll() is not None:
                break
            if time.monotonic() - t0 > HOST_READY_TIMEOUT:
                break
        if not host.ready.is_set():
            failures.append(f"host {HOST_READY_TIMEOUT:g} sn içinde hazır olmadı")
        else:
            t_ready = time.monotonic()
            host_startup = t_ready - t0
            host_kind = kind_of("host")
            if verbose:
                print(f"  host hazır: {host_startup:.2f} sn ({host_kind})")
            clients = peer_names(plan.clients)[1:]
            for name in sorted(clients, key=lambda n: plan.start_delay.get(n, 0.0)):
                wait = t_ready + plan.start_delay.get(name, 0.0) - time.monotonic()
                if wait > 0:
                    time.sleep(wait)
                elapsed = time.monotonic() - t0
                offset = clock_offset(elapsed, host_startup, kind_of(name), host_kind)
                proc = make(name, offset, quit_after_for(name, duration, offset, plan.clients))
                procs[name] = proc
                proc.start()
        ends = [p.started_at + p.quit_after for p in procs.values()]
        deadline = max(ends) + LINGER_SEC + 15.0
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

    for proc in procs.values():
        if proc.killed:
            failures.append(f"{proc.name} zaman aşımında öldürüldü")
        elif proc.exit_code != 0:
            failures.append(f"{proc.name} çıkış kodu {proc.exit_code}")
        for line in proc.lines:
            if ERROR_LINE.match(line):
                failures.append(f"{proc.name} log hatası: {line.strip()}")

    written, skipped, shot_failures = collect_shots(
        expected, {n: p.lines for n, p in procs.items()}, raw_root, plan.out_dir, plan.window, plan.min_stddev
    )
    failures += shot_failures
    shutil.rmtree(raw_root, ignore_errors=True)
    shutil.rmtree(tmp, ignore_errors=True)

    if not written and not skipped and not failures:
        failures.append("hiç görüntü anı yok")
    ok = not failures
    elapsed = time.monotonic() - t_begin
    extra = f", {len(skipped)} an atlandı" if skipped else ""
    print(f"{'PASS' if ok else 'FAIL'} screenshot {plan.name}: {len(written)} görüntü{extra}, {elapsed:.1f} sn")
    for path in written:
        print(f"  {os.path.relpath(path, ROOT)}")
    for text in notes + skipped:
        print(f"  atlandı: {text}")
    for text in failures:
        print(f"  FAIL {text}")
    if verbose or not ok:
        for proc in procs.values():
            print(f"----- {proc.name} log ({' '.join(proc.cmd[-6:])}) -----")
            print("\n".join(proc.lines) if proc.lines else "(boş)")
    return 0 if ok else 1


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Pencereli Godot süreçlerinden ekran görüntüsü (IS-022, S6)")
    ap.add_argument("--at", required=True, help="anlar, host başlangıcına göre sn: 3,6,9")
    ap.add_argument("--name", help="çıktı alt dizini (varsayılan: senaryo ya da seviye adı)")
    ap.add_argument("--scenario", help="net_smoke senaryosu (level, player_scene, clients, bots, start_delay, names)")
    ap.add_argument("--level", help=f"res:// seviye [{DEFAULT_LEVEL}]")
    ap.add_argument("--clients", type=int, help="istemci sayısı [2]")
    ap.add_argument("--bot", action="append", default=[], help="PEER=res://...json (tekrarlanabilir)")
    ap.add_argument("--start-delay", action="append", default=[], help="PEER=SN (tekrarlanabilir)")
    ap.add_argument("--player-scene", help=f"res:// oyuncu sahnesi [{DEFAULT_PLAYER_SCENE}]")
    ap.add_argument("--peers", default="all", help="görüntüsü alınacak peer'lar: all | host,c1,...")
    ap.add_argument("--window-size", default=f"{DEFAULT_WINDOW[0]}x{DEFAULT_WINDOW[1]}")
    ap.add_argument("--out", default=DEFAULT_OUT, help=f"çıktı kökü [{DEFAULT_OUT}]")
    ap.add_argument("--godot-gui", help="pencereli Godot exe'si")
    ap.add_argument("--min-stddev", type=float, default=DEFAULT_MIN_STDDEV, help="boş görüntü eşiği")
    ap.add_argument("--force", action="store_true", help="ekran/CI denetimini atla")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args(argv)
    if not args.force:
        reason = display_skip_reason()
        if reason:
            print(f"SKIP screenshot: atlandı — {reason}")
            return 0
    try:
        plan = build_plan(args)
    except (OSError, ValueError, json.JSONDecodeError) as e:
        print(f"FAIL screenshot: {e}")
        return 2
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    if hasattr(signal, "SIGBREAK"):
        signal.signal(signal.SIGBREAK, lambda *_: sys.exit(143))
    return run(plan, resolve_gui_godot(args.godot_gui), args.verbose)


if __name__ == "__main__":
    sys.exit(main())
