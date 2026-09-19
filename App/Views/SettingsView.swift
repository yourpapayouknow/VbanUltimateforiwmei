import SwiftUI

// 设置管理双列视图
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var ipCopied: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            topToolbar

            Divider().background(Theme.borderSubtle)

            HStack(spacing: 0) {
                generalSettingsColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().background(Theme.borderSubtle)

                aboutHeroColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.windowBg)
    }

    // 顶部双列操作工具栏
    private var topToolbar: some View {
        HStack(spacing: 0) {
            // 左列标题：常规设置
            HStack(spacing: 8) {
                Text(model.t("常规设置", "General Settings"))
                    .font(Theme.cnText(16.5, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .help(model.t("音频工作台界面语言、网络端口与核心驱动配置", "Configure workstation language, network port, and CoreAudio driver"))

                Spacer()

                Button(action: {
                    model.refreshHostIpAddress()
                    model.refreshAll()
                }) {
                    Text(model.t("刷新状态", "Refresh"))
                        .font(Theme.cnText(12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.neonCyan.opacity(0.18))
                        .foregroundColor(Theme.neonCyan)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.neonCyan.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(model.t("强制重新扫描 CoreAudio 硬件与网络流状态", "Force rescan CoreAudio devices and stream states"))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 右列标题：关于
            HStack(spacing: 8) {
                Text(model.t("关于", "About"))
                    .font(Theme.cnText(16.5, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .help(model.t("应用程序版本信息、底层架构规格与技术支持", "Application version, architecture specs, and technical support"))

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 40)
        .background(Theme.cardBg)
    }

    // 大节分割线
    private var sectionDivider: some View {
        Divider()
            .background(Theme.borderSubtle)
            .padding(.bottom, 14)
    }

    // 常规设置列
    private var generalSettingsColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                displayLanguageSection

                sectionDivider

                networkTransmissionSection

                sectionDivider

                virtualDriverSection

                sectionDivider

                telemetrySection
            }
            .padding(18)
        }
    }

    @Namespace private var settingsSwitcherAnimation

    // 界面显示语言与外观样式设置
    private var displayLanguageSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.t("界面与显示", "Interface & Display"))
                .font(Theme.cnText(12.5, weight: .bold))
                .foregroundColor(Theme.neonCyan)
                .padding(.bottom, 8)

            // 语言设置行
            HStack(spacing: 16) {
                Text(model.t("语言", "Language"))
                    .font(Theme.cnText(13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                HStack(spacing: 0) {
                    ForEach(AppLanguage.allCases) { lang in
                        slidingCapsuleItem(
                            title: lang.displayName,
                            isSelected: model.language == lang,
                            matchedId: "langHighlight"
                        ) {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                model.language = lang
                            }
                        }
                    }
                }
                .padding(2)
                .background(Theme.capsuleBg)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.borderSubtle, lineWidth: 1)
                )
                .help(model.t("切换应用程序界面显示语言", "Switch application display language"))
            }
            .frame(height: 40)

            Divider().background(Theme.borderSubtle)

            // 样式设置行
            HStack(spacing: 16) {
                Text(model.t("样式", "Appearance"))
                    .font(Theme.cnText(13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                HStack(spacing: 0) {
                    ForEach(AppThemeStyle.allCases) { style in
                        slidingCapsuleItem(
                            title: style.title(for: model.language),
                            isSelected: model.themeStyle == style,
                            matchedId: "themeHighlight"
                        ) {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                model.themeStyle = style
                            }
                        }
                    }
                }
                .padding(2)
                .background(Theme.capsuleBg)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.borderSubtle, lineWidth: 1)
                )
                .help(model.t("切换应用程序外观样式（深色、浅色、跟随系统）", "Switch appearance mode (Dark, Light, System)"))
            }
            .frame(height: 40)
        }
    }

    // 滑块切换单元
    private func slidingCapsuleItem(title: String, isSelected: Bool, matchedId: String, itemWidth: CGFloat = 68, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.neonCyan.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.neonCyan.opacity(0.45), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: matchedId, in: settingsSwitcherAnimation)
                }

                Text(title)
                    .font(Theme.cnText(11.5, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Theme.neonCyan : Theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: itemWidth, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // 网络通信与传输参数
    private var networkTransmissionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.t("网络与传输参数", "Network & Transmission"))
                .font(Theme.cnText(12.5, weight: .bold))
                .foregroundColor(Theme.neonCyan)
                .padding(.bottom, 8)

            // 主机网络地址行
            HStack(spacing: 16) {
                Text(model.t("主机网络地址", "IP Host Address"))
                    .font(Theme.cnText(13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                HStack(spacing: 8) {
                    Text(model.hostIpAddress.isEmpty ? "127.0.0.1" : model.hostIpAddress)
                        .font(Theme.monoDigit(13, weight: .bold))
                        .foregroundColor(Theme.neonCyan)

                    Button(action: {
                        model.copyHostIp()
                        ipCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            ipCopied = false
                        }
                    }) {
                        Text(ipCopied ? model.t("已复制", "Copied") : model.t("复制", "Copy"))
                            .font(Theme.cnText(10.5, weight: .semibold))
                            .frame(width: 48, height: 20)
                            .background(ipCopied ? Theme.meterGreen.opacity(0.2) : Theme.btnBg)
                            .foregroundColor(ipCopied ? Theme.meterGreen : Theme.neonCyan)
                            .cornerRadius(3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(ipCopied ? Theme.meterGreen.opacity(0.85) : Theme.neonCyan.opacity(0.85), lineWidth: 1.2)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(model.t("复制本机网络地址到剪贴板，方便在对端发送设备中填入", "Copy host IP to clipboard for configuring remote transmitter"))
                }
            }
            .frame(height: 40)
            .help(model.t("本机局域网通信地址。当远端设备向本机发送音频流时，须在对端输入此地址。点击可复制至剪贴板。", "Local host IP address on your LAN. When remote devices send audio to this machine, enter this IP on the transmitter. Click to copy."))

            Divider().background(Theme.borderSubtle)

            // 监听端口行
            HStack(spacing: 16) {
                Text(model.t("网络监听端口", "VBAN Port"))
                    .font(Theme.cnText(13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                TextField("", text: $model.udpPort, onCommit: {
                    model.retryBindPort()
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(Theme.monoDigit(12, weight: .semibold))
                .multilineTextAlignment(.center)
                .frame(width: 120, height: 24)
            }
            .frame(height: 40)
            .help(model.t("网络监听端口，官方标准为6980。同一网络或同一机器存在多个实例时可自定义端口实现隔离。修改后按回车重新绑定。", "Official standard VBAN UDP port is 6980. Change this to isolate multiple instances on the same host or network. Press Enter to rebind."))

            Divider().background(Theme.borderSubtle)

            // 用户节点名称行
            HStack(spacing: 16) {
                Text(model.t("用户节点标识", "Username"))
                    .font(Theme.cnText(13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                TextField("", text: $model.username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(Theme.monoDigit(12, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(width: 120, height: 24)
            }
            .frame(height: 40)
            .help(model.t("用户节点名称与电台呼号标识，最大长度十六字符。发送流默认使用此标识，方便对端设备识别通信来源。", "Station username and node identifier (max 16 characters). Transmitted streams use this label by default so remote receivers recognize this node."))

            Divider().background(Theme.borderSubtle)

            // 网络质量策略行
            HStack(spacing: 16) {
                Text(model.t("网络传输质量", "Network Quality"))
                    .font(Theme.cnText(13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Picker("", selection: $model.networkQuality) {
                    ForEach(VbanNetworkQuality.allCases) { q in
                        Text(q.title(for: model.language)).tag(q)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
            .frame(height: 40)
            .help(model.t("网络传输质量预设：\(model.networkQuality.desc(for: model.language))。动态调整抗抖动平滑缓冲深度，避免网络丢包产生爆音。", "Network transmission quality preset: \(model.networkQuality.desc(for: model.language)). Dynamically adjusts jitter buffer depth to prevent underruns."))

            Divider().background(Theme.borderSubtle)

            // 音频缓冲大小行
            HStack(spacing: 16) {
                Text(model.t("音频缓冲大小", "Buffering"))
                    .font(Theme.cnText(13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Picker("", selection: $model.bufferingFrames) {
                    ForEach(model.availableBuffering, id: \.self) { bf in
                        Text(model.language == .chinese ? "\(bf) 采样" : "\(bf) samples").tag(bf)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
            .frame(height: 40)
            .help(model.t("音频缓冲调度大小：\(model.bufferingDesc(model.bufferingFrames))。包含标称十毫秒封包帧长与低延迟音频调度块大小。", "Audio buffer scheduling size: \(model.bufferingDesc(model.bufferingFrames)). Covers nominal 10ms packet frames and low-latency audio blocks."))
        }
    }

    // 虚拟音频驱动管理
    private var virtualDriverSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.t("虚拟音频驱动", "Virtual Audio Driver"))
                .font(Theme.cnText(12.5, weight: .bold))
                .foregroundColor(Theme.neonCyan)
                .padding(.bottom, 8)

            HStack(spacing: 12) {
                StatusLed(isActive: model.metrics.driverInstalled)

                Text(model.metrics.driverInstalled ? model.t("驱动已部署并正常就绪", "Driver installed & ready in CoreAudio") : model.t("驱动尚未部署至系统 HAL 目录", "Driver not deployed in system HAL"))
                    .font(Theme.cnText(13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .help(model.t("驱动路径: /Library/Audio/Plug-Ins/HAL/VBANUltimateAudio.driver。支持原子目录监听，增删线缆无需重启 coreaudiod。", "Path: /Library/Audio/Plug-Ins/HAL/VBANUltimateAudio.driver. Supports atomic directory watching with zero coreaudiod restarts."))

                Spacer()

                Button(action: {
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                    p.arguments = ["-lc", "Scripts/install_driver.zsh"]
                    try? p.run()
                    p.waitUntilExit()
                    model.refreshAll()
                }) {
                    Text(model.metrics.driverInstalled ? model.t("重新安装驱动", "Reinstall Driver") : model.t("安装虚拟驱动", "Install Driver"))
                        .font(Theme.cnText(11.5, weight: .semibold))
                        .frame(width: 106, height: 22)
                        .background(Theme.neonCyan.opacity(0.18))
                        .foregroundColor(Theme.neonCyan)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.neonCyan.opacity(0.85), lineWidth: 1.2)
                        )
                }
                .buttonStyle(.plain)
                .help(model.t("部署 AudioServerPlugIn 驱动至 macOS 系统 HAL 目录（需要管理员权限）", "Deploy AudioServerPlugIn driver into system HAL directory (requires admin)"))
            }
            .frame(height: 40)
        }
    }

    // 系统运行遥测状态
    private var telemetrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.t("系统运行状态", "System Status"))
                .font(Theme.cnText(12.5, weight: .bold))
                .foregroundColor(Theme.neonCyan)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    telemetryCard(
                        title: model.t("接收活跃流", "Active Rx"),
                        value: "\(model.metrics.activeRx)",
                        color: Theme.meterGreen,
                        helpText: model.t("当前在线接收的网络音频流数量", "Number of active incoming streams")
                    )
                    telemetryCard(
                        title: model.t("发送活跃流", "Active Tx"),
                        value: "\(model.metrics.activeTx)",
                        color: Theme.amberWarn,
                        helpText: model.t("当前向外发送的网络音频流数量", "Number of active outgoing streams")
                    )
                }

                HStack(spacing: 8) {
                    telemetryCard(
                        title: model.t("虚拟音频线缆", "Virtual Cables"),
                        value: "\(model.cables.count)",
                        color: Theme.neonCyan,
                        helpText: model.t("系统 CoreAudio HAL 中已注册的虚拟线缆数量", "Registered virtual cables in CoreAudio HAL")
                    )
                    telemetryCard(
                        title: model.t("累计丢包数", "Packet Loss"),
                        value: "\(model.metrics.totalLost)",
                        color: model.metrics.totalLost > 0 ? Theme.alertRed : Theme.meterGreen,
                        helpText: model.t("自应用启动以来的所有流 UDP 丢包总数", "Total UDP packet loss count across all streams")
                    )
                }

                telemetryCard(
                    title: model.t("音频调度核心", "Audio Engine"),
                    value: model.isAudioRunning ? model.t("已就绪", "Ready") : model.t("已暂停", "Paused"),
                    color: model.isAudioRunning ? Theme.meterGreen : Theme.alertRed,
                    helpText: model.t("底层 CoreAudio AUHAL 实时音频引擎调度状态", "CoreAudio AUHAL real-time audio engine state")
                )
            }
        }
    }

    // 遥测指标小单元格
    private func telemetryCard(title: String, value: String, color: Color, helpText: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.cnText(11.5, weight: .semibold))
                .foregroundColor(Theme.textTertiary)

            Text(value)
                .font(Theme.monoDigit(16, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBg)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Theme.borderSubtle, lineWidth: 1)
        )
        .help(helpText)
    }

    // 关于信息高级展示列
    private var aboutHeroColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                identityView

                sloganView

                Divider().background(Theme.borderSubtle)

                systemToolsSection

                Divider().background(Theme.borderSubtle)

                creditsSection

                Divider().background(Theme.borderSubtle)

                copyrightAndLinksSection
            }
            .padding(20)
        }
    }

    // 应用标识与版本
    private var identityView: some View {
        HStack(spacing: 16) {
            if let icon = loadBundleImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.neonCyan.opacity(0.45), lineWidth: 1.2)
                    )
                    .shadow(color: Theme.neonCyan.opacity(0.22), radius: 8, x: 0, y: 2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("VBAN Ultimate")
                    .font(Theme.cnText(19, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                HStack(spacing: 6) {
                    ParamCapsule(text: "v1.0.0", color: Theme.neonCyan)
                    ParamCapsule(text: "arm64", color: Theme.textSecondary)
                    ParamCapsule(text: "macOS 13+", color: Theme.textTertiary)
                }
            }
        }
    }

    // 产品一句话定位
    private var sloganView: some View {
        Text(model.t(
            "广播级 VBAN 局域网音频传输与 CoreAudio 虚拟线缆管理工作台",
            "Broadcast VBAN network audio stream management & CoreAudio virtual cable workstation."
        ))
        .font(Theme.cnText(12, weight: .medium))
        .foregroundColor(Theme.textSecondary)
        .lineSpacing(3)
    }

    // 系统音频工具与快捷入口
    private var systemToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.t("系统音频工具与路径", "System Audio Tools & Paths"))
                .font(Theme.cnText(12, weight: .bold))
                .foregroundColor(Theme.neonCyan)

            HStack(spacing: 8) {
                toolButton(
                    title: model.t("音频与MIDI设置", "Audio MIDI Setup"),
                    helpText: model.t("打开 macOS 原生“音频与MIDI设置”检查声卡参数", "Open native macOS Audio MIDI Setup to inspect audio devices"),
                    action: {
                        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Audio MIDI Setup.app")
                        NSWorkspace.shared.open(url)
                    }
                )

                toolButton(
                    title: model.t("驱动安装目录", "HAL Driver Path"),
                    helpText: model.t("在 Finder 中定位 CoreAudio HAL 插件驱动目录", "Reveal CoreAudio HAL plug-ins directory in Finder"),
                    action: {
                        let url = URL(fileURLWithPath: "/Library/Audio/Plug-Ins/HAL")
                        NSWorkspace.shared.open(url)
                    }
                )

                toolButton(
                    title: model.t("配置共享目录", "Config Path"),
                    helpText: model.t("在 Finder 中定位虚拟音频线缆共享配置文件目录", "Reveal VBANUltimate shared configuration folder in Finder"),
                    action: {
                        let url = URL(fileURLWithPath: "/Library/Application Support/VBANUltimate")
                        NSWorkspace.shared.open(url)
                    }
                )
            }
        }
    }

    // 系统工具按钮
    private func toolButton(title: String, helpText: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.cnText(11.5, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.cardBg)
                .foregroundColor(Theme.textPrimary)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Theme.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    // 开源鸣谢与致敬
    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.t("开源鸣谢与参考", "Credits & Acknowledgments"))
                .font(Theme.cnText(12, weight: .bold))
                .foregroundColor(Theme.neonCyan)

            VStack(spacing: 7) {
                creditRow(
                    name: "VB-Audio Software",
                    author: "Vincent Burel",
                    desc: model.t("VBAN 网络音频通信协议官方发明者与标准规范制定", "Official VBAN audio protocol creator & standards authority"),
                    urlString: "https://vb-audio.com/"
                )

                creditRow(
                    name: "BlackHole",
                    author: "Devin Roth (Existential Audio)",
                    desc: model.t("macOS 虚拟音频回环驱动架构与 CoreAudio HAL 属性规范实践", "macOS virtual audio loopback driver & CoreAudio HAL reference"),
                    urlString: "https://github.com/ExistentialAudio/BlackHole"
                )

                creditRow(
                    name: "libASPL",
                    author: "Alexander Gavrilov (gavv)",
                    desc: model.t("现代 C++ CoreAudio AudioServerPlugIn 驱动面向对象框架", "Modern C++ AudioServerPlugIn framework for macOS"),
                    urlString: "https://github.com/gavv/aspl"
                )

                creditRow(
                    name: "vban",
                    author: "Benoit Quiniou (quiniouben)",
                    desc: model.t("VBAN 官方通信协议开源 C 语言参考实现", "C reference implementation of VBAN audio protocol"),
                    urlString: "https://github.com/quiniouben/vban"
                )

                creditRow(
                    name: "Splitwave",
                    author: "Horuse",
                    desc: model.t("基于目录监听的动态虚拟设备无感重载机制参考", "Dynamic device reload mechanism via directory watching"),
                    urlString: "https://github.com/Horuse/Splitwave"
                )
            }
        }
    }

    // 鸣谢列表行
    private func creditRow(name: String, author: String, desc: String, urlString: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 6) {
                Text(name)
                    .font(Theme.monoDigit(12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text("• \(author)")
                    .font(Theme.cnText(11.5, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
            }

            Spacer()

            Button(action: {
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text(model.t("访问", "Visit"))
                    .font(Theme.cnText(10.5, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Theme.btnBg)
                    .foregroundColor(Theme.neonCyan)
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Theme.neonCyan.opacity(0.85), lineWidth: 1.2)
                    )
            }
            .buttonStyle(.plain)
            .help(urlString)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.cardBg)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.borderSubtle, lineWidth: 1)
        )
        .help("\(name) • \(author)\n\(desc)")
    }

    // 版权与外链支持
    private var copyrightAndLinksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("© 2026 iwmei. All rights reserved.")
                .font(Theme.cnText(11.5, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .help(model.t(
                    "遵循 VBAN 协议开源准则与 Apple CoreAudio HAL 驱动规范",
                    "Compliant with VBAN protocol specifications and Apple CoreAudio HAL standards."
                ))

            HStack(spacing: 8) {
                linkButton(title: model.t("技术文档", "Docs"), urlString: "https://github.com/yourpapayouknow/VbanUltimateforiwmei#readme")
                linkButton(title: model.t("开源仓库", "GitHub"), urlString: "https://github.com/yourpapayouknow/VbanUltimateforiwmei")
                linkButton(title: model.t("反馈支持", "Feedback"), urlString: "https://github.com/yourpapayouknow/VbanUltimateforiwmei/issues")
            }
            .padding(.top, 2)
        }
    }

    // 外部链接按钮
    private func linkButton(title: String, urlString: String) -> some View {
        Button(action: {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }) {
            Text(title)
                .font(Theme.cnText(11, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Theme.btnBg)
                .foregroundColor(Theme.neonCyan)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Theme.neonCyan.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // 本地图片资源加载
    private func loadBundleImage(named: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: named, withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return NSImage(contentsOfFile: "Resources/\(named).png")
    }
}
