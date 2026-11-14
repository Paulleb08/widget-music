#!/bin/bash
# Compile le widget et le lance. Nécessite les outils Xcode : xcode-select --install
set -euo pipefail
cd "$(dirname "$0")"
APP=MusicWidget.app
mkdir -p "$APP/Contents/MacOS"
swiftc -O main.swift -o "$APP/Contents/MacOS/MusicWidget"
cp Info.plist "$APP/Contents/"
codesign --force -s - "$APP"
open "$APP"
