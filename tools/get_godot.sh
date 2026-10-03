#!/usr/bin/env bash
# Prepares the Godot binary and prints its path to stdout (mimari.md §1). The version is kept only here.
# Uses the GODOT environment variable if given (warns if the version differs).
# Otherwise downloads Godot 4.7.2-stable into <project>/.tools/ (skipped if present with the right version) and verifies
# the SHA-512 against the official SHA512-SUMS.txt value:
# Linux x86_64          -> .tools/godot
# Windows (Git Bash/MSYS2/Cygwin) -> .tools/Godot_v<version>-stable_win64_console.exe (GUI exe alongside;
# the console exe launches it as a child process). The path is printed as C:/...
# Usage: "$(tools/get_godot.sh)" --version
set -euo pipefail

GODOT_VERSION="4.7.2"
GODOT_ZIP_SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
GODOT_WIN64_ZIP_SHA512="83decd58fdf67b9d657958a1ae6bf1929c20785315a81effe245874cdc57acb709bf868e00778a96984338c1b29dafdb453c6847747694621c6ecf5da2259993"

release="${GODOT_VERSION}-stable"
want="${GODOT_VERSION}.stable"

if [[ -n "${GODOT:-}" ]]; then
	if ! have="$("$GODOT" --version 2>/dev/null | tr -d '\r' | tail -n 1)"; then
		echo "get_godot: GODOT=$GODOT çalıştırılamıyor" >&2
		exit 1
	fi
	[[ "$have" == "$want"* ]] || echo "get_godot: UYARI: GODOT=$GODOT sürümü $have, beklenen $want" >&2
	echo "$GODOT"
	exit 0
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*)
	windows=1
	name="Godot_v${release}_win64.exe"
	sha512="$GODOT_WIN64_ZIP_SHA512"
	bin="$root/.tools/Godot_v${release}_win64_console.exe"
	;;
*)
	windows=0
	name="Godot_v${release}_linux.x86_64"
	sha512="$GODOT_ZIP_SHA512"
	bin="$root/.tools/godot"
	;;
esac

# On Windows the path is printed as C:/... so both bash and native Windows processes (Python) can use it.
print_bin() {
	if ((windows)); then cygpath -m "$bin"; else echo "$bin"; fi
}

if [[ -x "$bin" ]] && "$bin" --version 2>/dev/null | tr -d '\r' | tail -n 1 | grep -q "^${want}"; then
	print_bin
	exit 0
fi

if ((!windows)) && [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
	echo "get_godot: yalnız Linux x86_64 ve Windows x86_64 indirilir; Godot $release kurup GODOT=/yol/godot verin" >&2
	exit 1
fi

url="https://github.com/godotengine/godot/releases/download/${release}/${name}.zip"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "get_godot: indiriliyor $url" >&2
curl -fsSL --retry 3 -o "$tmp/godot.zip" "$url"
echo "${sha512}  $tmp/godot.zip" | sha512sum -c --quiet - >&2 \
	|| { echo "get_godot: SHA-512 uyuşmuyor" >&2; exit 1; }
unzip -q "$tmp/godot.zip" -d "$tmp"
mkdir -p "$root/.tools"
if ((windows)); then
	# The zip has the GUI exe and the console exe side by side; the console exe looks for the GUI exe in the same dir.
	mv -f "$tmp/${name}" "$tmp/Godot_v${release}_win64_console.exe" "$root/.tools/"
else
	mv -f "$tmp/$name" "$bin"
	chmod +x "$bin"
fi
print_bin
