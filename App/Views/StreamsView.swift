import SwiftUI

struct StreamsView: View {
    @ObservedObject var model: AppModel
    @State private var newStreamName = ""
    @State private var newStreamIp   = "192.168.1.50"
    @State private var newStreamPort = "6980"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 接收流段落 (VBAN RX)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("RECEIVE STREAMS (VBAN RX)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.8))
                        Spacer()
                        MicroCapsuleBadge(title: "\(model.metrics.rxStreams.count) Active", color: Theme.activeGreen)
                    }

                    if model.metrics.rxStreams.isEmpty {
                        Text("No active incoming streams on UDP port 6980. Streams will automatically appear here upon detection.")
                            .font(Theme.regularText(12))
                            .foregroundColor(Theme.mutedGray)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(model.metrics.rxStreams, id: \.name) { strm in
                                streamRow(strm: strm)
                                Divider().background(Theme.borderSubtle)
                            }
                        }
                    }
                }

                Divider().background(Theme.borderSubtle)

                // 发送流段落 (VBAN TX)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("TRANSMIT STREAMS (VBAN TX)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.8))
                        Spacer()
                        MicroCapsuleBadge(title: "Multi-Target Engine", color: Theme.amberGold)
                    }

                    // 快速添加发送流输入栏
                    HStack(spacing: 12) {
                        TextField("Stream Name (e.g. MasterOut)", text: $newStreamName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(8)
                            .background(Theme.surfaceBg)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .font(Theme.regularText(12))

                        TextField("Target IP (e.g. 192.168.1.100)", text: $newStreamIp)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(8)
                            .background(Theme.surfaceBg)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .font(Theme.monoDigit(12))
                            .frame(width: 180)

                        Button(action: {
                            // 添加新发送流
                        }) {
                            Label("Add TX Stream", systemImage: "plus.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.neonCyan)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(24)
        }
    }

    private func streamRow(strm: VbanStrmMetric) -> some View {
        HStack(spacing: 16) {
            Circle()
                .fill(strm.status == "Active" ? Theme.activeGreen : Theme.offlineRed)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(strm.name)
                    .font(Theme.monoDigit(13, weight: .bold))
                    .foregroundColor(.white)
                Text("\(strm.srcIp):\(strm.srcPort)")
                    .font(Theme.monoDigit(11))
                    .foregroundColor(Theme.mutedGray)
            }
            .frame(width: 140, alignment: .leading)

            Spacer()

            MicroCapsuleBadge(title: "\(strm.sampleRate / 1000) kHz", color: Theme.amberGold)
            MicroCapsuleBadge(title: "\(strm.channels) CH", color: .white.opacity(0.8))
            MicroCapsuleBadge(title: strm.format, color: Theme.mutedGray)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(strm.kbps) kbps")
                    .font(Theme.monoDigit(12, weight: .semibold))
                    .foregroundColor(Theme.neonCyan)
                Text("\(strm.packetsPerSec) pkt/s")
                    .font(Theme.monoDigit(10))
                    .foregroundColor(Theme.mutedGray)
            }
            .frame(width: 80, alignment: .trailing)

            VStack(alignment: .trailing, spacing: 2) {
                Text("Loss: \(strm.lostCount)")
                    .font(Theme.monoDigit(11, weight: .medium))
                    .foregroundColor(strm.lostCount > 0 ? Theme.offlineRed : Theme.activeGreen)
                Text(String(format: "Jitter: %.1fms", strm.jitterMs))
                    .font(Theme.monoDigit(10))
                    .foregroundColor(Theme.mutedGray)
            }
            .frame(width: 90, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}
