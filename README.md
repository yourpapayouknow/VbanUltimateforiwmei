<div align="center">

<img src="Resources/AppIcon.png" alt="VBAN Ultimate Icon" width="128" height="128" />

# VBAN Ultimate for macOS

![Project badge](assets/readme-badge.png)

**专为 Apple Silicon 架构量身打造的原生轻量、超低延迟广播级 VBAN 音频路由矩阵与 CoreAudio 动态虚拟音频线缆工作台**

[English](README_EN.md) · [简体中文](README.md)

[![macOS](https://img.shields.io/badge/Platform-macOS%2013%2B-blue.svg?style=flat-square)](https://apple.com/macos)
[![Architecture](https://img.shields.io/badge/Arch-arm64%20(Apple%20Silicon)-orange.svg?style=flat-square)](https://apple.com)
[![Engine](https://img.shields.io/badge/Engine-C%2B%2B20%20RT--Safe-green.svg?style=flat-square)](Core/)
[![UI](https://img.shields.io/badge/UI-SwiftUI%20Native-cyan.svg?style=flat-square)](App/)
[![License](https://img.shields.io/badge/License-MIT-purple.svg?style=flat-square)](LICENSE)

</div>

---

## 📖 项目概览 (Overview)

**VBAN Ultimate** 是一套基础设施级的专业音频工作台，深度贯通 **VBAN (VB-Audio Network)** 网络音频流协议与 **macOS CoreAudio HAL** 系统硬件抽象层。项目专为低延迟、高保真局域网音频分发设计，剔除了传统宿主软件（DAW）的臃肿堆叠，专注于三大核心支柱：

1. **单端口多路音频流复用**：遵循 VBAN 官方 UDP 6980 标准端口，单套接字实现多路网络音频流的全双工零拷贝解复用与并发发送。
2. **广播级 4x4 点阵路由矩阵**：严格遵循专业路由器（Audio Router / Matrix Switcher）逻辑，单目标输出源互斥切换，输入信号支持广播级一对多分发（Fan-out）。
3. **CoreAudio HAL 原生虚拟音频线缆**：自主研发的系统级 `AudioServerPlugIn` 驱动，在系统原生“音频与MIDI设置”中完全可见，热增删配置无需重启音频守护进程 `coreaudiod`。
4. **全链路微秒级抖动诊断**：毫秒与微秒级网络抖动吸收、无锁 SPSC 环形缓冲、丢包率及真实吞吐带宽实时监控。

---

## 🏛️ 信号链路与系统架构

```mermaid
graph TD
    subgraph LAN [局域网网络音频流 (VBAN)]
        PC1[工作站 A 发送端] -->|UDP:6980| SOCK[单 UDP 监听套接字]
        PC2[工作站 B 发送端] -->|UDP:6980| SOCK
    end

    subgraph Core [C++20 RT-Safe 音频内核]
        SOCK --> DMX[流解复用器 Demuxer]
        DMX --> JB[自适应微抖动吸收器 JitterBuffer]
        JB --> RB[无锁 SPSC 环形缓冲区 RingBuffer]
        RB --> RTR[4x4 点阵路由矩阵 MatrixRouter]
    end

    subgraph macOS [macOS CoreAudio 系统音频]
        RTR --> SPK[物理扬声器 / 耳机输出]
        RTR --> DRV[VBANUltimateAudio.driver]
        DRV --> CBL1[虚拟音频线缆 Cable A]
        DRV --> CBL2[虚拟音频线缆 Cable B]
        CBL1 --> OBS[OBS Studio / Logic Pro / 协作会议]
    end
```

---

## ✨ 核心特性

- **双列流对称卡片排版**：左列纯粹展示接收流（RX）动态采样率、声道、位深（真实动态解析 8/16/24/32-bit）、真实吞吐与抖动丢包；右列展示发送流（TX）设备源、目标 IP 与对称带宽指示。
- **4x4 点阵矩阵对齐设计**：矩阵方格与点阵画布实行点对点数学对齐（$4 \times 24 = 96\text{pt}$），视觉通透；激活状态中心高亮显示醒目 `ON` 标头，支持单击直观建立或切断路由。
- **双列声场横向电平表**：支持 1CH / 2CH / 4CH / 6CH / 8CH 多声道立体声场左右对称对阵排布，50Hz 真实物理能量直出，无信号时呈现专业静音基准 `-∞ dB`。
- **智能端口冲突排查接管**：当 UDP 6980 被外部程序占用时，拒绝静默降级，常驻右上角安全警示，支持一键探测占用进程并原生弹窗授权安全接管。
- **国际化双语热切换**：全系统支持简体中文与英文专业音频术语一键平滑热切换，所有操作指引与技术参数说明全部收敛至原生悬浮提示（Tooltip）。

---

## 💻 系统与硬件要求

- **操作系统**：macOS 13.0 (Ventura) 及以上版本（支持 macOS 14 Sonoma 与 macOS 15 Sequoia）；
- **硬件架构**：Apple Silicon (`arm64`，M1 / M2 / M3 / M4 架构原生编译与优化）；
- **开发工具**：Xcode Command Line Tools（包含 `clang++` 与 `swiftc`）。

---

## 🚀 快速安装与使用

### 方式 1：直接下载正式发布包
从 GitHub Releases 下载预编译发布包：
1. 下载 `VBANUltimate-v1.0.0-macOS-arm64.dmg` 或 `.zip`；
2. 将 `VBANUltimate.app` 拖移至 `/Applications`（应用程序目录）；
3. 首次使用如需虚拟音频线缆功能，在终端运行项目脚本安装系统驱动：
   ```zsh
   sudo ./Scripts/install_driver.zsh
   ```

### 方式 2：从源码编译并固化至本机
克隆仓库后，通过终端执行纯脚本构建：

```zsh
# 1. 编译 CoreAudio 驱动
./Scripts/build_driver.zsh

# 2. 安装驱动至系统 HAL 目录（需要管理员授权）
sudo ./Scripts/install_driver.zsh

# 3. 编译并签名 macOS 原生应用程序
./Scripts/build_app.zsh

# 4. 将正式版本固化部署至 /Applications
cp -R build/VBANUltimate.app /Applications/
```

---

## 🛠️ 自动化测试套件

工程内建完整的 C++20 与 Swift 原生验证套件，覆盖协议、无锁环形队列、并发网络与硬件枚举：

```zsh
# 运行协议头与边界测试
clang++ -std=c++20 -O2 Tests/TestVBANParser.cpp -o bin/test_vban_parser && ./bin/test_vban_parser

# 运行本地 UDP 回环多流测试
clang++ -std=c++20 -O2 Tests/TestNetworkLoopback.cpp -o bin/test_network_loopback && ./bin/test_network_loopback

# 运行无锁 SPSC 环形缓冲高并发测试
clang++ -std=c++20 -O2 Tests/TestRingBuffer.cpp -o bin/test_ring_buffer && ./bin/test_ring_buffer

# 运行 CoreAudio 硬件设备探测测试
clang++ -std=c++20 -O2 -framework CoreAudio -framework CoreFoundation Tests/TestAudioDeviceCatalog.cpp -o bin/test_device_catalog && ./bin/test_device_catalog

# 运行正弦波音频还原重建测试
clang++ -std=c++20 -O2 Tests/TestAudioLoopback.cpp -o bin/test_audio_loopback && ./bin/test_audio_loopback

# 运行虚拟线缆生命周期与 Plist 存储测试
clang++ -std=c++20 -O2 -framework CoreAudio -framework CoreFoundation Tests/TestCableManager.cpp -o bin/test_cable_manager && ./bin/test_cable_manager

# 运行矩阵路由分发测试
clang++ -std=c++20 -O2 -framework CoreAudio -framework CoreFoundation Tests/TestMatrixRouter.cpp -o bin/test_matrix_router && ./bin/test_matrix_router
```

---

## 📜 开源鸣谢与致敬

- **[VB-Audio Software](https://vb-audio.com/) (Vincent Burel)**：VBAN 协议原创发明者与官方标准制定者。
- **[Existential Audio / BlackHole](https://github.com/ExistentialAudio/BlackHole) (Devin Roth)**：macOS 虚拟音频回环驱动架构与 CoreAudio HAL 规范实践的先驱。
- **[libASPL](https://github.com/gavv/aspl) (Alexander Gavrilov)**：现代 C++ 面向对象的 CoreAudio `AudioServerPlugIn` 开源框架。

---

## 📄 许可证

本项目遵循 MIT 协议开源。详细信息请参阅 [LICENSE](LICENSE) 文件。
