#!/usr/bin/env bash
# Windows + Linux builds (IS-005): prepares export templates, produces both platform outputs into build/ with the
# export_presets.cfg presets, and opens and closes the build for this machine's platform headless.
# Usage: tools/export.sh [--debug] [templates|windows|linux|smoke ...]   (with no steps all, in this order)
# --debug    (or EXPORT_DEBUG=1 in the environment; tools/ci_local.sh export and CI pass it via the environment) builds
# with the debug template (Godot --export-debug): GDScript runtime errors land in the log with a trace,
# a crash handler block is written on crash, OS.is_debug_build() is true. `test-*` tagged friend test
# builds come out this way (IS-076); default and main-push artifacts use the release template.
# templates  Installs the Godot version's (tools/get_godot.sh) export templates into the user dir:
# Windows: %APPDATA%/Godot/export_templates/<version>.stable
# Linux:   ${XDG_DATA_HOME:-~/.local/share}/godot/export_templates/<version>.stable
# Skipped if installed. Otherwise downloads the official .tpz (~1.3 GB) into .tools/, verifies SHA-512 against the official
# SHA512-SUMS.txt value, extracts only the Windows/Linux x86_64 templates, deletes the .tpz.
# windows    build/windows/Insiders.exe (+ Insiders.console.exe; pck embedded) + perf_dump.bat (IS-067)
# linux      build/linux/Insiders.x86_64 (pck embedded) + build/Insiders-linux-x86_64.tar.gz (execute permission kept)
# smoke      opens this machine's build (Windows on Windows, Linux on Linux) headless as two processes: host +
# a client joining 127.0.0.1, both close via --quit-after; each must give code 0, a READY line,
# no error line, a dump with exit_reason=quit_after (2 peers in the client dump).
# Exits non-zero on the first failure. Works with Git Bash on Windows. tools/ci_local.sh export calls this.
set -euo pipefail

# The template archive's digest is valid only for this version; update it here when get_godot.sh is upgraded.
TEMPLATES_VERSION="4.7.2"
TEMPLATES_TPZ_SHA512="ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079"
# export_presets.cfg preset names and outputs (paths relative to the project root).
WINDOWS_PRESET="Windows Desktop"
WINDOWS_OUT="build/windows/Insiders.exe"
LINUX_PRESET="Linux"
LINUX_OUT="build/linux/Insiders.x86_64"
LINUX_TARBALL="build/Insiders-linux-x86_64.tar.gz"
# Installed templates (from templates/ inside the tpz).
TEMPLATE_FILES=(
	version.txt
	windows_release_x86_64.exe windows_release_x86_64_console.exe
	windows_debug_x86_64.exe windows_debug_x86_64_console.exe
	linux_release.x86_64 linux_debug.x86_64
)
SMOKE_HOST_QUIT_AFTER=6
SMOKE_CLIENT_QUIT_AFTER=2
SMOKE_READY_WAIT_SEC=20
SMOKE_TIMEOUT_SEC=60

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

version="$(sed -n 's/^GODOT_VERSION="\(.*\)"$/\1/p' tools/get_godot.sh)"
if [[ "$version" != "$TEMPLATES_VERSION" ]]; then
	echo "export: get_godot.sh sürümü $version, şablon özeti $TEMPLATES_VERSION için; export.sh'ı güncelleyin" >&2
	exit 1
fi
release="${version}-stable"

case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*) windows=1 ;;
*) windows=0 ;;
esac

templates_dir() {
	if ((windows)); then
		echo "$(cygpath -u "$APPDATA")/Godot/export_templates/${version}.stable"
	else
		echo "${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${version}.stable"
	fi
}

templates_installed() {
	local dir="$1" f
	[[ -f "$dir/version.txt" && "$(tr -d '\r\n' <"$dir/version.txt")" == "${version}.stable" ]] || return 1
	for f in "${TEMPLATE_FILES[@]}"; do
		[[ -s "$dir/$f" ]] || return 1
	done
}

step_templates() {
	local dir
	dir="$(templates_dir)"
	if templates_installed "$dir"; then
		echo "Şablonlar kurulu: $dir"
		return 0
	fi
	local name="Godot_v${release}_export_templates.tpz"
	local tpz="$root/.tools/$name"
	mkdir -p "$root/.tools" || return 1
	if [[ ! -f "$tpz" ]] || ! echo "${TEMPLATES_TPZ_SHA512}  $tpz" | sha512sum -c --quiet - >/dev/null 2>&1; then
		local url="https://github.com/godotengine/godot/releases/download/${release}/${name}"
		echo "İndiriliyor (~1,3 GB): $url"
		# An interrupted download resumes where it left off (.part); deleted if the digest does not match.
		curl -fSL --retry 3 --retry-delay 5 -C - -sS -o "$tpz.part" "$url" || return 1
		if ! echo "${TEMPLATES_TPZ_SHA512}  $tpz.part" | sha512sum -c --quiet -; then
			rm -f "$tpz.part"
			echo "SHA-512 uyuşmuyor: $name" >&2
			return 1
		fi
		mv -f "$tpz.part" "$tpz" || return 1
	fi
	local tmp
	tmp="$(mktemp -d "$root/.tools/templates.XXXXXX")" || return 1
	local members=() f
	for f in "${TEMPLATE_FILES[@]}"; do members+=("templates/$f"); done
	if ! unzip -q -o "$tpz" "${members[@]}" -d "$tmp"; then
		rm -rf "$tmp"
		return 1
	fi
	mkdir -p "$dir" || return 1
	for f in "${TEMPLATE_FILES[@]}"; do
		mv -f "$tmp/templates/$f" "$dir/$f" || return 1
	done
	chmod +x "$dir"/linux_* || true
	rm -rf "$tmp" "$tpz"
	templates_installed "$dir" || { echo "Şablon kurulumu eksik: $dir" >&2; return 1; }
	echo "Şablonlar kuruldu: $dir"
}

# Prints and returns failure if there is an error line (ERROR:/SCRIPT ERROR:/USER ERROR:).
check_log() {
	local log="$1" problems
	problems="$(sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E '^[[:space:]]*(SCRIPT |USER )?ERROR:' || true)"
	if [[ -n "$problems" ]]; then
		echo "$problems"
		return 1
	fi
}

# Exports the preset; fails if the output is missing/empty or the log has an error.
export_preset() {
	local preset="$1" out="$2" godot log
	# Uses GODOT if given, otherwise the pinned version under .tools/.
	godot="$(bash tools/get_godot.sh)" || return 1
	templates_installed "$(templates_dir)" || { echo "Şablonlar kurulu değil: tools/export.sh templates" >&2; return 1; }
	rm -rf "$(dirname "$out")"
	mkdir -p "$(dirname "$out")" || return 1
	log="$(mktemp)"
	# On a fresh clone without a cache import first (export does it too; so translations are ready).
	[[ -d .godot ]] || "$godot" --headless --path . --import >"$log" 2>&1 || true
	echo "Export ($export_mode): $preset → $out"
	if ! "$godot" --headless --path . "--export-$export_mode" "$preset" "$out" >"$log" 2>&1; then
		cat "$log"
		rm -f "$log"
		echo "Export başarısız: $preset" >&2
		return 1
	fi
	if ! check_log "$log"; then
		rm -f "$log"
		echo "Export günlüğünde hata: $preset" >&2
		return 1
	fi
	rm -f "$log"
	[[ -s "$out" ]] || { echo "Çıktı yok: $out" >&2; return 1; }
	ls -l "$(dirname "$out")"
}

step_windows() {
	export_preset "$WINDOWS_PRESET" "$WINDOWS_OUT" || return 1
	[[ "$(head -c 2 "$WINDOWS_OUT")" == "MZ" ]] || { echo "PE değil: $WINDOWS_OUT" >&2; return 1; }
	[[ -s "${WINDOWS_OUT%.exe}.console.exe" ]] || { echo "Konsol sarmalayıcısı yok" >&2; return 1; }
	# IS-067: friend-machine performance dump script next to the build (CRLF for cmd).
	sed 's/\r*$/\r/' tools/perf_dump.bat > "$(dirname "$WINDOWS_OUT")/perf_dump.bat" || return 1
}

step_linux() {
	export_preset "$LINUX_PRESET" "$LINUX_OUT" || return 1
	[[ "$(head -c 4 "$LINUX_OUT" | tail -c 3)" == "ELF" ]] || { echo "ELF değil: $LINUX_OUT" >&2; return 1; }
	chmod +x "$LINUX_OUT" || return 1
	# On Windows (NTFS) chmod has no effect; the execute permission is written into the archive with --mode (GNU tar, same on Linux).
	tar --mode='a+x' -czf "$LINUX_TARBALL" -C "$(dirname "$LINUX_OUT")" . || return 1
	tar -tvzf "$LINUX_TARBALL" | grep -qE '^-rwx.* \./Insiders\.x86_64$' \
		|| { echo "Arşivde çalıştırma izni yok: $LINUX_TARBALL" >&2; tar -tvzf "$LINUX_TARBALL" >&2; return 1; }
	ls -l "$LINUX_TARBALL"
}

# Checks a run's result: code 0, a READY line, no error line, dump exit_reason=quit_after and
# the expected is_host / peer count (empty = not checked). Prints the log if there is a problem.
check_run() {
	local role="$1" code="$2" log="$3" dump="$4" is_host="$5" peers="$6" ok=1
	if ((code != 0)); then echo "$role: çıkış kodu $code (beklenen 0)" >&2; ok=0; fi
	grep -q "INSIDERS_READY $role" "$log" || { echo "$role: READY satırı yok" >&2; ok=0; }
	check_log "$log" >&2 || { echo "$role: çıktıda hata satırı var" >&2; ok=0; }
	if [[ ! -s "$dump" ]]; then
		echo "$role: döküm yazılmadı" >&2
		ok=0
	else
		local flat ids=()
		flat="$(tr -d ' \r\n' <"$dump")"
		[[ "$flat" == *'"exit_reason":"quit_after"'* ]] || { echo "$role: exit_reason quit_after değil" >&2; ok=0; }
		[[ "$flat" == *"\"is_host\":$is_host"* ]] || { echo "$role: is_host $is_host değil" >&2; ok=0; }
		if [[ -n "$peers" ]]; then
			[[ "$flat" =~ \"peers\":\[([0-9,]*)\] ]] && IFS=, read -r -a ids <<<"${BASH_REMATCH[1]}"
			((${#ids[@]} == peers)) || { echo "$role: peer sayısı ${#ids[@]}, beklenen $peers" >&2; ok=0; }
		fi
	fi
	((ok)) || { echo "--- $role çıktısı:"; cat "$log"; }
	((ok))
}

# This machine's build as two processes: host (store_a) + a client joining 127.0.0.1; both close themselves via --quit-after;
# the client dump must have two peers (the host dump is written after the client exits).
step_smoke() {
	local bin dir hdump cdump port hpid hcode=0 ccode=0 i
	if ((windows)); then bin="./${WINDOWS_OUT%.exe}.console.exe"; else bin="./$LINUX_OUT"; fi
	[[ -s "$bin" ]] || { echo "Build yok: $bin (önce export adımı)" >&2; return 1; }
	dir="$(mktemp -d)" || return 1
	hdump="$dir/host.json"
	cdump="$dir/client.json"
	if ((windows)); then
		hdump="$(cygpath -m "$hdump")"
		cdump="$(cygpath -m "$cdump")"
	fi
	port=$((20000 + RANDOM % 20000))
	echo "Host: $bin --headless -- --host --port=$port --quit-after=$SMOKE_HOST_QUIT_AFTER --dump=..."
	timeout "$SMOKE_TIMEOUT_SEC" "$bin" --headless -- --host "--port=$port" \
		"--quit-after=$SMOKE_HOST_QUIT_AFTER" "--dump=$hdump" >"$dir/host.log" 2>&1 &
	hpid=$!
	for ((i = 0; i < SMOKE_READY_WAIT_SEC * 10; i++)); do
		grep -q "INSIDERS_READY host" "$dir/host.log" 2>/dev/null && break
		kill -0 "$hpid" 2>/dev/null || break
		sleep 0.1
	done
	echo "İstemci: $bin --headless -- --join=127.0.0.1 --port=$port --quit-after=$SMOKE_CLIENT_QUIT_AFTER --dump=..."
	timeout "$SMOKE_TIMEOUT_SEC" "$bin" --headless -- --join=127.0.0.1 "--port=$port" \
		"--quit-after=$SMOKE_CLIENT_QUIT_AFTER" "--dump=$cdump" >"$dir/client.log" 2>&1 || ccode=$?
	wait "$hpid" || hcode=$?
	local ok=1
	check_run host "$hcode" "$dir/host.log" "$hdump" true "" || ok=0
	check_run client "$ccode" "$dir/client.log" "$cdump" false 2 || ok=0
	rm -rf "$dir"
	((ok)) || return 1
	echo "Build açıldı, istemci bağlandı, ikisi de temiz kapandı (kod 0, READY, döküm exit_reason=quit_after)."
}

export_mode=release
[[ "${EXPORT_DEBUG:-}" == 1 ]] && export_mode=debug
steps=()
for arg in "$@"; do
	if [[ "$arg" == --debug ]]; then export_mode=debug; else steps+=("$arg"); fi
done
((${#steps[@]})) || steps=(templates windows linux smoke)
for step in "${steps[@]}"; do
	case "$step" in
	templates | windows | linux | smoke) ;;
	*)
		echo "Bilinmeyen adım: $step ([--debug] templates|windows|linux|smoke)" >&2
		exit 2
		;;
	esac
	t0=$SECONDS
	echo "-- export: $step ($export_mode)"
	if ! "step_$step"; then
		echo "-- export: $step BAŞARISIZ ($((SECONDS - t0)) sn)" >&2
		exit 1
	fi
	echo "-- export: $step tamam ($((SECONDS - t0)) sn)"
done
