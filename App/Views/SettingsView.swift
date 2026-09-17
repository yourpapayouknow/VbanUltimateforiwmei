import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. 系统运行概览 (Overview)
                VStack(alignment: .leading, spacing: 10) {
                    Text("系统运行概览 (OVERVIEW)")
                        .font(Theme.cnText(11, weight: .bold))
                        .foregroundColor(Theme.neonCyan)

                    HStack(spacing: 24) {
                        metricBox(title: "接收活跃流", value: "\(model.metrics.activeRx)", color: Theme.meterGreen)
                        metricBox(title: "发送活跃流", value: "\(model.metrics.activeTx)", color: Theme.amberWarn)
                        metricBox(title: "虚拟音频线缆", value: "\(model.cables.count)", color: Theme.neonCyan)
                        metricBox(title: "累计丢包数", value: "\(model.metrics.totalLost)",
                                  color: model.metrics.totalLost > 0 ? Theme.alertRed : Theme.meterGreen)
                        metricBox(title: "音频调度核心", value: model.isAudioRunning ? "已就绪" : "已暂停",
                                  color: model.isAudioRunning ? Theme.meterGreen : Theme.alertRed)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.borderSubtle, lineWidth: 1))

                // 2. 网络协议设置
                VStack(alignment: .leading, spacing: 10) {
                    Text("网络通信参数 (VBAN PROTOCOL)")
                        .font(Theme.cnText(11, weight: .bold))
                        .foregroundColor(Theme.neonCyan)

                    HStack(spacing: 16) {
                        Text("默认 UDP 监听端口:")
                            .font(Theme.cnText(12))
                            .foregroundColor(Theme.textPrimary)

                        TextField("", text: $model.udpPort)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(Theme.monoDigit(11))
                            .frame(width: 80)

                        Text("官方标准端口为 6980，多流共用单 Socket 自动按流名解复用。")
                            .font(Theme.cnText(11))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.borderSubtle, lineWidth: 1))

                // 3. 虚拟驱动管理
                VStack(alignment: .leading, spacing: 10) {
                    Text("虚拟音频驱动插件 (AUDIOSERVERPLUGIN)")
                        .font(Theme.cnText(11, weight: .bold))
                        .foregroundColor(Theme.neonCyan)

                    HStack(spacing: 12) {
                        StatusLed(isActive: model.metrics.driverInstalled)
                        Text(model.metrics.driverInstalled ? "驱动已正确部署至 /Library/Audio/Plug-Ins/HAL/" : "驱动尚未部署至系统 HAL 目录")
                            .font(Theme.cnText(12))
                            .foregroundColor(Theme.textPrimary)

                        Spacer()

                        Button(action: {
                            let p = Process()
                            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                            p.arguments = ["-lc", "Scripts/install_driver.zsh"]
                            try? p.run()
                            p.waitUntilExit()
                            model.refreshAll()
                        }) {
                            Label(model.metrics.driverInstalled ? "重新安装/修复驱动" : "安装虚拟驱动",
                                  systemImage: "wrench.and.screwdriver")
                                .font(Theme.cnText(11, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.neonCyan)
                    }

                    Text("该驱动支持目录事件原子监听，添加或删除虚拟线缆时直接对齐系统 CoreAudio，无需重启 coreaudiod 守护进程。")
                        .font(Theme.cnText(11))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(14)
                .background(Color.white.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.borderSubtle, lineWidth: 1))

                // 4. 关于与底层信息
                VStack(alignment: .leading, spacing: 6) {
                    Text("关于 VBAN ULTIMATE")
                        .font(Theme.cnText(11, weight: .bold))
                        .foregroundColor(Theme.textTertiary)

                    Text("VBAN Ultimate for macOS • Apple Silicon 原生 (arm64)")
                        .font(Theme.cnText(12, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    Text("底层采用 C++20 实时安全（RT-Safe）无锁 SPSC 环形缓冲、单 Socket 多流高效解复用与自适应 Jitter 缓冲架构。")
                        .font(Theme.cnText(11))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(14)
                .background(Color.white.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.borderSubtle, lineWidth: 1))
            }
            .padding(16)
        }
        .background(Theme.windowBg)
    }

    private func metricBox(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.cnText(10))
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(Theme.monoDigit(16, weight: .bold))
                .foregroundColor(color)
        }
        .frame(minWidth: 100, alignment: .leading)
    }
}
