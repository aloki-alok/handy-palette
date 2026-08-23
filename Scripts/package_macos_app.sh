#!/bin/bash
set -euo pipefail

readonly project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly icon_source="$project_root/docs/handy-icon.png"
readonly plist_template="$project_root/Distribution/HandyPalette-Info.plist"

usage() {
  echo "Usage: $0 [version] [output-directory]" >&2
  exit 64
}

version="${1:-}"
output_directory="${2:-$project_root/dist}"

if [[ $# -gt 2 ]]; then
  usage
fi

if [[ -z "$version" ]]; then
  version="$(git -C "$project_root" describe --exact-match --tags --match 'v[0-9]*' 2>/dev/null | sed 's/^v//')" || {
    echo "A version argument is required outside an exact v* Git tag." >&2
    exit 64
  }
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid version: $version" >&2
  exit 64
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "This packager produces an arm64 archive and must run on an arm64 Mac." >&2
  exit 65
fi

for required_path in "$icon_source" "$plist_template"; do
  if [[ ! -f "$required_path" ]]; then
    echo "Required packaging input is missing: $required_path" >&2
    exit 66
  fi
done

build_directory="$project_root/.build/release"
gui_binary="$build_directory/Handy"
cli_binary="$build_directory/HandyCLI"
resource_bundle="$build_directory/Handy_HandyCore.bundle"

cd "$project_root"
swift build -c release --product Handy
swift build -c release --product HandyCLI

for required_path in "$gui_binary" "$cli_binary" "$resource_bundle"; do
  if [[ ! -e "$required_path" ]]; then
    echo "SwiftPM did not produce required release output: $required_path" >&2
    exit 67
  fi
done

binary_version="$($cli_binary version | sed -n 's/^Handy Palette //p')"
if [[ "$binary_version" != "$version" ]]; then
  echo "Package version $version does not match binary version $binary_version." >&2
  exit 68
fi

staging_directory="$(mktemp -d "${TMPDIR:-/tmp}/handy-palette-package.XXXXXX")"
trap 'rm -rf "$staging_directory"' EXIT

app_bundle="$staging_directory/Handy Palette.app"
contents="$app_bundle/Contents"
resources="$contents/Resources"
macos="$contents/MacOS"
helpers="$contents/Helpers"
archive="$output_directory/Handy-Palette-${version}-arm64.zip"

mkdir -p "$resources" "$macos" "$helpers" "$output_directory"
sed "s/__VERSION__/$version/g" "$plist_template" > "$contents/Info.plist"
iconset="$staging_directory/HandyPalette.iconset"
mkdir -p "$iconset"
sips -z 16 16 "$icon_source" --out "$iconset/icon_16x16.png" >/dev/null
sips -z 32 32 "$icon_source" --out "$iconset/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$icon_source" --out "$iconset/icon_32x32.png" >/dev/null
sips -z 64 64 "$icon_source" --out "$iconset/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$icon_source" --out "$iconset/icon_128x128.png" >/dev/null
sips -z 256 256 "$icon_source" --out "$iconset/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$icon_source" --out "$iconset/icon_256x256.png" >/dev/null
sips -z 512 512 "$icon_source" --out "$iconset/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$icon_source" --out "$iconset/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$icon_source" --out "$iconset/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$iconset" -o "$resources/HandyPalette.icns"

install -m 755 "$gui_binary" "$macos/HandyPalette"
install -m 755 "$cli_binary" "$helpers/handy-palette"
cp -R "$resource_bundle" "$resources/Handy_HandyCore.bundle"
install -m 644 "$resource_bundle/starter-library.json" "$resources/starter-library.json"

codesign --force --sign - --timestamp=none "$macos/HandyPalette"
codesign --force --sign - --timestamp=none "$helpers/handy-palette"
codesign --force --sign - --timestamp=none "$app_bundle"
codesign --verify --deep --strict --verbose=2 "$app_bundle"

rm -f "$archive"
ditto -c -k --keepParent "$app_bundle" "$archive"
shasum -a 256 "$archive"
echo "Created arm64 archive: $archive"
