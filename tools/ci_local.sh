#!/usr/bin/env bash
# Yerel CI (mimari.md §5): Godot getir → içe aktar → birim testler → araç testleri (Python) + uyarı kapısı →
# ağ duman senaryoları (0 ve 150 ms). İlk hatada sıfır olmayan kodla çıkar. Push öncesi yeşil olmalı.
# Kullanım: tools/ci_local.sh [godot|import|unit|tools|net|export ...]
#   Adım verilmezse godot import unit tools net (bu sırayla; dev ve main push'unda CI de bunları koşar).
#   export yalnız açıkça istenir: tools/export.sh (Windows + Linux build'i build/'e, bu makinenin build'iyle
#   duman koşusu); CI bunu yalnız main push'unda `godot import export` olarak koşar ve build'leri yükler.
# Python: python3 → python → py -3 sırasıyla ilk >= 3.10 olan (Windows'ta Git Bash ile de çalışır).
# .github/workflows/ci.yml aynı adımları aynı sırayla bu betikle koşar; biri değişirse diğeri de.
# Çıktı (IS-090): varsayılan kısa kip — başarıda adım başına özet satırı, başarısızlıkta ayrıntı.
# CI_VERBOSE=1 eski ayrıntılı çıktıyı açar (test başına [PASS], unittest satırları, uyarı tabloları, net -v;
# uzak CI bu kiple koşar). Kapılar ve çıkış kodları iki kipte aynıdır.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# Python çıktısı boruya/dosyaya giderken de UTF-8 olsun (Windows'ta varsayılan cp1254 Türkçeyi bozar;
# Linux'ta zararsız).
export PYTHONUTF8=1

VERBOSE=0
if [[ "${CI_VERBOSE:-}" == "1" ]]; then
	VERBOSE=1
	export TESTS_VERBOSE=1
fi

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
	if ((VERBOSE)); then echo "İçe aktarma temiz."; fi
}

# Birim testler. Koşucu çıkış kodunu verir (test başına yetim düğüm farkı da kapıdır: `[ORPHAN]` satırı,
# IS-046); motorun kapanışta bastığı sızıntı satırları (ObjectDB örneği,
# kaynak, RID: "... leaked at exit" / "... still in use at exit") koşucudan sonra geldiğinden burada
# yakalanır: biri bile varsa adım başarısız ve kaynaklar --verbose ikinci koşuyla listelenir (IS-029).
# (import adımı bu satırları zaten genel ERROR/WARNING kuralıyla yakalar.)
LEAK_PATTERN='(leaked|still in use) at exit'
step_unit() {
	local log code
	log="$(mktemp)"
	set +e
	if ((VERBOSE)); then
		"$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1 | tee "$log"
		code=${PIPESTATUS[0]}
	else
		# Kısa kip: koşucu zaten yalnız FAIL/ORPHAN + özet basar; motorun beklenen push_warning blokları
		# burada süzülür. Başarısızlıkta koşucu satırları + motor ERROR satırları; koşucu özet basmadan
		# düştüyse (çökme, zaman aşımı) log'un son 40 satırı.
		"$GODOT" --headless --path . -s res://tests/run_tests.gd >"$log" 2>&1
		code=$?
		local runner_re='^(\[FAIL\]|\[ORPHAN\]|       - |[0-9]+ test: |Yetim düğüm farkı|Koşulacak test yok)'
		if ((code == 0)); then
			sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E "$runner_re" || true
		elif sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -qE '^[0-9]+ test: '; then
			sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E "$runner_re|^(SCRIPT )?ERROR:" || true
			echo "(tam çıktı: CI_VERBOSE=1 ya da TESTS_VERBOSE=1)"
		else
			tail -n 40 "$log"
		fi
	fi
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

# Araç testleri: gecikme proxy'si, net_smoke süreç ağacı öldürme, ekran görüntüsü ve uyarı sayımı yardımcıları,
# ajan hook koruması .claude/hooks/agent_guard.py (IS-053) (Godot gerekmez). Ardından GDScript uyarı sayımı +
# kapısı (IS-047; Godot ister, import'tan sonra): project.godot'ta düzeyi 2 olan türde uyarı varsa ya da sayım
# alınamazsa adım KIRMIZI; düzeyi 0/1 olan türlerin sayımı yalnız bilgi (JSON: build/warn_count.json).
# Bir Python araç testini koşar. Kısa kipte çıktı yakalanır: geçerse tek satır ("dosya: Ran N tests in … OK"),
# kalırsa log'un tamamı (unittest başarısız testlerin izini ve nedenini basar).
py_test() {
	local file="$1" log
	if ((VERBOSE)); then
		"${PYTHON[@]}" "$file" || return 1
		return 0
	fi
	log="$(mktemp)"
	if "${PYTHON[@]}" "$file" >"$log" 2>&1; then
		echo "$(basename "$file"): $(grep -E '^Ran [0-9]+ tests? in' "$log" | tail -n 1) $(grep -E '^OK' "$log" | tail -n 1)"
		rm -f "$log"
		return 0
	fi
	cat "$log"
	rm -f "$log"
	return 1
}

# test_run_tests.py koşucunun kısa/ayrıntılı çıktı kipini doğrular (IS-090; Godot ister, GODOT dışa aktarıldı).
step_tools() {
	find_python || return 1
	if ((VERBOSE)); then "${PYTHON[@]}" --version; fi
	py_test tools/test_latency_proxy.py || return 1
	py_test tools/test_net_smoke.py || return 1
	py_test tools/test_screenshot.py || return 1
	py_test tools/test_perf_run.py || return 1
	py_test tools/test_warn_count.py || return 1
	py_test tools/test_agent_guard.py || return 1
	py_test tools/test_run_tests.py || return 1
	if ((VERBOSE)); then
		echo "-- GDScript uyarı sayımı (düzey 2 = kapı, diğerleri bilgi)"
		"${PYTHON[@]}" tools/warn_count.py --gate || return 1
	else
		"${PYTHON[@]}" tools/warn_count.py --gate --brief || return 1
	fi
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
	# Kısa kipte senaryo başına net_smoke'un tek PASS satırı (adı ve gecikmeyi içerir); FAIL'de başarısız
	# iddialar + log hata satırları. Ayrıntılı kipte "--" başlıkları ve -v (bütün iddialar).
	local s
	local net_v=()
	if ((VERBOSE)); then net_v=(-v); fi
	for s in "${scenarios[@]}"; do
		if ((VERBOSE)); then echo "-- $s (0 ms)"; fi
		"${PYTHON[@]}" tools/net_smoke.py "$s" "${net_v[@]}" || return 1
		if ((VERBOSE)); then echo "-- $s (150 ms)"; fi
		"${PYTHON[@]}" tools/net_smoke.py "$s" --latency-ms 150 "${net_v[@]}" || return 1
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
	if ((VERBOSE)); then echo "== $step"; fi
	if ! "step_$step"; then
		echo "== $step BAŞARISIZ ($((SECONDS - t0)) sn)" >&2
		exit 1
	fi
	echo "== $step tamam ($((SECONDS - t0)) sn)"
done
echo "== CI yeşil: ${steps[*]} ($((SECONDS - started)) sn)"
