#!/usr/bin/env bash
# Endurance run (IS-013 AC3; Phase 1 exit criterion 4): host + 2 bots (real player scene) in store_a roam
# for N minutes, interacting with register/door. Scenario tests/net/soak/store_a.json; tools/net_smoke.py does the run
# (process-tree kill, ERROR/WARNING check in the log, memory sampling, dump expectations). Processes are closed by
# net_smoke in every case (timeout, Ctrl-C, SIGTERM); no Godot is left hanging.
# Usage: tools/soak.sh [--minutes N] [net_smoke options, e.g. --latency-ms 150 --keep]
# --minutes N   run length (minutes, may be fractional; default 10)
# Works on Windows (Git Bash) and Linux. Python: python3 -> python -> py -3 (>= 3.10). Exit code 0 = passed.
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
	# shellcheck disable=SC2086 # candidate is deliberately split into words
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
# exec: signals (SIGTERM/SIGINT) go straight to net_smoke, which closes the Godot process trees.
exec "${python[@]}" tools/net_smoke.py tests/net/soak/store_a.json --duration "$seconds" -v ${extra[@]+"${extra[@]}"}
