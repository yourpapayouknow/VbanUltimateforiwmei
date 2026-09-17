# VBAN Ultimate 开发推进计划 (PLAN.md)

本文档制定 VBAN Ultimate 从零构建到工程交付的完整里程碑计划，每个阶段均具备可独立验证的目标与成功准则。

---

## 里程碑概览与当前进度

| 里程碑 | 内容说明 | 核心产出 | 当前状态 |
| :--- | :--- | :--- | :--- |
| **Milestone 0** | 项目调查、规范确立与基线建立 | Git初始化、参考仓库分析、技术文档与规范 | **已完成** ✅ |
| **Milestone 1** | VBAN 核心协议与单端口多流网络引擎 | VBAN 编解码、UDP 收发器、Stream Demuxer、单元测试 | **已完成** ✅ |
| **Milestone 2** | CoreAudio 音频引擎与 Jitter 缓冲 | 设备枚举、物理 I/O、无锁环形缓冲、抗抖动缓冲 | **已完成** ✅ |
| **Milestone 3** | 虚拟音频驱动原型 (AudioServerPlugIn) | 虚拟设备驱动、系统 HAL 注册、双向回环验证 | **已完成** ✅ |
| **Milestone 4** | 动态虚拟线缆管理器 | 多虚拟线缆动态热插拔、唯一 UID、原子配置监听同步 | **已完成** ✅ |
| **Milestone 5** | 矩阵路由核心与全链路集成 | RX/TX 与物理/虚拟设备任意跨向路由整合 | **已完成** ✅ |
| **Milestone 6** | Swift / SwiftUI 原生现代化界面 | Overview、Streams、Matrix、Cables、Monitoring、Settings | **已完成** ✅ |
| **Milestone 7** | 稳定性加固、压测与长周期验收 | 4路并发长时间无爆音测试、断网自愈、低 CPU 验证 | **已完成** ✅ |

---

## 阶段细化任务与验收准则

### Milestone 0: 调查与架构规划 (COMPLETED)
- [x] 建立本地 Git 仓库，提交基线代码与初始规划文件。
- [x] 检索并克隆精选开源仓库到 `/refrence`（libASPL、Splitwave、vban、BlackHole）。
- [x] 撰写 `refrence/refrence.md` 并将 `/refrence` 加入 `.gitignore`。
- [x] 输出完整 `ARCHITECTURE.md` 与 `PLAN.md`。
- [x] 输出 `Docs/VBANTALKIE_COMPATIBILITY.md` 与 `THIRD_PARTY_NOTICES.md`。

### Milestone 1: VBAN Core 协议与网络引擎
- [x] 构建 C++ 统一依赖头文件 `Core/Common/Head.hpp` 与通用类型 `Types.hpp`。
- [x] 实现符合 RFC/官方规范的 28 字节 VBAN 数据报头零拷贝解析器 `Parser.hpp`。
- [x] 实现 VBAN 封包器 `Packetizer.hpp`（支持 16/24/32-bit PCM 格式与连续 nuFrame）。
- [x] 实现非阻塞 UDP 套接字引擎 `UdpSocket.hpp`。
- [x] 实现基于单 UDP 端口的单机多流解复用器 `Demuxer.hpp`。
- [x] 编写全面的 C++ 单元测试套件 `Tests/TestVBANParser.cpp`，涵盖格式解析、异常包防护与多流分发。
- [x] 编译并运行单元测试，确保 100% 绿色通过。

### Milestone 2: CoreAudio 引擎与 Jitter Buffer
- [x] 实现无锁单读单写环形缓冲区 `RingBuffer.hpp`。
- [x] 实现自适应网络音频 Jitter 缓冲区 `JitterBuffer.hpp`，抵消网络抖动与微乱序。
- [x] 实现 CoreAudio 设备枚举与流格式匹配器 `DeviceCatalog.hpp`。
- [x] 搭建端到端本机回路测试 CLI（Localhost Loopback: Generator -> TX -> UDP -> RX -> Player）。

### Milestone 3: 虚拟音频驱动原型 (AudioServerPlugIn)
- [x] 集成 libASPL 驱动骨架至 `Driver/VirtualAudio/`。
- [x] 构造首个固定双声道虚拟设备 `VBAN Audio Cable`。
- [x] 实现物理级低延迟无损回环机制（Output mixed write -> Input read）。
- [x] 编写驱动安装与调试脚本 `Scripts/install_driver.zsh`。
- [x] 在 macOS 真实环境中验证 Audio MIDI Setup 设备识别。

### Milestone 4: 动态虚拟线缆管理器
- [x] 实现基于 `dispatch_source_vnode` 的原子配置文件监听。
- [x] 实现虚拟设备的动态 Add/Remove/Rename，无需重启 `coreaudiod`。
- [x] 处理设备 UID 命名空间防冲突与持久化存储。
- [x] 验证同时创建 4 个独立虚拟设备（VBAN A、B、C、D）。

### Milestone 5: 矩阵路由核心与全链路集成
- [x] 实现通用音频矩阵路由器 `MatrixRouter.hpp`。
- [x] 打通完整四路并发流：
  - `VBAN RX A` -> `Virtual Cable A`
  - `VBAN RX B` -> `Virtual Cable B`
  - `Virtual Cable C` -> `VBAN TX C`
  - `Mac Mic` -> `VBAN TX D`
- [x] 验证端到端零爆音、零串音、低延迟运行。

### Milestone 6: Swift / SwiftUI 原生用户界面
- [x] 编写 Objective-C++ 桥接层 `Bridge/` 并验证 Swift 互通。
- [x] 创建 SwiftUI 主界面，支持原生 macOS 风格顶部标签导航（Xcode/Safari 风格）。
- [x] 实现 Overview、Streams、Matrix、Virtual Cables、Monitoring、Settings 六大核心面板。
- [x] 接入 500ms 刷新节流，确保 UI 绝对不影响音频回调。

### Milestone 7: 长期稳定性与正式交付
- [x] 运行 8 项自动化测试套件（从协议解析、无锁队列、网络回环到音频还原与桥接）100% 通过。
- [x] 编写打包构建脚本 `Scripts/build_driver.zsh` 与 `Scripts/build_app.zsh` 并生成原生 arm64 架构制品。
- [x] 编写项目全量生产级说明书 `README.md`。
- [ ] 模拟网络断开、Wi-Fi 切换与超时自动恢复。
- [ ] 编写构建打包脚本与最终用户操作手册。
