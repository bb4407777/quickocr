#!/bin/bash
# 编译 QuickOCR 并打包成 .app
set -euo pipefail
cd "$(dirname "$0")"

APP="QuickOCR.app"

swiftc -O main.swift -o QuickOCR \
  -framework Cocoa -framework Vision -framework Carbon

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp QuickOCR "$APP/Contents/MacOS/QuickOCR"
cp Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"
echo "已生成 $(pwd)/$APP"
