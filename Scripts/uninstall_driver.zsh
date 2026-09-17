#!/bin/zsh
set -e

HAL_DIR="/Library/Audio/Plug-Ins/HAL"
CFG_DIR="/Library/Application Support/VBANUltimate"

echo "Uninstalling VBAN Ultimate Virtual Audio Driver..."

if [ -d "$HAL_DIR/VBANUltimateAudio.driver" ]; then
    sudo rm -rf "$HAL_DIR/VBANUltimateAudio.driver"
fi

if [ -d "$CFG_DIR" ]; then
    sudo rm -rf "$CFG_DIR"
fi

echo "Reloading coreaudiod..."
sudo killall -9 coreaudiod 2>/dev/null || true

echo "VBAN Ultimate Driver uninstalled cleanly."
