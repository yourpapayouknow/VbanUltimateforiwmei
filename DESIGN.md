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
- **定位理念**：遵循 macOS 原生人机交互指南 (HIG)，打造现代轻量级专业网络音频基础设施工具。
- **视觉风格**：深色暗调专业工具风格，去卡片化流动排版，专注音频流传输与虚拟线缆状态的直观呈现。
- **信息密度**：兼顾专业工程师的高密度监控需求与高品质视觉美感，拒绝冗余装饰。

---

## 2. Colors (色彩体系与语义色)
- **基底底色**：
  - Window Background: `#121214` (深黑磨砂底色)
  - Surface Background: `#1E1E24` (微深灰面板底色)
  - Elevated Popover: `#25252C` (浮层悬浮底色)
- **品牌与强调色**：
  - Primary Accent: `#00F2FE` (霓虹青，用于激活状态、选中的Tab与主连线)
  - Secondary Accent: `#FFB300` (琥珀金，用于重要提示与特殊参数指示)
- **状态语义色**：
  - Active / Connected: `#10B981` (明快翡翠绿)
  - Jitter / Warning: `#F59E0B` (预警琥珀黄)
  - Error / Offline: `#EF4444` (告警珊瑚红)
  - Disabled / Muted: `#6B7280` (中性低对比度冷灰)

---

## 3. Typography (排版与字体规范)
- **字体族阶梯**：
  - 主体标题与界面标签：`SF Pro` (System Font)
  - 音频参数、采样率、IP、端口与统计指标：`SF Mono` / `.monospacedDigit()`
- **字阶与字重**：
  - Page Title: `20pt`, Bold, Tracking: `-0.2pt`
  - Section Header: `14pt`, Semibold, Secondary Color
  - Body Text: `13pt`, Regular
  - Metric Digits: `13pt`, Monospaced, Medium (杜绝高频数值变动时产生横向抖动)
  - Footnote / Caption: `11pt`, Regular, Muted

---

## 4. Layout (界面布局与导航骨架)
- **导航结构**：顶部多标签页集成导航（Top Segmented Navigation），布局类似 Xcode / Safari 工具栏。
  - 核心标签：`Overview` | `Streams` | `Matrix` | `Virtual Cables` | `Monitoring` | `Settings`
- **主视窗排版**：最大化单页面展示，去侧边栏侵占，充分利用水平视宽呈现音频路由与多流并发矩阵。
- **窗口尺寸规范**：
  - 默认窗口尺寸：`960 x 640 pt`
  - 最小窗口尺寸：`800 x 520 pt`

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
