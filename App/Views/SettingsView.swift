import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            // 固定高度顶栏 (40pt，与其它标签页完全对齐)
            HStack(spacing: 8) {
                Text(model.t("设置与概览", "Settings & Overview"))
                    .font(Theme.cnText(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .help(model.t("系统运行状态遥测与全局通信配置", "System telemetry and global communication settings"))

                Spacer()

                Button(action: {
                    model.refreshAll()
                }) {
                    Label(model.t("刷新状态", "Refresh"), systemImage: "arrow.clockwise")
                        .font(Theme.cnText(12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.neonCyan)
                .help(model.t("强制重新扫描 CoreAudio 硬件与网络流状态", "Force rescan CoreAudio devices and stream states"))
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(Color.white.opacity(0.03))

            Divider().background(Theme.borderSubtle)

            // 设置主体内容
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. 系统运行概览 (Overview)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.t("系统运行概览", "System Overview"))
                            .font(Theme.cnText(13, weight: .bold))
                            .foregroundColor(Theme.neonCyan)

                        HStack(spacing: 24) {
                            metricBox(title: model.t("接收活跃流", "Active Rx"), value: "\(model.metrics.activeRx)", color: Theme.meterGreen)
                                .help(model.t("当前在线接收的网络音频流数量", "Number of active incoming streams"))
                            metricBox(title: model.t("发送活跃流", "Active Tx"), value: "\(model.metrics.activeTx)", color: Theme.amberWarn)
                                .help(model.t("当前向外发送的网络音频流数量", "Number of active outgoing streams"))
                            metricBox(title: model.t("虚拟音频线缆", "Virtual Cables"), value: "\(model.cables.count)", color: Theme.neonCyan)
                                .help(model.t("系统 CoreAudio HAL 中已注册的虚拟线缆数量", "Registered virtual cables in CoreAudio HAL"))
                            metricBox(title: model.t("累计丢包数", "Packet Loss"), value: "\(model.metrics.totalLost)",
                                      color: model.metrics.totalLost > 0 ? Theme.alertRed : Theme.meterGreen)
                                .help(model.t("自应用启动以来的所有流 UDP 丢包总数", "Total UDP packet loss count across all streams"))
                            metricBox(title: model.t("音频调度核心", "Audio Engine"), value: model.isAudioRunning ? model.t("已就绪", "Ready") : model.t("已暂停", "Paused"),
                                      color: model.isAudioRunning ? Theme.meterGreen : Theme.alertRed)
                                .help(model.t("底层 CoreAudio AUHAL 实时音频引擎调度状态", "CoreAudio AUHAL real-time audio engine state"))
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.borderSubtle, lineWidth: 1))

                    // 2. 界面显示语言
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.t("界面显示语言", "Display Language"))
                            .font(Theme.cnText(13, weight: .bold))
                            .foregroundColor(Theme.neonCyan)

                        HStack(spacing: 16) {
                            Text(model.t("选择语言:", "Language:"))
                                .font(Theme.cnText(13, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)

                            Picker("", selection: $model.language) {
                                ForEach(AppLanguage.allCases) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                            .help(model.t("切换应用程序界面显示语言", "Switch application display language"))

                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.borderSubtle, lineWidth: 1))

                    // 3. 网络协议设置
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.t("网络通信协议", "Network Protocol"))
                            .font(Theme.cnText(13, weight: .bold))
                            .foregroundColor(Theme.neonCyan)

                        HStack(spacing: 16) {
                            Text(model.t("默认 UDP 监听端口:", "Default UDP Port:"))
                                .font(Theme.cnText(13, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)

                            TextField("", text: $model.udpPort)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(Theme.monoDigit(12.5, weight: .semibold))
                                .frame(width: 85)
                                .help(model.t("VBAN 官方标准网络监听端口为 6980。底层单套接字根据流名自动解复用。", "Official standard VBAN UDP port is 6980. Single socket automatically demuxes incoming streams by stream name."))

                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.borderSubtle, lineWidth: 1))

                    // 4. 虚拟驱动管理
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.t("虚拟音频驱动", "Virtual Audio Driver"))
                            .font(Theme.cnText(13, weight: .bold))
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
                                Label(model.metrics.driverInstalled ? model.t("重新安装驱动", "Reinstall Driver") : model.t("安装虚拟驱动", "Install Driver"),
                                      systemImage: "wrench.and.screwdriver")
                                    .font(Theme.cnText(12, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.neonCyan)
                            .help(model.t("部署 AudioServerPlugIn 驱动至 macOS 系统 HAL 目录（需要管理员权限）", "Deploy AudioServerPlugIn driver into system HAL directory (requires admin)"))
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.borderSubtle, lineWidth: 1))

                    // 5. 关于
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.t("关于", "About"))
                            .font(Theme.cnText(13, weight: .bold))
                            .foregroundColor(Theme.textTertiary)

                        Text("VBAN Ultimate for macOS • Apple Silicon (arm64)")
                            .font(Theme.cnText(13.5, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                            .help(model.t("底层采用 C++20 实时安全（RT-Safe）无锁 SPSC 环形缓冲、单 Socket 多流高效解复用与自适应 Jitter 缓冲架构。", "Built with C++20 RT-safe lock-free SPSC circular buffers, single-socket multi-stream demuxing, and adaptive jitter buffer architecture."))
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.borderSubtle, lineWidth: 1))
                }
                .padding(18)
            }
        }
        .background(Theme.windowBg)
    }

    private func metricBox(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.cnText(11.5, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(Theme.monoDigit(18, weight: .bold))
                .foregroundColor(color)
        }
        .frame(minWidth: 110, alignment: .leading)
    }
}
