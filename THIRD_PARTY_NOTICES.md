# Third-Party Notices & Licenses

本项目在设计与开发过程中参考并借鉴了以下优秀的开源项目与公开协议规范。特此致谢并列明其相关许可信息：

---

## 1. VBAN (VB-Audio Network Protocol)
- **原创所有者**：Vincent Burel / VB-Audio Software
- **官方主页**：https://vb-audio.com/Voicemeeter/vban.htm
- **开源参考**：`quiniouben/vban` (GNU General Public License v3.0)
- **使用范围**：参考官方公开规范与数据报头定义，自主实现符合 VBAN 协议规范的 C++ 协议解析器与网络数据流封装，未直接拷贝旧库代码。

---

## 2. libASPL (AudioServerPlugIn C++ Framework)
- **作者**：Vladislav Gorlov (gavv)
- **仓库地址**：https://github.com/gavv/libASPL
- **许可证**：Apache License 2.0 / MIT License
- **使用范围**：作为虚拟音频驱动 `VBANUltimateAudio.driver` 的 CoreAudio HAL AudioServerPlugIn 协议封装库。

---

## 3. Splitwave
- **作者**：Horuse
- **仓库地址**：https://github.com/Horuse/Splitwave
- **许可证**：GNU General Public License v3.0
- **使用范围**：参考其基于 CoreFoundation / dispatch_source_vnode 监听的动态虚拟设备增删机制与设备生命周期同步设计思路。

---

## 4. BlackHole
- **作者**：Existential Audio Inc.
- **仓库地址**：https://github.com/ExistentialAudio/BlackHole
- **许可证**：GNU General Public License v3.0
- **使用范围**：参考其无锁音频环形缓冲区机制及 CoreAudio HAL 虚拟设备属性返回值规范。
