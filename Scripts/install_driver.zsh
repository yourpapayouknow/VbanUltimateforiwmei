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

# 确保配置目录存在且具有普通写权限
if [ ! -d "$CFG_DIR" ]; then
    sudo mkdir -p "$CFG_DIR"
    sudo chmod 777 "$CFG_DIR"
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
