#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[bootstrap] checking for tracked secrets"
if git ls-files --error-unmatch Config/Secrets.xcconfig >/dev/null 2>&1; then
  echo "[bootstrap] error: Config/Secrets.xcconfig must not be tracked"
  exit 1
fi

echo "[bootstrap] running swift package tests"
swift test

echo "[bootstrap] done"
