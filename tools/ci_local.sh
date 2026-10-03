#!/usr/bin/env bash
# Local CI (mimari.md §5): fetch Godot -> import -> unit tests -> tool tests (Python) + warning gate -> network smoke
# scenarios (0 and 150 ms). Exits non-zero on the first failure. Must be green before push.
# Usage: tools/ci_local.sh [godot|import|unit|tools|net|export ...]
# With no steps: godot import unit tools net (in this order; CI runs the same on dev and main push).
# export only on request: tools/export.sh (Windows + Linux builds into build/, smoke run with this machine's build);
# CI runs it only on main push as `godot import export` and uploads the builds.
# Python: first of python3 -> python -> py -3 that is >= 3.10 (also works on Windows with Git Bash).
# .github/workflows/ci.yml runs the same steps in the same order via this script; change one, change the other.
# Output (IS-090): short mode by default - one summary line per step on success, details on failure.
# CI_VERBOSE=1 enables the old detailed output (per-test [PASS], unittest lines, warning tables, net -v;
# remote CI runs in this mode). Gates and exit codes are the same in both modes.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# Make Python output UTF-8 even when piped/redirected (on Windows the default cp1254 garbles Turkish;
# harmless on Linux).
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

# Import runs in two passes: the first builds the cache and generated files (.godot/, *.translation);
# on a fresh clone translations are not generated yet, so it may print a load error.
# The second pass must be clean: any error or warning line fails the step.
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

# Unit tests. The runner provides the exit code (the per-test orphan node delta is also a gate: `[ORPHAN]` line,
# IS-046); leak lines the engine prints at shutdown (ObjectDB instances,
# resource, RID: "... leaked at exit" / "... still in use at exit") come after the runner, so they are
# caught here: any one fails the step and the resources are listed by a second --verbose run (IS-029).
# (The import step already catches these lines with the generic ERROR/WARNING rule.)
LEAK_PATTERN='(leaked|still in use) at exit'
step_unit() {
	local log code
	log="$(mktemp)"
	set +e
	if ((VERBOSE)); then
		"$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1 | tee "$log"
		code=${PIPESTATUS[0]}
	else
		# Short mode: the runner already prints only FAIL/ORPHAN + summary; the engine's expected push_warning blocks
		# are filtered here. On failure the runner lines + engine ERROR lines; if the runner fell over without a summary
		# (crash, timeout) the last 40 lines of the log.
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

# Python interpreter (array: `py -3` is two words). Found on first use; if none, the step fails.
PYTHON=()
find_python() {
	((${#PYTHON[@]})) && return 0
	local cand
	for cand in "python3" "python" "py -3"; do
		# shellcheck disable=SC2086 # candidate is deliberately split into words
		if command -v "${cand%% *}" >/dev/null 2>&1 \
			&& $cand -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1; then
			read -r -a PYTHON <<<"$cand"
			return 0
		fi
	done
	echo "Python >= 3.10 bulunamadı (python3 | python | py -3)." >&2
	return 1
}

# Tool tests: latency proxy, net_smoke process-tree kill, screenshot and warning-count helpers,
# the agent hook guard .claude/hooks/agent_guard.py (IS-053) (no Godot needed). Then the GDScript warning count +
# gate (IS-047; needs Godot, after import): the step is RED if a kind at level 2 in project.godot has warnings or the count
# cannot be taken; counts of level 0/1 kinds are informational only (JSON: build/warn_count.json).
# Runs one Python tool test. In short mode output is captured: if it passes a single line ("file: Ran N tests in ... OK"),
# if it fails the whole log (unittest prints the failing tests' traces and reasons).
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

# test_run_tests.py checks the runner's short/verbose output modes (IS-090; needs Godot, GODOT is exported).
step_tools() {
	find_python || return 1
	if ((VERBOSE)); then "${PYTHON[@]}" --version; fi
	py_test tools/test_latency_proxy.py || return 1
	py_test tools/test_net_smoke.py || return 1
	py_test tools/test_screenshot.py || return 1
	py_test tools/test_perf_run.py || return 1
	py_test tools/test_heist_stats.py || return 1
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

# Windows + Linux builds (IS-005); templates are downloaded on first run (~1.3 GB), then skipped.
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
	# Note: steps are called inside `if`, so set -e does not act here; every error is returned explicitly.
	# In short mode one net_smoke PASS line per scenario (includes name and latency); on FAIL the failed
	# assertions + log error lines. In verbose mode the "--" headers and -v (all assertions).
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
