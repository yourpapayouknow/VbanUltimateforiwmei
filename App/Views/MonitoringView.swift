import SwiftUI

struct MonitoringView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏 (固定高度 38)
            HStack(spacing: 8) {
                Text(model.t("网络音频监控与指标诊断", "Monitoring & Diagnostics"))
                    .font(Theme.cnText(12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .help(model.t("实时遥测各音频流网络吞吐、微秒抖动、丢包与时钟漂移", "Real-time telemetry of network throughput, jitter, loss, and clock drift"))

                Spacer()

                ParamCapsule(text: model.t("500ms 实时采样", "500ms Sampling"), color: Theme.amberWarn)
                    .help(model.t("后台调度定时器每 500ms 刷新一次微秒级网络统计数据", "Background timer polls microsecond network stats every 500ms"))
            }
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(Color.white.opacity(0.03))

            Divider().background(Theme.borderSubtle)

            // 表头 (固定高度 28)
            HStack(spacing: 10) {
                Text(model.t("状态", "Status"))
                    .frame(width: 40, alignment: .center)
                Text(model.t("流标识", "Stream ID"))
                    .frame(width: 140, alignment: .leading)
                Text(model.t("有效带宽", "Bandwidth"))
                    .frame(width: 100, alignment: .trailing)
                Text(model.t("网络包率", "Packet Rate"))
                    .frame(width: 90, alignment: .trailing)
                Text(model.t("音频帧数", "Audio Frames"))
                    .frame(width: 110, alignment: .trailing)
                Text(model.t("网络抖动", "Jitter"))
                    .frame(width: 80, alignment: .trailing)
                Text(model.t("丢包计数", "Lost Pkts"))
                    .frame(width: 70, alignment: .trailing)
                Text(model.t("重复包", "Duplicates"))
                    .frame(width: 60, alignment: .trailing)
                Text(model.t("乱序包", "Reordered"))
                    .frame(width: 60, alignment: .trailing)
                Spacer()
            }
            .font(Theme.cnText(11, weight: .semibold))
            .foregroundColor(Theme.textTertiary)
            .padding(.horizontal, 16)
            .frame(height: 28)
            .background(Color.black.opacity(0.2))

            Divider().background(Theme.borderSubtle)

            // 指标数据行
            if model.metrics.rxStreams.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.textTertiary)
                    Text(model.t("无监控遥测数据", "No Telemetry Data"))
                        .font(Theme.cnText(12))
                        .foregroundColor(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .help(model.t("当存在活动网络音频流时，此处将实时展示各流的微秒级网络吞吐与丢包分析", "Active streams will display microsecond network throughput and loss telemetry here"))
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(model.metrics.rxStreams.enumerated()), id: \.element.name) { idx, strm in
                            HStack(spacing: 10) {
                                StatusLed(isActive: strm.status == "Active")
                                    .frame(width: 40, alignment: .center)

                                Text(strm.name)
                                    .font(Theme.monoDigit(12, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                    .frame(width: 140, alignment: .leading)

                                Text("\(strm.kbps) kbps")
                                    .font(Theme.monoDigit(11))
                                    .foregroundColor(Theme.neonCyan)
                                    .frame(width: 100, alignment: .trailing)

                                Text("\(strm.packetsPerSec) pkt/s")
                                    .font(Theme.monoDigit(11))
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(width: 90, alignment: .trailing)

                                Text("\(strm.frameCount)")
                                    .font(Theme.monoDigit(11))
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(width: 110, alignment: .trailing)

                                Text(String(format: "%.1f ms", strm.jitterMs))
                                    .font(Theme.monoDigit(11))
                                    .foregroundColor(strm.jitterMs > 20.0 ? Theme.amberWarn : Theme.meterGreen)
                                    .frame(width: 80, alignment: .trailing)

                                Text("\(strm.lostCount)")
                                    .font(Theme.monoDigit(11, weight: .semibold))
                                    .foregroundColor(strm.lostCount > 0 ? Theme.alertRed : Theme.meterGreen)
                                    .frame(width: 70, alignment: .trailing)

                                Text("\(strm.duplicateCount)")
                                    .font(Theme.monoDigit(11))
                                    .foregroundColor(strm.duplicateCount > 0 ? Theme.amberWarn : Theme.textTertiary)
                                    .frame(width: 60, alignment: .trailing)

                                Text("\(strm.orderErrorCount)")
                                    .font(Theme.monoDigit(11))
                                    .foregroundColor(strm.orderErrorCount > 0 ? Theme.amberWarn : Theme.textTertiary)
                                    .frame(width: 60, alignment: .trailing)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 34)
                            .background(idx % 2 == 0 ? Color.clear : Theme.rowAltBg)

                            Divider().background(Theme.borderSubtle)
                        }
                    }
                }
            }
        }
        .background(Theme.windowBg)
    }
}
