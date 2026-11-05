#!/usr/bin/env bash
# Copies the canonical level configs into the app bundle (offline-first:
# World 1 ships inside the APK; later worlds download via the content API).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/app/assets/levels"
cp "$root"/content/levels/*.json "$root/app/assets/levels/"
echo "synced $(ls "$root"/content/levels/*.json | wc -l) level(s)"
