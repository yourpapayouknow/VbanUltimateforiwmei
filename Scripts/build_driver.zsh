#!/bin/zsh
set -e

# 目标输出目录
PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$PROJECT_DIR/build"
BUNDLE_DIR="$BUILD_DIR/VBANUltimateAudio.driver"
MACOS_DIR="$BUNDLE_DIR/Contents/MacOS"

echo "Building VBAN Ultimate Virtual Audio Driver..."

mkdir -p "$MACOS_DIR"
cp "$PROJECT_DIR/Driver/VirtualAudio/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"

# 编译所有 libASPL 源码与驱动入口
LIBASPL_DIR="$PROJECT_DIR/refrence/libASPL"

clang++ -std=c++17 -dynamiclib \
    -arch arm64 \
    -mmacosx-version-min=13.0 \
    -O2 -fblocks \
    -framework CoreAudio \
    -framework CoreFoundation \
    -I "$LIBASPL_DIR/include" \
    -o "$MACOS_DIR/VBANUltimateAudio" \
    "$PROJECT_DIR/Driver/VirtualAudio/DriverEntry.cpp" \
    "$LIBASPL_DIR"/src/*.cpp

echo "Driver built successfully at: $BUNDLE_DIR"
file "$MACOS_DIR/VBANUltimateAudio"
