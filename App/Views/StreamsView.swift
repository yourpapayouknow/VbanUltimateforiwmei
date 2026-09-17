import SwiftUI

struct StreamsView: View {
    @ObservedObject var model: AppModel
    @State private var newTxName = "MasterOut"
    @State private var newTxIp   = "192.168.1.50"
    @State private var newTxPort = "6980"

    var body: some View {
        VStack(spacing: 0) {
            // 接收流 (VBAN RX) - 固定高度顶栏 (40pt)
            VStack(alignment: .leading, spacing: 0) {
                // 固定高度工具栏
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.neonCyan)
                    Text(model.t("音频接收流", "Incoming Streams"))
                        .font(Theme.cnText(14, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .help(model.t("监听外部网络传入的 VBAN UDP 音频数据流", "Listens for incoming VBAN UDP audio streams from network"))

                    Spacer()

                    Text("UDP \(model.udpPort)")
                        .font(Theme.monoDigit(12.5, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                        .help(model.t("VBAN 标准网络监听端口", "Standard VBAN network listening port"))

                    ParamCapsule(text: "\(model.metrics.rxStreams.count) " + model.t("活跃", "Active"), color: Theme.meterGreen)
                        .help(model.t("当前在线接收的音频流数量", "Number of currently active incoming streams"))
                }
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(Color.white.opacity(0.03))

                Divider().background(Theme.borderSubtle)

                // 固定高度表头 (30pt)
                HStack(spacing: 12) {
                    Text(model.t("状态", "Status"))
                        .frame(width: 44, alignment: .center)
                    Text(model.t("流名称", "Stream Name"))
                        .frame(width: 150, alignment: .leading)
                    Text(model.t("远端来源", "Remote Source"))
                        .frame(width: 160, alignment: .leading)
                    Text(model.t("采样格式", "Audio Format"))
                        .frame(width: 150, alignment: .leading)
                    Text(model.t("吞吐速率", "Bitrate"))
                        .frame(width: 110, alignment: .trailing)
                    Text(model.t("丢包 / 抖动", "Loss / Jitter"))
                        .frame(width: 120, alignment: .trailing)
                    Spacer()
                }
                .font(Theme.cnText(12.5, weight: .bold))
                .foregroundColor(Theme.textTertiary)
                .padding(.horizontal, 16)
                .frame(height: 30)
                .background(Color.black.opacity(0.2))

                Divider().background(Theme.borderSubtle)

                // 接收流列表
                if model.metrics.rxStreams.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundColor(Theme.textTertiary)
                        Text(model.t("无网络音频流", "No Active Streams"))
                            .font(Theme.cnText(14, weight: .semibold))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .help(model.t("向本机 UDP 6980 端口发送 VBAN 音频包将自动上线识别", "Sending VBAN packets to UDP 6980 will automatically list active streams here"))
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(model.metrics.rxStreams.enumerated()), id: \.element.name) { idx, strm in
                                HStack(spacing: 12) {
                                    StatusLed(isActive: strm.status == "Active")
                                        .frame(width: 44, alignment: .center)

                                    Text(strm.name)
                                        .font(Theme.monoDigit(14, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                        .frame(width: 150, alignment: .leading)

                                    Text("\(strm.srcIp):\(strm.srcPort)")
                                        .font(Theme.monoDigit(12.5, weight: .semibold))
                                        .foregroundColor(Theme.textSecondary)
                                        .frame(width: 160, alignment: .leading)

                                    HStack(spacing: 4) {
                                        ParamCapsule(text: "\(strm.sampleRate / 1000)kHz")
                                        ParamCapsule(text: "\(strm.channels)CH")
                                        ParamCapsule(text: "16-bit")
                                    }
                                    .frame(width: 150, alignment: .leading)

                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text("\(strm.kbps) kbps")
                                            .font(Theme.monoDigit(12.5, weight: .bold))
                                            .foregroundColor(Theme.neonCyan)
                                        Text("\(strm.packetsPerSec) pkt/s")
                                            .font(Theme.monoDigit(11, weight: .semibold))
                                            .foregroundColor(Theme.textTertiary)
                                    }
                                    .frame(width: 110, alignment: .trailing)

                                    HStack(spacing: 4) {
                                        Text("丢:\(strm.lostCount)")
                                            .font(Theme.monoDigit(12.5, weight: .bold))
                                            .foregroundColor(strm.lostCount > 0 ? Theme.alertRed : Theme.meterGreen)
                                        Text(String(format: "%.1fms", strm.jitterMs))
                                            .font(Theme.monoDigit(11, weight: .semibold))
                                            .foregroundColor(Theme.textTertiary)
                                    }
                                    .frame(width: 120, alignment: .trailing)

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 38)
                                .background(idx % 2 == 0 ? Color.clear : Theme.rowAltBg)

                                Divider().background(Theme.borderSubtle)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Divider().background(Theme.borderSubtle)

            // 发送流 (VBAN TX) - 固定单行紧凑底栏 (44pt)
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.amberWarn)
                Text(model.t("音频发送流", "Outgoing Streams"))
                    .font(Theme.cnText(13.5, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .help(model.t("向局域网单播或广播目标主机传输音频流", "Transmit audio stream to unicast or broadcast network targets"))

                Spacer()

                HStack(spacing: 8) {
                    Text(model.t("流名称:", "Stream:"))
                        .font(Theme.cnText(12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    TextField("", text: $newTxName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(12.5, weight: .semibold))
                        .frame(width: 120)
                        .help(model.t("自定义发送音频流的名称标识", "Custom outgoing audio stream identifier"))

                    Text(model.t("目标IP:", "Target IP:"))
                        .font(Theme.cnText(12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    TextField("", text: $newTxIp)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(12.5, weight: .semibold))
                        .frame(width: 130)
                        .help(model.t("接收端局域网 IP 地址（单播如 192.168.1.50，广播如 192.168.1.255）", "Target network IP (unicast or broadcast)"))

                    Text(model.t("端口:", "Port:"))
                        .font(Theme.cnText(12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    TextField("", text: $newTxPort)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(12.5, weight: .semibold))
                        .frame(width: 65)
                        .help(model.t("目标监听 UDP 端口号（标准默认为 6980）", "Target UDP port number (standard 6980)"))

                    Button(action: {
                        // 预留TX流添加动作
                    }) {
                        Label(model.t("新建发送流", "Add Stream"), systemImage: "plus")
                            .font(Theme.cnText(12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.neonCyan)
                    .help(model.t("创建并启动新的 VBAN 发送流", "Create and start new VBAN outgoing stream"))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color.white.opacity(0.02))
        }
        .background(Theme.windowBg)
    }
}
