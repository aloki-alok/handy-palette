#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${1:-$repo_root/.build/pages}"

mkdir -p "$output_dir"
cp "$repo_root/docs/index.html" "$output_dir/index.html"
cp "$repo_root/docs/kana-icon.png" "$output_dir/kana-icon.png"
cp "$repo_root/Sources/KanaCore/Resources/starter-library.json" "$output_dir/catalog.json"

printf 'Built GitHub Pages artifact at %s\n' "$output_dir"
