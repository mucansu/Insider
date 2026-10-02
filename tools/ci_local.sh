#!/usr/bin/env bash
# Yerel CI (mimari.md §5): Godot getir → içe aktar → birim testler → araç testleri (Python) →
# ağ duman senaryoları (0 ve 150 ms). İlk hatada sıfır olmayan kodla çıkar. Push öncesi yeşil olmalı.
# Kullanım: tools/ci_local.sh [godot|import|unit|tools|net|export ...]
#   Adım verilmezse godot import unit tools net (bu sırayla; dev ve main push'unda CI de bunları koşar).
#   export yalnız açıkça istenir: tools/export.sh (Windows + Linux build'i build/'e, bu makinenin build'iyle
#   duman koşusu); CI bunu yalnız main push'unda `godot import export` olarak koşar ve build'leri yükler.
# Python: python3 → python → py -3 sırasıyla ilk >= 3.10 olan (Windows'ta Git Bash ile de çalışır).
# .github/workflows/ci.yml aynı adımları aynı sırayla bu betikle koşar; biri değişirse diğeri de.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# Python çıktısı boruya/dosyaya giderken de UTF-8 olsun (Windows'ta varsayılan cp1254 Türkçeyi bozar;
# Linux'ta zararsız).
export PYTHONUTF8=1

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

# Birim testler. Koşucu çıkış kodunu verir; motorun kapanışta bastığı sızıntı satırları (ObjectDB örneği,
# kaynak, RID: "... leaked at exit" / "... still in use at exit") koşucudan sonra geldiğinden burada
# yakalanır: biri bile varsa adım başarısız ve kaynaklar --verbose ikinci koşuyla listelenir (IS-029).
# (import adımı bu satırları zaten genel ERROR/WARNING kuralıyla yakalar.)
LEAK_PATTERN='(leaked|still in use) at exit'
step_unit() {
	local log code
	log="$(mktemp)"
	set +e
	"$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1 | tee "$log"
	code=${PIPESTATUS[0]}
	set -e
	local leaks
	leaks="$(sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E "$LEAK_PATTERN" || true)"
	rm -f "$log"
	((code == 0)) || return "$code"
	if [[ -n "$leaks" ]]; then
		echo "Birim koşusu çıkışta sızıntı bıraktı:"
		echo "$leaks"
		echo "Kaynaklar (--verbose ikinci koşu; test başına izole etmek için -- --filter=METİN):"
		"$GODOT" --headless --verbose --path . -s res://tests/run_tests.gd 2>&1 \
			| sed 's/\x1b\[[0-9;]*m//g' | grep -E '^(Leaked instance|Resource still in use|Hint: Leaked)' || true
		return 1
	fi
}

# Python yorumlayıcısı (dizi: `py -3` iki sözcük). İlk kullanımda bulunur; yoksa adım başarısız.
PYTHON=()
find_python() {
	((${#PYTHON[@]})) && return 0
	local cand
	for cand in "python3" "python" "py -3"; do
		# shellcheck disable=SC2086 # aday bilerek sözcüklere bölünür
		if command -v "${cand%% *}" >/dev/null 2>&1 \
			&& $cand -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1; then
			read -r -a PYTHON <<<"$cand"
			return 0
		fi
	done
	echo "Python >= 3.10 bulunamadı (python3 | python | py -3)." >&2
	return 1
}

# Araç testleri: gecikme proxy'si ve net_smoke süreç ağacı öldürme (Godot gerekmez).
step_tools() {
	find_python || return 1
	"${PYTHON[@]}" --version
	"${PYTHON[@]}" tools/test_latency_proxy.py || return 1
	"${PYTHON[@]}" tools/test_net_smoke.py || return 1
	"${PYTHON[@]}" tools/test_screenshot.py || return 1
}

# Windows + Linux build'i (IS-005); şablonlar ilk koşuda indirilir (~1,3 GB), sonra atlanır.
step_export() {
	bash tools/export.sh
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
	find_python || return 1
	# Not: adımlar `if` içinde çağrıldığından set -e burada işlemez; her hata açıkça döndürülür.
	local s
	for s in "${scenarios[@]}"; do
		echo "-- $s (0 ms)"
		"${PYTHON[@]}" tools/net_smoke.py "$s" || return 1
		echo "-- $s (150 ms)"
		"${PYTHON[@]}" tools/net_smoke.py "$s" --latency-ms 150 || return 1
	done
}

steps=("$@")
((${#steps[@]})) || steps=(godot import unit tools net)
started=$SECONDS
for step in "${steps[@]}"; do
	case "$step" in
	godot | import | unit | tools | net | export) ;;
	*)
		echo "Bilinmeyen adım: $step (godot|import|unit|tools|net|export)" >&2
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
