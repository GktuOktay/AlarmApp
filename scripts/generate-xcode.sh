#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen gerekli. Kurulum: brew install xcodegen"
  exit 1
fi

if ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
  echo "Tam Xcode gerekli. Xcode'u kurup şunu çalıştır:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

xcodegen generate
echo "Oluştu: AlarmApp.xcodeproj — açmak için: open AlarmApp.xcodeproj"
