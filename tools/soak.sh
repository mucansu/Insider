#!/usr/bin/env bash
# Dayanıklılık koşusu (IS-013 AC3; Faz 1 çıkış kriteri 4): store_a'da host + 2 bot (gerçek oyuncu sahnesi)
# N dakika dolaşır, kasa/kapı etkileşir. Senaryo tests/net/soak/store_a.json; koşuyu tools/net_smoke.py yapar
# (süreç ağacı öldürme, log'da ERROR/WARNING denetimi, bellek örnekleme, döküm beklentileri). Süreçler her
# durumda (zaman aşımı, Ctrl-C, SIGTERM) net_smoke tarafından kapatılır; asılı Godot kalmaz.
# Kullanım: tools/soak.sh [--minutes N] [net_smoke seçenekleri, ör. --latency-ms 150 --keep]
#   --minutes N   koşu süresi (dakika, ondalık olabilir; varsayılan 10)
# Windows (Git Bash) ve Linux'ta çalışır. Python: python3 → python → py -3 (>= 3.10). Çıkış kodu 0 = geçti.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
export PYTHONUTF8=1

minutes=10
extra=()
while (($#)); do
	case "$1" in
	--minutes)
		[[ $# -ge 2 ]] || { echo "--minutes bir değer ister" >&2; exit 2; }
		minutes="$2"
		shift 2
		;;
	--minutes=*)
		minutes="${1#*=}"
		shift
		;;
	-h | --help)
		sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*)
		extra+=("$1")
		shift
		;;
	esac
done
if ! [[ "$minutes" =~ ^[0-9]+([.][0-9]+)?$ ]] || [[ "$minutes" =~ ^0+([.]0+)?$ ]]; then
	echo "--minutes pozitif bir sayı olmalı: $minutes" >&2
	exit 2
fi

python=()
for cand in "python3" "python" "py -3"; do
	# shellcheck disable=SC2086 # aday bilerek sözcüklere bölünür
	if command -v "${cand%% *}" >/dev/null 2>&1 \
		&& $cand -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1; then
		read -r -a python <<<"$cand"
		break
	fi
done
if ((${#python[@]} == 0)); then
	echo "Python >= 3.10 bulunamadı (python3 | python | py -3)." >&2
	exit 1
fi

seconds="$("${python[@]}" -c "import sys; print(round(float(sys.argv[1]) * 60, 1))" "$minutes")"
echo "== soak: store_a, ${minutes} dk (${seconds} sn), $(date '+%Y-%m-%d %H:%M:%S')"
# exec: sinyaller (SIGTERM/SIGINT) doğrudan net_smoke'a gider; o da Godot süreç ağaçlarını kapatır.
exec "${python[@]}" tools/net_smoke.py tests/net/soak/store_a.json --duration "$seconds" -v ${extra[@]+"${extra[@]}"}
