# VBAN Ultimate 架构白皮书 (ARCHITECTURE.md)

本文档定义 VBAN Ultimate (`vbanultimateforiwmei`) 的顶层系统架构、模块分层边界、数据流时序、线程模型以及实时安全规范。

---

## 1. 顶层设计原则

1. **专注纯粹**：定位为“VBAN 网络音频 + CoreAudio 虚拟线缆基础设施工具”，严禁引入 DAW 复杂的 DSP 链、效果器、多轨混音或屏幕捕获功能。
2. **实时安全（RT-Safe）**：CoreAudio 实时线程内绝对禁止动态内存分配（`malloc`/`new`）、文件系统 I/O、锁阻塞、字符串拼接或 Objective-C/Swift 消息派发。
3. **单 Socket 多流复用**：单物理 UDP 端口统一收包，通过报头中的 `streamname`、源 IP 及端口实现极速多流解复用（Demux），避免为每条流创建独立的系统网络套接字。
4. **动态驱动同步**：基于 macOS CoreAudio `AudioServerPlugIn` 规范，通过用户空间安全配置信号通知，实现无需重启系统 `coreaudiod` 的虚拟音频设备即时增删改。
5. **现代模块化架构**：
   ```text
   Swift / SwiftUI (UI/交互层)
          ↓ (Combine / Observable / FFI)
   Objective-C++ / C-ABI Bridge (胶水桥接层)
          ↓ (Zero-copy Buffers & Events)
   C++20 Audio & Network Core (核心层：协议/网络/路由/指标)
          ↓ (CoreAudio HAL API / IO Handler)
   AudioServerPlugIn Driver (内核音频驱动插件)
   ```

---

## 2. 核心模块分工与目录结构

```text
vbanultimateforiwmei/
├── App/                       # Swift / SwiftUI 应用程序入口与原生视窗
│   ├── Views/                 # Overview, Streams, Matrix, Cables, Monitoring, Settings
│   └── ViewModels/            # 状态发布与 UI 刷新解耦 (500ms~1s 定时节流)
├── Bridge/                    # Objective-C++ / C 导出接口，为 Swift 提供类型安全绑定
│   ├── HeadBridge.h           # 统一桥接头文件
│   └── BridgeCore.mm          # C++ Core 到 Swift 原生数据类型转换
├── Core/                      # C++20 业务逻辑与音频核心
│   ├── Common/
│   │   ├── Head.hpp           # 全局统一依赖引入与基础宏定义
│   │   ├── RingBuffer.hpp     # 单读单写无锁环形缓冲区 (Lock-free SPSC)
│   │   └── Types.hpp          # 基础类型与统一枚举
│   ├── VBAN/                  # VBAN 协议编解码与验证 (RFC/官方规范)
│   │   ├── Protocol.hpp       # VBAN Header 结构体定义 (28字节)
│   │   ├── Parser.hpp         # 零拷贝包解析与有效性校验
│   │   └── Packetizer.hpp     # 音频帧打包与帧计数器递增
│   ├── Network/               # 高性能 UDP 通信层
│   │   ├── UdpSocket.hpp      # 非阻塞 POSIX UDP Socket 封装
│   │   ├── Demuxer.hpp        # 依据 StreamName/IP 的单端口多流分发器
│   │   └── JitterBuffer.hpp   # 抗抖动、抗乱序与丢包平滑缓冲池
│   ├── Audio/                 # CoreAudio 物理设备捕获与播放引擎
│   │   ├── AudioEngine.hpp    # AudioUnit / AudioOutputUnitStart 调度
│   │   └── DeviceCatalog.hpp  # 系统物理音频输入/输出设备枚举与监听
│   ├── Routing/               # 矩阵映射核心
│   │   └── MatrixRouter.hpp   # Source (Input/Cable/RX) -> Destination (Output/Cable/TX)
│   └── Monitoring/            # 统计与指标计算
│   │   ├── StreamStats.hpp    # 丢包率、Jitter、速率、水位指标追踪
│   │   └── MetricsEngine.hpp  # 集中式指标收集器与快照生成器
├── Driver/                    # 虚拟音频驱动 (AudioServerPlugIn)
│   └── VirtualAudio/
│       ├── DriverEntry.cpp    # AudioServerPlugIn 动态链接入口
│       ├── CableDevice.hpp    # 虚拟设备实例与 CoreAudio HAL 属性
│       └── RingConnector.hpp  # 虚拟输出写回虚拟输入的极速环形总线
├── Tests/                     # 单元测试与端到端自动化测试
│   ├── TestVBANParser.cpp     # 协议报头与边界测试
│   ├── TestDemuxer.cpp        # 单端口多流解复用测试
│   └── TestRingBuffer.cpp     # 无锁环形缓冲区并发测试
├── Docs/                      # 设计规范与兼容性文档
├── Scripts/                   # 驱动构建、签名与安装维护脚本
├── THIRD_PARTY_NOTICES.md     # 第三方开源协议声明
├── ARCHITECTURE.md            # 系统架构设计
└── PLAN.md                    # 阶段开发推进计划
```

---

## 3. 音频与网络数据流向

### 3.1 接收流时序 (VBAN RX)
```text
[UDP Socket 接收端口 (例如 6980)]
                ↓ (Zero-copy read)
        [VBAN Parser]  ---(校验 Magic 'VBAN' / 采样率 / 声道数 / nuFrame)
                ↓
        [Stream Demuxer] ---(按 StreamName + Source IP 分流到对应上下文)
                ↓
        [Jitter Buffer] ---(乱序纠正、时间戳重排、防止瞬时网络微抖)
                ↓
    [Audio Ring Buffer (SPSC)]
                ↓
    [CoreAudio Render Callback]
                ↓
[物理音频输出 (扬声器/耳机) 或 虚拟线缆 Input (供 OBS/DAW 录制)]
```

### 3.2 发送流时序 (VBAN TX)
```text
[物理麦克风 或 虚拟线缆 Output (如系统播放声音)]
                ↓
    [CoreAudio Input Callback]
                ↓
    [Audio Ring Buffer (SPSC)]
                ↓
        [Packetizer] ---(打上 28 字节 VBAN 报头，自动维护连续递增的 nuFrame)
                ↓
[UDP Socket 发送给目标机 (Target IP:Port)]
```

---

## 4. 虚拟音频线缆 (AudioServerPlugIn) 原理与生命周期

### 4.1 驱动通信与同步机制
1. 驱动插件 `VBANUltimateAudio.driver` 部署在 `/Library/Audio/Plug-Ins/HAL/`，由系统守护进程 `coreaudiod` 加载。
2. 守护进程中创建的线程利用 `dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE)` 监视 `/Library/Application Support/VBANUltimate/cables.plist`。
3. 当用户通过应用程序创建、重命名、修改声道数或删除虚拟线缆时，App 将配置以原子写入（write to temp + atomic rename）方式更新该文件。
4. 驱动收到目录通知后触发对齐函数：
   - 比对现有设备与配置列表。
   - 对新增配置调用 `gPlugin->AddDevice(...)`。
   - 对移除配置调用 `gPlugin->RemoveDevice(...)`。
5. 系统 CoreAudio 框架即刻向全系统广播设备增减通知，无需重启 `coreaudiod`，所有音频应用即刻可见新设备。

### 4.2 虚拟线缆音频回环 (Loopback)
- 每个虚拟线缆包含一组固定的配对流：
  - `Output Stream`：向外部 App 暴露为“输出设备”（外部 App 往里写声音）。
  - `Input Stream`：向外部 App 暴露为“输入设备”（外部 App 从中读声音）。
- 驱动内部通过纳秒时间戳对齐的环形回环缓冲 `DeviceRing`，将写入 `Output` 的音频样本直接拷贝至 `Input` 的就绪区间，延迟维持在 1 个音频周期（通常 1~2ms），实现完美的无损回环。

---

## 5. 编码规范约束 (符合 Rule 10)

1. **统一头文件**：C++ 核心统一包含 `Core/Common/Head.hpp`，外部依赖严格禁止跨模块零散包含。
2. **函数命名**：遵循英文辅音缩写规范（例如 `initproto()`, `prspkt()`, `sndpkt()`, `rcvpkt()`, `blddev()`, `syncdev()` 等），字符数严格限制在 13 个字符以内。
3. **功能注释**：函数头部一律采用一行简明功能注释（例如 `// 解析传入的VBAN网络包`），杜绝任何引申与解释性叙述。
