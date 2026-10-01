#!/usr/bin/env bash
# Yerel CI (mimari.md §5): Godot getir → içe aktar → birim testler → ağ duman senaryoları (0 ve 150 ms).
# İlk hatada sıfır olmayan kodla çıkar. Push öncesi yeşil olmalı.
# Kullanım: tools/ci_local.sh [godot|import|unit|net ...]   (adım verilmezse hepsi, bu sırayla)
# .github/workflows/ci.yml aynı adımları aynı sırayla bu betikle koşar; biri değişirse diğeri de.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

GODOT="$(bash tools/get_godot.sh)"
export GODOT

step_godot() {
	"$GODOT" --version
}

# İçe aktarma iki geçiş: ilki önbelleği ve üretilen dosyaları (.godot/, *.translation) kurar;
# taze klonda çeviriler henüz üretilmediği için yükleme hatası basabilir. İkinci geçiş temiz olmalı:
# hata ya da uyarı satırı varsa adım başarısız.
step_import() {
	local log
	log="$(mktemp)"
	"$GODOT" --headless --path . --import >"$log" 2>&1 || { cat "$log"; rm -f "$log"; return 1; }
	"$GODOT" --headless --path . --import >"$log" 2>&1 || { cat "$log"; rm -f "$log"; return 1; }
	local problems
	problems="$(sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E '^[[:space:]]*(SCRIPT |USER )?(ERROR|WARNING):' || true)"
	rm -f "$log"
	if [[ -n "$problems" ]]; then
		echo "İçe aktarma hata/uyarı verdi:"
		echo "$problems"
		return 1
	fi
	echo "İçe aktarma temiz."
}

step_unit() {
	"$GODOT" --headless --path . -s res://tests/run_tests.gd
}

step_net() {
	shopt -s nullglob
	local scenarios=(tests/net/*.json)
	shopt -u nullglob
	if ((${#scenarios[@]} == 0)); then
		echo "tests/net/*.json yok; ağ senaryosu atlandı."
		return 0
	fi
	if [[ ! -f tools/net_smoke.py ]]; then
		echo "UYARI: tools/net_smoke.py yok; ${#scenarios[@]} ağ senaryosu atlandı." >&2
		return 0
	fi
	# Not: adımlar `if` içinde çağrıldığından set -e burada işlemez; her hata açıkça döndürülür.
	local s
	for s in "${scenarios[@]}"; do
		echo "-- $s (0 ms)"
		python3 tools/net_smoke.py "$s" || return 1
		echo "-- $s (150 ms)"
		python3 tools/net_smoke.py "$s" --latency-ms 150 || return 1
	done
}

steps=("$@")
((${#steps[@]})) || steps=(godot import unit net)
started=$SECONDS
for step in "${steps[@]}"; do
	case "$step" in
	godot | import | unit | net) ;;
	*)
		echo "Bilinmeyen adım: $step (godot|import|unit|net)" >&2
		exit 2
		;;
	esac
	t0=$SECONDS
	echo "== $step"
	if ! "step_$step"; then
		echo "== $step BAŞARISIZ ($((SECONDS - t0)) sn)" >&2
		exit 1
	fi
	echo "== $step tamam ($((SECONDS - t0)) sn)"
done
echo "== CI yeşil: ${steps[*]} ($((SECONDS - started)) sn)"
