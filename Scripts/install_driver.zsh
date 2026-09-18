#!/bin/zsh
set -e

# 安装 VBAN Ultimate 虚拟音频驱动到 macOS 系统
PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
DRIVER_SRC="$PROJECT_DIR/build/VBANUltimateAudio.driver"
HAL_DIR="/Library/Audio/Plug-Ins/HAL"
CFG_DIR="/Library/Application Support/VBANUltimate"

if [ ! -d "$DRIVER_SRC" ]; then
    echo "Driver bundle not found. Building now..."
    "$PROJECT_DIR/Scripts/build_driver.zsh"
fi

echo "Installing VBAN Ultimate Virtual Audio Driver..."

# 确保配置目录存在并具备读写权限
if [ ! -d "$CFG_DIR" ]; then
    mkdir -p "$CFG_DIR"
fi
chmod 777 "$CFG_DIR"

# 同步既有用户配置
USER_CFG="$HOME/Library/Application Support/VBANUltimate/cables.plist"
if [ -f "$USER_CFG" ] && [ ! -f "$CFG_DIR/cables.plist" ]; then
    cp "$USER_CFG" "$CFG_DIR/cables.plist"
fi
if [ -f "$CFG_DIR/cables.plist" ]; then
    chmod 666 "$CFG_DIR/cables.plist"
fi

# 复制驱动插件到 HAL 目录
sudo rm -rf "$HAL_DIR/VBANUltimateAudio.driver"
sudo cp -R "$DRIVER_SRC" "$HAL_DIR/"
sudo chown -R root:wheel "$HAL_DIR/VBANUltimateAudio.driver"
sudo chmod -R 755 "$HAL_DIR/VBANUltimateAudio.driver"

# 触发 coreaudiod 重新载入 HAL 驱动插件
echo "Reloading coreaudiod..."
sudo killall -9 coreaudiod 2>/dev/null || true

echo "VBAN Ultimate Driver installed successfully!"
