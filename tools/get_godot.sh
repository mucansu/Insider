#!/usr/bin/env bash
# Godot ikilisini hazırlar ve yolunu stdout'a basar (mimari.md §1). Sürüm yalnız burada tutulur.
#   GODOT ortam değişkeni verilmişse onu kullanır (sürüm farklıysa uyarır).
#   Yoksa Godot 4.7.2-stable Linux x86_64 ikilisini <proje>/.tools/godot'a indirir (varsa atlar),
#   SHA-512 özetini resmi SHA512-SUMS.txt değeriyle doğrular.
# Kullanım: "$(tools/get_godot.sh)" --version
set -euo pipefail

GODOT_VERSION="4.7.2"
GODOT_ZIP_SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"

release="${GODOT_VERSION}-stable"
want="${GODOT_VERSION}.stable"

if [[ -n "${GODOT:-}" ]]; then
	if ! have="$("$GODOT" --version 2>/dev/null | tail -n 1)"; then
		echo "get_godot: GODOT=$GODOT çalıştırılamıyor" >&2
		exit 1
	fi
	[[ "$have" == "$want"* ]] || echo "get_godot: UYARI: GODOT=$GODOT sürümü $have, beklenen $want" >&2
	echo "$GODOT"
	exit 0
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bin="$root/.tools/godot"
if [[ -x "$bin" ]] && "$bin" --version 2>/dev/null | tail -n 1 | grep -q "^${want}"; then
	echo "$bin"
	exit 0
fi

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
	echo "get_godot: yalnız Linux x86_64 indirilir; Godot $release kurup GODOT=/yol/godot verin" >&2
	exit 1
fi

name="Godot_v${release}_linux.x86_64"
url="https://github.com/godotengine/godot/releases/download/${release}/${name}.zip"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "get_godot: indiriliyor $url" >&2
curl -fsSL --retry 3 -o "$tmp/godot.zip" "$url"
echo "${GODOT_ZIP_SHA512}  $tmp/godot.zip" | sha512sum -c --quiet - >&2 \
	|| { echo "get_godot: SHA-512 uyuşmuyor" >&2; exit 1; }
unzip -q "$tmp/godot.zip" -d "$tmp"
mkdir -p "$root/.tools"
mv -f "$tmp/$name" "$bin"
chmod +x "$bin"
echo "$bin"
