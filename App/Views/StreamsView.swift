import SwiftUI

struct StreamsView: View {
    @ObservedObject var model: AppModel
    @State private var newTxName = "MasterOut"
    @State private var newTxIp   = "192.168.1.50"
    @State private var newTxPort = "6980"

    var body: some View {
        VStack(spacing: 0) {
            // 接收流 (VBAN RX)
            VStack(alignment: .leading, spacing: 0) {
                // 分组标题栏
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(Theme.neonCyan)
                    Text("接收音频流 (VBAN RX)")
                        .font(Theme.cnText(12, weight: .bold))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    Text("监听端口: UDP \(model.udpPort)")
                        .font(Theme.monoDigit(11))
                        .foregroundColor(Theme.textTertiary)

                    ParamCapsule(text: "\(model.metrics.rxStreams.count) 活跃流", color: Theme.meterGreen)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.03))

                // 表头
                HStack(spacing: 12) {
                    Text("状态")
                        .frame(width: 40, alignment: .center)
                    Text("流名称")
                        .frame(width: 140, alignment: .leading)
                    Text("远端来源")
                        .frame(width: 150, alignment: .leading)
                    Text("采样格式")
                        .frame(width: 140, alignment: .leading)
                    Text("吞吐速率")
                        .frame(width: 100, alignment: .trailing)
                    Text("丢包 / 抖动")
                        .frame(width: 110, alignment: .trailing)
                    Spacer()
                }
                .font(Theme.cnText(11, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.2))

                Divider().background(Theme.borderSubtle)

                // 接收流列表
                if model.metrics.rxStreams.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.textTertiary)
                        Text("当前未检测到外部网络音频流。向本机的 UDP \(model.udpPort) 端口发送 VBAN 包将自动上线识别。")
                            .font(Theme.cnText(11))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(model.metrics.rxStreams.enumerated()), id: \.element.name) { idx, strm in
                                HStack(spacing: 12) {
                                    StatusLed(isActive: strm.status == "Active")
                                        .frame(width: 40, alignment: .center)

                                    Text(strm.name)
                                        .font(Theme.monoDigit(12, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                        .frame(width: 140, alignment: .leading)

                                    Text("\(strm.srcIp):\(strm.srcPort)")
                                        .font(Theme.monoDigit(11))
                                        .foregroundColor(Theme.textSecondary)
                                        .frame(width: 150, alignment: .leading)

                                    HStack(spacing: 4) {
                                        ParamCapsule(text: "\(strm.sampleRate / 1000)kHz")
                                        ParamCapsule(text: "\(strm.channels)CH")
                                        ParamCapsule(text: "16-bit")
                                    }
                                    .frame(width: 140, alignment: .leading)

                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text("\(strm.kbps) kbps")
                                            .font(Theme.monoDigit(11, weight: .semibold))
                                            .foregroundColor(Theme.neonCyan)
                                        Text("\(strm.packetsPerSec) pkt/s")
                                            .font(Theme.monoDigit(10))
                                            .foregroundColor(Theme.textTertiary)
                                    }
                                    .frame(width: 100, alignment: .trailing)

                                    HStack(spacing: 4) {
                                        Text("丢:\(strm.lostCount)")
                                            .font(Theme.monoDigit(11))
                                            .foregroundColor(strm.lostCount > 0 ? Theme.alertRed : Theme.meterGreen)
                                        Text(String(format: "%.1fms", strm.jitterMs))
                                            .font(Theme.monoDigit(10))
                                            .foregroundColor(Theme.textTertiary)
                                    }
                                    .frame(width: 110, alignment: .trailing)

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
            .frame(maxHeight: .infinity)

            Divider().background(Theme.borderSubtle)

            // 发送流 (VBAN TX)
            VStack(alignment: .leading, spacing: 0) {
                // 分组标题栏
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(Theme.amberWarn)
                    Text("发送音频流 (VBAN TX)")
                        .font(Theme.cnText(12, weight: .bold))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    Text("支持向局域网单播/广播任意音频源")
                        .font(Theme.cnText(11))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.03))

                // 原生紧凑添加条
                HStack(spacing: 10) {
                    Text("流名称:")
                        .font(Theme.cnText(11))
                        .foregroundColor(Theme.textSecondary)
                    TextField("", text: $newTxName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(11))
                        .frame(width: 120)

                    Text("目标IP:")
                        .font(Theme.cnText(11))
                        .foregroundColor(Theme.textSecondary)
                    TextField("", text: $newTxIp)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(11))
                        .frame(width: 130)

                    Text("端口:")
                        .font(Theme.cnText(11))
                        .foregroundColor(Theme.textSecondary)
                    TextField("", text: $newTxPort)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(11))
                        .frame(width: 60)

                    Spacer()

                    Button(action: {
                        // 预留TX流添加动作
                    }) {
                        Label("新建发送流", systemImage: "plus")
                            .font(Theme.cnText(11, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.neonCyan)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.15))
            }
        }
        .background(Theme.windowBg)
    }
}
