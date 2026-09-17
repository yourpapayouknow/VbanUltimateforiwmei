---
title: VBAN Ultimate Design System
version: 1.0.0
platform: macOS
framework: SwiftUI
theme: Dark Professional Audio
---

# VBAN Ultimate 前端设计系统规范 (DESIGN.md)

本文档制定 VBAN Ultimate macOS 原生客户端界面的设计语言、排版梯度、色彩语义与组件规范。

---

## 1. Overview (视觉与设计理念)
- **定位理念**：遵循 macOS 原生人机交互指南 (HIG)，打造媲美 Loopback / Dante Controller 的专业级原生音频基础设施桌面应用。
- **界面语言**：全界面原生中文（专业广电与音频工程术语）。
- **去网页化与专业质感**：彻底摒弃 Web 端卡片堆叠与松散留白，采用 macOS 统一标题栏（Unified Toolbar）、原生分段控制器（Segmented Control）、密集型原生数据表格与交叉矩阵。
- **信息架构收敛**：
  - 核心标签保留：`音频流 (Streams)` | `路由矩阵 (Matrix)` | `虚拟线缆 (Cables)` | `监控诊断 (Monitoring)` | `设置与概览 (Settings)`
  - 原独立“概览”收归至“设置与概览”模块作为系统仪表盘，突出核心音频流收发与矩阵操作。

---

## 2. Colors (色彩体系与语义色)
- **基底底色**：
  - Window Background: `NSColor.windowBackgroundColor` / `#16161A` (深度音频工作台底色)
  - Surface Background: `NSColor.controlBackgroundColor` / `#202026` (控制板底色)
  - Table Alternate Row: `rgba(255, 255, 255, 0.02)` (交替行斑马纹)
- **品牌与强调色**：
  - Primary Accent: `#00F2FE` (霓虹青，用于激活状态、选中的Tab与连线)
  - Meter Green: `#10B981` (标准音频电平绿)
  - Amber Warning: `#F59E0B` (警告与 Jitter 预警黄)
  - Critical Red: `#EF4444` (丢包、离线与报错红)
  - Muted Gray: `#71717A` (次级文本与未激活端点)

---

## 3. Typography (排版与字体规范)
- **字体族阶梯**：
  - 标题与中文标签：系统原生中文字体（PingFang SC / SF Pro），中等字重。
  - 音频技术参数（采样率、声道、IP、端口、时间戳、吞吐率、帧数）：统一使用系统等宽字体 `SF Mono` 并配置 `.monospacedDigit()`，严防数据刷新时横向抖动。
- **字号阶梯**：
  - Toolbar Title: `13pt`, Bold
  - Section Header: `12pt`, Semibold, Muted
  - Table Cell Text: `12pt`, Regular
  - Metric Value: `12pt`, Monospaced Medium
  - Subtitle / Description: `11pt`, Muted

---

## 4. Layout (界面布局与导航骨架)
- **窗口骨架**：
  - 采用 macOS 原生统一工具栏（Unified Window Toolbar），使用原生 `Picker.pickerStyle(.segmented)` 置于顶部工具栏中心（Placement: `.principal`），彻底去除网页式自定义 TabBar。
  - 窗口右上角常驻 CoreAudio 引擎工作状态（在线/离线）与即时启停控制。
- **主工作区排版**：
  - 单页面紧凑工作台，充满视窗，横向与纵向自适应伸缩，最大化保留交叉矩阵与多流监控可视区域。
- **窗口尺寸规范**：
  - 默认窗口尺寸：`920 x 600 pt`
  - 最小窗口尺寸：`820 x 500 pt`

---

## 5. Elevation & Depth (层级深度与投影材质)
- **背景材质**：深色磨砂亚克力材质（`NSVisualEffectView` Ultra-thin Material）。
- **去卡片化微质感**：
  - 不使用多层厚重封闭色块卡片。
  - 区域划分使用超细微透明分隔线：`rgba(255, 255, 255, 0.08)`。
  - 激活流与高亮组件带有轻微霓虹青光晕阴影：`radius: 8, color: rgba(0, 242, 254, 0.15)`。

---

## 6. Shapes (几何形状与圆角规范)
- **轮廓标准**：采用 Apple Squircle（连续平滑圆角）。
- **圆角梯度**：
  - 弹窗与主面板：`10pt ~ 12pt`
  - 交互按钮与微胶囊状态灯：`6pt ~ 8pt`
  - 纯圆状态指示微指示灯：`100% (Circle)`

---

## 7. Components (去卡片化组件与交互库)
- **去卡片化流列表（Borderless Fluid Stream List）**：
  - 弃用厚实卡片，采用轻盈通透的行级排版。
  - 单行展现：流名称、状态小绿灯、IP:Port微胶囊、采样率与声道、实时速率、控制开关。
- **微胶囊指示器（Micro Capsule Badge）**：
  - 高度 `20pt`，背景 `rgba(255,255,255,0.06)`，字号 `11pt` 等宽数字。
- **矩阵交叉连接盘（Matrix Grid Cross-points）**：
  - 横轴源端点（物理麦克风、虚拟线缆输出、VBAN RX），纵轴目标端点（扬声器、虚拟线缆输入、VBAN TX）。
  - 连接点具备点击即连/断与平滑增益推子调节。
- **虚拟线缆快速管理器（Cable Row Manager）**：
  - 行内即时编辑名称、声道（1ch/2ch）、采样率（44.1k/48k/96k），一键移除与重启测试。

---

## 8. Do's and Don'ts (设计与交互红线准则)
- **Do's (必须遵守)**：
  1. 必须使用 `.monospacedDigit()` 渲染所有动态计数与速率指标，杜绝界面文字横向抖动跳动。
  2. UI 状态刷新定时器必须节流在 `500ms ~ 1000ms`，且必须派发在主线程，绝对禁止阻塞实时音频工作线程。
  3. 异常与离线必须有直观视觉反馈（红色故障灯或明确 Offline 标签），严禁“后台已断开但 UI 显示仍正常”。
  4. 支持 macOS 原生快捷键（如 `Cmd+1~6` 切换视图、`Cmd+R` 重新载入设备）。
- **Don'ts (严格禁止)**：
  1. 严禁使用 Windows Voicemeeter 风格的多层沉重反光拟物与杂乱色彩堆砌。
  2. 严禁厚重多层封闭卡片嵌套，坚持去卡片化的通透现代排版。
  3. 严禁引入与音频基础设施无关的复杂节点连线编辑器或 DAW 编曲特效。
