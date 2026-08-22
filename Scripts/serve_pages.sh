#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
port="${1:-4173}"
artifact_dir="$repo_root/.build/pages-e2e"

"$repo_root/Scripts/build_pages.sh" "$artifact_dir"
exec python3 -m http.server "$port" --directory "$artifact_dir"
