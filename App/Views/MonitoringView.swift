import SwiftUI

struct MonitoringView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack(spacing: 8) {
                Text("网络音频监控与指标诊断")
                    .font(Theme.cnText(12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                ParamCapsule(text: "500ms 实时采样", color: Theme.amberWarn)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.03))

            Divider().background(Theme.borderSubtle)

            // 表头
            HStack(spacing: 10) {
                Text("状态")
                    .frame(width: 40, alignment: .center)
                Text("流标识")
                    .frame(width: 140, alignment: .leading)
                Text("有效带宽")
                    .frame(width: 100, alignment: .trailing)
                Text("网络包率")
                    .frame(width: 90, alignment: .trailing)
                Text("累计音频帧")
                    .frame(width: 110, alignment: .trailing)
                Text("网络抖动")
                    .frame(width: 80, alignment: .trailing)
                Text("丢包计数")
                    .frame(width: 70, alignment: .trailing)
                Text("重复包")
                    .frame(width: 60, alignment: .trailing)
                Text("乱序包")
                    .frame(width: 60, alignment: .trailing)
                Spacer()
            }
            .font(Theme.cnText(11, weight: .semibold))
            .foregroundColor(Theme.textTertiary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.2))

            Divider().background(Theme.borderSubtle)

            // 指标数据行
            if model.metrics.rxStreams.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.textTertiary)
                    Text("无活动网络音频流指标。向本机发送音频流后将在此处实时刷新微秒级遥测数据。")
                        .font(Theme.cnText(11))
                        .foregroundColor(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            .padding(.vertical, 8)
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
