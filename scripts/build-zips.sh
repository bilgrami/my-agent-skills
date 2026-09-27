#!/usr/bin/env bash
# Rebuild dist/<skill>.zip for every skill, ready to upload in Claude's Settings.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist
for dir in skills/*/; do
  name=$(basename "$dir")
  rm -f "dist/$name.zip"
  (cd skills && zip -qr -X "../dist/$name.zip" "$name" -x '*.DS_Store')
  echo "dist/$name.zip"
done
