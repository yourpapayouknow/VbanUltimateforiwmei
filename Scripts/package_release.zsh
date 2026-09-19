#!/bin/zsh
set -e

# 打包发布产物脚本
PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/VBANUltimate.app"
DIST_DIR="$BUILD_DIR/dist"
VERSION="1.0.0"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH does not exist. Please run build_app.zsh first."
    exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "Packaging VBAN Ultimate v$VERSION for macOS (arm64)..."

# 1. 验证签名完整性
echo "Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH"

# 2. 生成 ZIP 发布包
echo "Creating ZIP archive..."
ZIP_NAME="VBANUltimate-v${VERSION}-macOS-arm64.zip"
(cd "$BUILD_DIR" && ditto -c -k --sequesterRsrc --keepParent VBANUltimate.app "$DIST_DIR/$ZIP_NAME")
echo "Created: $DIST_DIR/$ZIP_NAME"

# 3. 生成 DMG 安装镜像
echo "Creating DMG disk image..."
DMG_NAME="VBANUltimate-v${VERSION}-macOS-arm64.dmg"
DMG_TMP="$BUILD_DIR/dmg_tmp"
rm -rf "$DMG_TMP"
mkdir -p "$DMG_TMP"

cp -R "$APP_PATH" "$DMG_TMP/"
ln -s /Applications "$DMG_TMP/Applications"

hdiutil create -volname "VBAN Ultimate" -srcfolder "$DMG_TMP" -ov -format UDZO "$DIST_DIR/$DMG_NAME"
rm -rf "$DMG_TMP"
echo "Created: $DIST_DIR/$DMG_NAME"

echo "Packaging completed successfully!"
ls -lh "$DIST_DIR"
