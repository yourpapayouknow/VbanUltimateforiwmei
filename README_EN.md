<div align="center">

<img src="Resources/AppIcon.png" alt="VBAN Ultimate Icon" width="128" height="128" />

# VBAN Ultimate for macOS

![Project badge](assets/readme-badge.png)

**Native, Ultra-Low-Latency Broadcast VBAN Audio Matrix & CoreAudio Dynamic Virtual Audio Cable Workstation built exclusively for Apple Silicon.**

[English](README_EN.md) · [简体中文](README.md)

[![macOS](https://img.shields.io/badge/Platform-macOS%2013%2B-blue.svg?style=flat-square)](https://apple.com/macos)
[![Architecture](https://img.shields.io/badge/Arch-arm64%20(Apple%20Silicon)-orange.svg?style=flat-square)](https://apple.com)
[![Engine](https://img.shields.io/badge/Engine-C%2B%2B20%20RT--Safe-green.svg?style=flat-square)](Core/)
[![UI](https://img.shields.io/badge/UI-SwiftUI%20Native-cyan.svg?style=flat-square)](App/)
[![License](https://img.shields.io/badge/License-MIT-purple.svg?style=flat-square)](LICENSE)

</div>

---

## 📖 Overview

**VBAN Ultimate** is an infrastructure-grade audio utility that natively bridges **VBAN (VB-Audio Network)** network streaming and **macOS CoreAudio HAL**. Purpose-built for high-fidelity, low-latency LAN audio transmission, it eliminates DAW bloat while excelling across four essential engineering pillars:

1. **Single-Port Multiplexed Audio Streaming**: Operates over official VBAN UDP port `6980`, delivering full-duplex, zero-copy multi-stream demultiplexing and transmission on a single network socket.
2. **Broadcast 4x4 Dot-Grid Crosspoint Router**: True broadcast audio routing matrix logic with single-destination source mutual exclusion and broadcast fan-out (one source to many outputs).
3. **Native CoreAudio HAL Dynamic Virtual Cables**: High-performance system-level `AudioServerPlugIn` driver that appears natively in Audio MIDI Setup. Dynamic cable creation and reconfiguration require no daemon restarts.
4. **Sub-millisecond Jitter & Quality Diagnostics**: Adaptive jitter buffers, lock-free SPSC ring buffers, real-time packet loss, and physical bandwidth telemetry.

---

## 🏛️ System Architecture

```mermaid
graph TD
    subgraph LAN [Local Area Network Audio Streams (VBAN)]
        PC1[Host A VBAN Sender] -->|UDP:6980| SOCK[Single UDP Socket]
        PC2[Host B VBAN Sender] -->|UDP:6980| SOCK
    end

    subgraph Core [C++20 RT-Safe Audio Core]
        SOCK --> DMX[Stream Demuxer]
        DMX --> JB[Adaptive Micro-Jitter Buffer]
        JB --> RB[Lock-Free SPSC Ring Buffer]
        RB --> RTR[4x4 Matrix Router]
    end

    subgraph macOS [macOS CoreAudio HAL]
        RTR --> SPK[Speakers / Headphones]
        RTR --> DRV[VBANUltimateAudio.driver]
        DRV --> CBL1[Virtual Cable A]
        DRV --> CBL2[Virtual Cable B]
        CBL1 --> OBS[OBS Studio / Logic Pro / Conferences]
    end
```

---

## ✨ Key Features

- **Dual-Column Symmetrical Stream Cards**: Left column displays active RX streams with dynamically parsed bit depth (8/16/24/32-bit), throughput, and jitter/loss metrics; right column displays TX streams with source device, destination IP, and real-time bandwidth.
- **4x4 Dot-Grid Crosspoint Alignment**: Matrix grid slots are mathematically aligned to the dot canvas ($4 \times 24 = 96\text{pt}$), rendering clean, transparent cells with a prominent centered `ON` indicator for connected routes.
- **Dual-Column Soundstage Meters**: Horizontally paired L/R meters for 1CH, 2CH, 4CH, 6CH, and 8CH configurations. 50Hz hardware-backed physical metering accurately resting at `-∞ dB` during silence.
- **Smart Port Conflict Resolution**: Never silently degrades when UDP 6980 is occupied. Displays a clean status capsule and provides one-click inspection to safely take over the port with user confirmation.
- **Dynamic Bilingual Localization**: Fluid real-time switching between English and Simplified Chinese with all operational guidance neatly converged into native macOS tooltips.

---

## 💻 System Requirements

- **Operating System**: macOS 13.0 (Ventura) or later (fully compatible with macOS 14 Sonoma and macOS 15 Sequoia);
- **Architecture**: Apple Silicon (`arm64`, natively optimized for M1 / M2 / M3 / M4);
- **Toolchain**: Xcode Command Line Tools (`clang++`, `swiftc`).

---

## 🚀 Quick Start & Installation

### Option 1: Download Official Release
Download the pre-compiled package from GitHub Releases:
1. Download `VBANUltimate-v1.0.0-macOS-arm64.dmg` or `.zip`;
2. Drag `VBANUltimate.app` to `/Applications`;
3. To enable virtual audio cables, run the driver installer script once in Terminal:
   ```zsh
   sudo ./Scripts/install_driver.zsh
   ```

### Option 2: Build and Install from Source
Clone the repository and build natively using Zsh:

```zsh
# 1. Build the CoreAudio HAL driver
./Scripts/build_driver.zsh

# 2. Install driver to /Library/Audio/Plug-Ins/HAL/ (requires sudo)
sudo ./Scripts/install_driver.zsh

# 3. Compile and sign the macOS Application
./Scripts/build_app.zsh

# 4. Deploy permanently to /Applications
cp -R build/VBANUltimate.app /Applications/
```

---

## 🛠️ Automated Test Suite

The project includes an end-to-end verification suite written in C++20 and Swift:

```zsh
# Run protocol parser and boundary tests
clang++ -std=c++20 -O2 Tests/TestVBANParser.cpp -o bin/test_vban_parser && ./bin/test_vban_parser

# Run multi-stream UDP loopback test
clang++ -std=c++20 -O2 Tests/TestNetworkLoopback.cpp -o bin/test_network_loopback && ./bin/test_network_loopback

# Run lock-free SPSC concurrency & jitter buffer tests
clang++ -std=c++20 -O2 Tests/TestRingBuffer.cpp -o bin/test_ring_buffer && ./bin/test_ring_buffer

# Run CoreAudio hardware enumeration test
clang++ -std=c++20 -O2 -framework CoreAudio -framework CoreFoundation Tests/TestAudioDeviceCatalog.cpp -o bin/test_device_catalog && ./bin/test_device_catalog

# Run sine wave audio reconstruction test
clang++ -std=c++20 -O2 Tests/TestAudioLoopback.cpp -o bin/test_audio_loopback && ./bin/test_audio_loopback

# Run dynamic cable manager & plist persistence test
clang++ -std=c++20 -O2 -framework CoreAudio -framework CoreFoundation Tests/TestCableManager.cpp -o bin/test_cable_manager && ./bin/test_cable_manager

# Run audio matrix routing test
clang++ -std=c++20 -O2 -framework CoreAudio -framework CoreFoundation Tests/TestMatrixRouter.cpp -o bin/test_matrix_router && ./bin/test_matrix_router
```

---

## 📜 Credits & Acknowledgments

- **[VB-Audio Software](https://vb-audio.com/) (Vincent Burel)**: Original creator of the VBAN audio over IP protocol and official specifications.
- **[Existential Audio / BlackHole](https://github.com/ExistentialAudio/BlackHole) (Devin Roth)**: Inspiration for macOS CoreAudio loopback drivers and HAL plug-in implementations.
- **[libASPL](https://github.com/gavv/aspl) (Alexander Gavrilov)**: Modern C++ AudioServerPlugIn framework for macOS.

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
