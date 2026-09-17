import SwiftUI

struct OverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 顶部状态指标汇总 (去卡片化流动排版)
                HStack(spacing: 32) {
                    metricItem(label: "VBAN RX STREAMS",
                               value: "\(model.metrics.activeRx)",
                               sub: "Active Incoming",
                               accent: Theme.neonCyan)

                    metricItem(label: "VBAN TX STREAMS",
                               value: "\(model.metrics.activeTx)",
                               sub: "Active Outgoing",
                               accent: Theme.amberGold)

                    metricItem(label: "VIRTUAL CABLES",
                               value: "\(model.cables.count)",
                               sub: "Managed in HAL",
                               accent: Theme.neonCyan)

                    metricItem(label: "PACKET LOSS",
                               value: "\(model.metrics.totalLost)",
                               sub: "Dropped Packets",
                               accent: model.metrics.totalLost > 0 ? Theme.offlineRed : Theme.activeGreen)

                    metricItem(label: "AUDIO CORE",
                               value: model.isAudioRunning ? "RUNNING" : "STOPPED",
                               sub: "CoreAudio Engine",
                               accent: model.isAudioRunning ? Theme.activeGreen : Theme.offlineRed)
                }
                .padding(.vertical, 8)

                Divider()
                    .background(Theme.borderSubtle)

                // 核心工作流概览与状态
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("ACTIVE VBAN STREAMS")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.7))
                        Spacer()
                        MicroCapsuleBadge(title: "UDP PORT 6980", color: Theme.neonCyan)
                    }

                    if model.metrics.rxStreams.isEmpty {
                        HStack {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .foregroundColor(Theme.mutedGray)
                            Text("Listening on UDP 6980... No active VBAN audio streams detected yet.")
                                .font(Theme.regularText(12))
                                .foregroundColor(Theme.mutedGray)
                        }
                        .padding(.vertical, 16)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(model.metrics.rxStreams, id: \.name) { strm in
                                HStack {
                                    Circle()
                                        .fill(strm.status == "Active" ? Theme.activeGreen : Theme.offlineRed)
                                        .frame(width: 8, height: 8)

                                    Text(strm.name)
                                        .font(Theme.monoDigit(13, weight: .semibold))
                                        .foregroundColor(.white)

                                    Spacer()

                                    MicroCapsuleBadge(title: "\(strm.srcIp):\(strm.srcPort)", color: Theme.neonCyan)
                                    MicroCapsuleBadge(title: "\(strm.sampleRate / 1000) kHz", color: Theme.amberGold)
                                    MicroCapsuleBadge(title: "\(strm.channels) CH", color: .white.opacity(0.8))

                                    Text("\(strm.packetsPerSec) pkt/s")
                                        .font(Theme.monoDigit(11))
                                        .foregroundColor(Theme.mutedGray)
                                        .frame(width: 80, alignment: .trailing)
                                }
                                .padding(.vertical, 10)
                                Divider().background(Theme.borderSubtle)
                            }
                        }
                    }
                }

                // 驱动状态提示
                HStack(spacing: 12) {
                    Image(systemName: model.metrics.driverInstalled ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(model.metrics.driverInstalled ? Theme.activeGreen : Theme.warningAmber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.metrics.driverInstalled ? "Virtual Audio Driver is Loaded & Healthy" : "Virtual Audio Driver Not Installed into System HAL")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text(model.metrics.driverInstalled ? "AudioServerPlugIn is active in coreaudiod with zero-restart dynamic hotplug support." : "You can install VBANUltimateAudio.driver in Settings to unlock virtual cables.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.mutedGray)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Theme.surfaceBg)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.borderSubtle, lineWidth: 1)
                )
            }
            .padding(24)
        }
    }

    private func metricItem(label: String, value: String, sub: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.white.opacity(0.5))
            Text(value)
                .font(Theme.monoDigit(20, weight: .bold))
                .foregroundColor(accent)
            Text(sub)
                .font(.system(size: 11))
                .foregroundColor(Theme.mutedGray)
        }
        .frame(minWidth: 120, alignment: .leading)
    }
}
