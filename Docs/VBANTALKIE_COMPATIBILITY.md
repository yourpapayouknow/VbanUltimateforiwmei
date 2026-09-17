# VBAN Talkie / Receptor 兼容性与指标对照表 (VBANTALKIE_COMPATIBILITY.md)

本文档详尽对照 VB-Audio VBAN Talkie (macOS Cherry 版) 及 Voicemeeter VBAN Receptor/Emitter 的所有状态、指标、配置及行为，确保本项目在功能与监控深度上实现完整对齐与超越。

---

## 1. 核心功能与指标对照矩阵

| 分类 | VBAN Talkie / Receptor 指标与功能 | 本项目 (VBAN Ultimate) 对应实现 | 状态 | 优势与增强说明 |
| :--- | :--- | :--- | :--- | :--- |
| **流基础配置** | Stream Name (单条流设定) | 多条独立流（每个 RX/TX 可独立设置 Stream Name） | 计划支持 (M1) | 支持多流并发，彻底突破 Talkie 仅单流限制 |
| **流网络方向** | 固定接收或单向对讲 | 完整双向多流矩阵（RX 多流 + TX 多流同时并发） | 计划支持 (M1) | 真正的全双工多通道网络矩阵 |
| **远端网络寻址** | IP Address / Target IP | 每条流独立 Source IP 绑定与 Destination IP 指定 | 计划支持 (M1) | 支持多对多，单 IP 多流复用同一 UDP 端口 |
| **网络端口** | 默认 UDP 6980 (仅单端口) | 默认 6980，支持全局单端口多流分流，支持自定义端口 | 计划支持 (M1) | 单一 UDP Socket 高效分流，极低系统开销 |
| **采样率解析** | 11025 ~ 96000 Hz 识别 | 完整支持 6000 ~ 705600 Hz 官方 21 种标准采样率 | 计划支持 (M1) | 严格遵循 VBAN 协议规范，自动识别并重采样/对齐 |
| **声道支持** | Mono / Stereo | 1 ~ 256 声道动态解析（首期原生 1~2 声道，保留扩展能力） | 计划支持 (M1) | 结构体无缝支持任意多声道 |
| **采样格式** | 16-bit / 24-bit PCM | 8/16/24/32-bit 整型 PCM 及 32-bit IEEE 浮点 | 计划支持 (M1) | 自动统一转换为 32-bit Float 进行内部 CoreAudio 交换 |
| **包计数器** | Packet Counter 递增显示 | 64 位累计接收/发送包数，nuFrame 连续性严格追踪 | 计划支持 (M1) | 防止 32 位计数器溢出引起的抖动统计异常 |
| **实时吞吐率** | 未显式精确显示 | Packets/s 瞬时统计、Payload Bitrate (kbps) 精准计算 | 计划支持 (M1) | 毫秒级滑动窗口计算实时速率 |
| **丢包与异常** | Packet Error (红绿灯状态) | 精确统计：Lost Packets、Duplicate、Out-of-order | 计划支持 (M1) | 详细分类错误原因，而非仅给模糊红灯 |
| **网络抖动** | Net Quality 档位 (Fast~Very Slow) | 实时微秒级 Jitter 统计 + 可配置自适应 Jitter Buffer | 计划支持 (M2) | 动态抵消网络时延抖动，平衡低延迟与稳定性 |
| **缓冲健康度** | Underrun 告警灯 | Buffer Fill Level (%)、Underrun/Overrun 计数器 | 计划支持 (M2) | 图形化百分比仪表盘展示缓冲水位 |
| **流连接状态** | ON / OFF / 连接闪烁 | Active / Standby / Offline / Muted 明确状态机 | 计划支持 (M1) | 支持流超时检测（3秒无包自动标记 Offline）与瞬间自愈 |
| **运行健康时长** | 无详细统计 | Stream Uptime、Last Packet Timestamp 纳秒追踪 | 计划支持 (M1) | 方便长时间无人值守稳定性诊断 |
| **音频输出设备** | 仅限 Mac 物理输出 | 任意 CoreAudio 物理输出 或 动态虚拟音频线缆 | 计划支持 (M3-M5)| 独创可直接输出到虚拟线缆供给 OBS/DAW 捕获 |
| **音频输入设备** | 仅限 Mac 物理麦克风 | 任意 CoreAudio 物理输入 或 虚拟线缆回环捕获 | 计划支持 (M3-M5)| 独创任意系统音频/应用输出转 VBAN 发送 |
| **对讲/静音** | PTT 按钮、Mute 切换 | 每路流独立 Mute / Solo 控制，PTT 键盘快捷触发 | 计划支持 (M6) | 既可做专业矩阵路由，亦可完整覆盖 Talkie 对讲需求 |

---

## 2. 诊断与高级指标分类 (Diagnostics / Advanced)

为避免主界面过度杂乱，UI 遵循原生简洁风格，将详细诊断数据分配如下：

### 主界面 (Overview / Streams)
- 流名称与方向标识
- 状态指示灯（绿色 Active、黄色 Jittering、灰色 Offline、红色 Error）
- IP:Port 及格式简写（例如：`192.168.1.50:6980 | 48kHz 24b 2ch`）
- 吞吐速率（例如：`1.54 Mbps | 187.5 pkt/s`）
- 简短质量状态（丢包率百分比、Jitter 级别）

### 诊断面板 (Monitoring / Diagnostics)
- 详细错误分类：Lost（丢包）、Duplicate（重复包）、Out-of-Order（乱序包）
- 真实 Jitter（ms）与 Jitter Buffer 水位（当前占满率 / 目标水位）
- Underrun / Overrun 累计触发次数
- 网络物理往返与传输间隔分布直方图
- 最近收到的一包时间差（用于判定网络瞬断）
