import SwiftUI

// 设置管理视图
struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            topToolbar

            Divider().background(Theme.borderSubtle)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    systemStatusSection

                    Divider().background(Theme.borderSubtle)

                    interfaceAndNetworkSection

                    Divider().background(Theme.borderSubtle)

                    virtualDriverSection

                    Divider().background(Theme.borderSubtle)

                    aboutSection
                }
                .padding(20)
            }
        }
        .background(Theme.windowBg)
    }

    // 顶部操作工具栏
    private var topToolbar: some View {
        HStack(spacing: 8) {
            Text(model.t("设置", "Settings"))
                .font(Theme.cnText(14, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .help(model.t("系统运行状态遥测与全局通信配置", "System telemetry and global communication settings"))

            Spacer()

            Button(action: {
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
        .frame(height: 40)
        .background(Color.white.opacity(0.03))
    }

    // 系统状态全宽指标栏
    private var systemStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.t("系统运行状态", "System Status"))
                .font(Theme.cnText(12.5, weight: .bold))
                .foregroundColor(Theme.neonCyan)

            HStack(spacing: 12) {
                metricCell(
                    title: model.t("接收活跃流", "Active Rx"),
                    value: "\(model.metrics.activeRx)",
                    color: Theme.meterGreen,
                    helpText: model.t("当前在线接收的网络音频流数量", "Number of active incoming streams")
                )
                metricCell(
                    title: model.t("发送活跃流", "Active Tx"),
                    value: "\(model.metrics.activeTx)",
                    color: Theme.amberWarn,
                    helpText: model.t("当前向外发送的网络音频流数量", "Number of active outgoing streams")
                )
                metricCell(
                    title: model.t("虚拟音频线缆", "Virtual Cables"),
                    value: "\(model.cables.count)",
                    color: Theme.neonCyan,
                    helpText: model.t("系统 CoreAudio HAL 中已注册的虚拟线缆数量", "Registered virtual cables in CoreAudio HAL")
                )
                metricCell(
                    title: model.t("累计丢包数", "Packet Loss"),
                    value: "\(model.metrics.totalLost)",
                    color: model.metrics.totalLost > 0 ? Theme.alertRed : Theme.meterGreen,
                    helpText: model.t("自应用启动以来的所有流 UDP 丢包总数", "Total UDP packet loss count across all streams")
                )
                metricCell(
                    title: model.t("音频调度核心", "Audio Engine"),
                    value: model.isAudioRunning ? model.t("已就绪", "Ready") : model.t("已暂停", "Paused"),
                    color: model.isAudioRunning ? Theme.meterGreen : Theme.alertRed,
                    helpText: model.t("底层 CoreAudio AUHAL 实时音频引擎调度状态", "CoreAudio AUHAL real-time audio engine state")
                )
            }
        }
    }

    // 状态指标单元格
    private func metricCell(title: String, value: String, color: Color, helpText: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.cnText(11.5, weight: .semibold))
                .foregroundColor(Theme.textTertiary)

            Text(value)
                .font(Theme.monoDigit(18, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.02))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Theme.borderSubtle, lineWidth: 1)
        )
        .help(helpText)
    }

    // 界面与通信配置
    private var interfaceAndNetworkSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.t("界面与通信", "Interface & Network"))
                .font(Theme.cnText(12.5, weight: .bold))
                .foregroundColor(Theme.neonCyan)

            HStack(spacing: 16) {
                Text(model.t("界面显示语言", "Display Language"))
                    .font(Theme.cnText(13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Picker("", selection: $model.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .help(model.t("切换应用程序界面显示语言", "Switch application display language"))
            }

            Divider().background(Color.white.opacity(0.04))

            HStack(spacing: 16) {
                Text(model.t("默认 UDP 监听端口", "Default UDP Port"))
                    .font(Theme.cnText(13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                TextField("", text: $model.udpPort)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(Theme.monoDigit(12.5, weight: .semibold))
                    .frame(width: 85)
                    .help(model.t("VBAN 官方标准网络监听端口为 6980。底层单套接字根据流名自动解复用。", "Official standard VBAN UDP port is 6980. Single socket automatically demuxes incoming streams by stream name."))
            }
        }
    }

    // 虚拟音频驱动管理
    private var virtualDriverSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.t("虚拟音频驱动", "Virtual Audio Driver"))
                .font(Theme.cnText(12.5, weight: .bold))
                .foregroundColor(Theme.neonCyan)

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
                .help(model.t("部署 AudioServerPlugIn 驱动至 macOS 系统 HAL 目录（需要管理员权限）", "Deploy AudioServerPlugIn driver into system HAL directory (requires admin)"))
            }
        }
    }

    // 关于信息
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.t("关于", "About"))
                .font(Theme.cnText(12.5, weight: .bold))
                .foregroundColor(Theme.textTertiary)

            Text("VBAN Ultimate for macOS • Apple Silicon (arm64)")
                .font(Theme.cnText(13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .help(model.t("底层采用 C++20 实时安全（RT-Safe）无锁 SPSC 环形缓冲、单 Socket 多流高效解复用与自适应 Jitter 缓冲架构。", "Built with C++20 RT-safe lock-free SPSC circular buffers, single-socket multi-stream demuxing, and adaptive jitter buffer architecture."))
        }
    }
}
