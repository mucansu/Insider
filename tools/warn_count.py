#!/usr/bin/env python3
"""GDScript uyarı sayımı ve kapısı (IS-047). Hiçbir dosyayı değiştirmez. Yalnız Python standart kütüphanesi.

Kullanım:
    python tools/warn_count.py [--gate] [--json build/warn_count.json] [--top 10] [--timeout 300] [--quiet]

Kapı (--gate): project.godot'ta düzeyi 2 (hata) olan türlerde tek uyarı bile varsa çıkış kodu 2 ve yerleri
stderr'e basılır; düzeyi 0/1 olan türler yalnız bilgi olarak sayılır. Düzey 2 ihlali `-d` olmadan da betiği
yüklenemez yapar (Parse Error), ama `--import` bunu göstermez ve hiçbir testin yüklemediği betik ancak
çalışırken düşer; kapı bütün betikleri tarar.

İki Godot koşusu (tools/warn_count.gd):
  1) Hata ayıklayıcısız tarama (`-- --gate-only`): bütün betikler proje ayarlarıyla yüklenir; motorun
     `SCRIPT ERROR: Parse Error: ... (Warning treated as error.)` satırları düzey 2 ihlalidir (kapı), başka
     `SCRIPT ERROR` satırı betik hatasıdır. Biri varsa 2. koşu atlanır (`-d` altında çözümleme hatası yerel hata
     ayıklayıcıyı durdurur ve süreç takılır; "Debugger Break" görülürse süreç hemen öldürülür).
  2) Sayım (`-d`).
Godot 4.7 `--import` ve `--check-only` GDScript uyarılarını basmaz (yalnız hataları). Bu yüzden sayım
tools/warn_count.gd ile yapılır: `godot --headless -d --path . -s res://tools/warn_count.gd` bütün .gd
dosyalarını (addons/build/docs ve gizli dizinler hariç) bellekte bütün uyarı türleri 1'e (uyar) çekilmiş
olarak yeniden çözümler ve Logger'a gelen uyarıları kod adıyla (ör. unsafe_method_access) toplar; sonuç tek
`@@WC_JSON {...}` satırıdır. Bu araç o satırı okur, türe ve dosyaya göre sayar:
  - Her tür için project.godot düzeyi (0 kapalı / 1 uyar / 2 hata) ve üretim / test / diğer sayıları.
    Düzeyi 0 olan türler "kapalı (bilgi)" olarak ayrı listelenir: açılsalar kaç uyarı verirlerdi.
  - Gruplar: üretim = autoload, core, entities, levels, ui, data ve kök dizindeki betikler; test = tests/;
    diğer = geri kalan (ör. tools/).
  - En çok uyarı veren --top dosya (yalnız düzeyi >= 1 olan türler sayılır).
JSON raporu (--json, varsayılan build/warn_count.json; build/ gitignore'da) aynı verinin tamamını ve her
uyarının satırını içerir. Metin özeti stdout'a basılır.

Çıkış kodu: 0 sayım alındı (ve --gate ile kapı geçti); 1 Godot koşusu başarısız, zaman aşımı, hata ayıklayıcı
durdu, betik hatası ya da @@WC_JSON satırı yok (--gate yokken düzey 2 ihlali de); 2 kapı (--gate): düzeyi 2
olan türde uyarı var.
Godot: GODOT ortam değişkeni, yoksa tools/get_godot.sh. Süreç zaman aşımında ağacıyla öldürülür.
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
    """res:// yolunun grubu: uretim (PRODUCTION_DIRS ya da kök dizindeki betik), test (tests/) ya da diger."""
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
    """Godot çıktısındaki son `@@WC_JSON {...}` satırını çözer (ANSI kodları temizlenir); yoksa None."""
    payload = None
    for raw in lines:
        line = ANSI.sub("", raw).strip()
        if line.startswith(JSON_MARKER):
            payload = json.loads(line[len(JSON_MARKER):])
    return payload


def aggregate(payload: dict[str, Any], top: int = 10) -> dict[str, Any]:
    """warn_count.gd çıktısından rapor: türe göre (düzey + grup sayıları), dosyaya göre, en çok uyarı verenler."""
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
    """Kısa metin özeti: etkin türler, kapalı türler (bilgi), en çok uyarı veren dosyalar, yükleme hataları."""
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


def gate_violations(report: dict[str, Any]) -> list[dict[str, Any]]:
    """Kapı: project.godot'ta düzeyi 2 (hata) olan türlerin uyarıları (bütün gruplar); boşsa kapı geçer."""
    hard = {k for k, t in report["turler"].items() if t["level"] >= 2}
    return [w for w in report["uyarilar"] if str(w["type"]) in hard]


def parse_script_errors(lines: list[str]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Hata ayıklayıcısız koşunun `SCRIPT ERROR:` satırları (+ ardındaki `at: ... (res://yol:satır)`).
    Dönüş (sert, diğer): sert = "(Warning treated as error.)" ile biten çözümleme hataları (düzeyi 2 olan uyarı);
    diğer = geri kalan betik hataları. Aynı (dosya, satır, ileti) bir kez sayılır (yüklenemeyen betik her
    başvuruda yeniden çözümlenir)."""
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
    """warn_count.gd'yi koşar: debug ise `-d` ile sayım, değilse `-- --gate-only` tarama.
    Dönüş (çıkış kodu ya da öldürüldüyse None, çıktı satırları, hata ayıklayıcı durdu mu). `-d` altında
    "Debugger Break" görülürse süreç beklenmeden öldürülür (yerel hata ayıklayıcı stdin bekleyip takılır)."""
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
    """Godot koşusu neden kullanılamaz; kullanılabilirse boş dize."""
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
    ap.add_argument("--gate", action="store_true", help="düzeyi 2 olan türde uyarı varsa çıkış kodu 2")
    args = ap.parse_args(argv)
    godot = find_godot()

    # 1) Hata ayıklayıcısız tarama: düzey 2 ihlalleri ve çözümleme hataları (-d altında bunlar süreci takar).
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

    # 2) Sayım: -d ile, bütün türler bellekte 1'e çekilmiş yeniden çözümleme.
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
    if not args.quiet:
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
