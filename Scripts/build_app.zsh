#!/bin/zsh
set -e

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/VBANUltimate.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"

echo "Building VBAN Ultimate macOS Application..."

mkdir -p "$MACOS_DIR"
mkdir -p "$PROJECT_DIR/bin"

# 1. 编译 Objective-C++ 桥接目标文件
echo "Compiling BridgeCore.mm..."
clang++ -std=c++20 -x objective-c++ -c "$PROJECT_DIR/Bridge/BridgeCore.mm" \
    -target arm64-apple-macos13.0 \
    -o "$PROJECT_DIR/bin/BridgeCore.o" -Wall -Wextra -fobjc-arc

# 2. 生成 App Info.plist 并同步 Resources
mkdir -p "$APP_DIR/Contents/Resources"
if [ -d "$PROJECT_DIR/Resources" ]; then
    cp -R "$PROJECT_DIR/Resources/"* "$APP_DIR/Contents/Resources/"
fi

cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>VBANUltimate</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.iwmei.vbanultimate</string>
    <key>CFBundleName</key>
    <string>VBANUltimate</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>VBAN Ultimate requires microphone access for VBAN audio transmission.</string>
</dict>
</plist>
EOF

# 3. 编译 Swift / SwiftUI 源文件
echo "Compiling Swift / SwiftUI application..."
swiftc -O \
    -target arm64-apple-macos13.0 \
    -import-objc-header "$PROJECT_DIR/Bridge/VBANUltimate-Bridging-Header.h" \
    "$PROJECT_DIR/bin/BridgeCore.o" \
    "$PROJECT_DIR/App/Theme.swift" \
    "$PROJECT_DIR/App/ViewModels/AppModel.swift" \
    "$PROJECT_DIR/App/Views/StreamsView.swift" \
    "$PROJECT_DIR/App/Views/MatrixView.swift" \
    "$PROJECT_DIR/App/Views/CablesView.swift" \
    "$PROJECT_DIR/App/Views/MonitoringView.swift" \
    "$PROJECT_DIR/App/Views/VbanPingSheet.swift" \
    "$PROJECT_DIR/App/Views/SettingsView.swift" \
    "$PROJECT_DIR/App/Views/MainContainerView.swift" \
    "$PROJECT_DIR/App/VBANUltimateApp.swift" \
    -lc++ \
    -framework CoreAudio \
    -framework AudioToolbox \
    -framework AudioUnit \
    -framework CoreFoundation \
    -framework SwiftUI \
    -framework AppKit \
    -o "$MACOS_DIR/VBANUltimate"

# 4. 代码签名（携带音频输入权限声明）
SIGN_ID="VBAN Ultimate Local Signing"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
    echo "Signing VBAN Ultimate application bundle with: $SIGN_ID"
    codesign --force --deep --sign "$SIGN_ID" \
        --entitlements "$PROJECT_DIR/Resources/VBANUltimate.entitlements" \
        "$APP_DIR"
else
    echo "WARNING: signing identity '$SIGN_ID' not found, falling back to ad-hoc."
    echo "         Microphone capture will be silently blocked by TCC."
    codesign --force --deep --sign - \
        --entitlements "$PROJECT_DIR/Resources/VBANUltimate.entitlements" \
        "$APP_DIR"
fi
codesign -dvvv "$APP_DIR" 2>&1 | grep -E "Identifier|Authority|Signature|TeamIdentifier"

echo "Application built and signed successfully at: $APP_DIR"
file "$MACOS_DIR/VBANUltimate"
