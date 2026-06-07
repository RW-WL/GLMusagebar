#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="GLMUsageBar"
APP_BUNDLE="${PROJECT_DIR}/build/${APP_NAME}.app"
EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "🔨 Compiling..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

swiftc \
    -o "${EXECUTABLE}" \
    "${PROJECT_DIR}/Sources/Models.swift" \
    "${PROJECT_DIR}/Sources/UsageService.swift" \
    "${PROJECT_DIR}/Sources/main.swift" \
    -framework Cocoa \
    -Osize

cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

echo "✅ Built: ${APP_BUNDLE}"
echo "📦 Size: $(du -sh "${APP_BUNDLE}" | cut -f1)"
echo "🚀 Run: open \"${APP_BUNDLE}\""