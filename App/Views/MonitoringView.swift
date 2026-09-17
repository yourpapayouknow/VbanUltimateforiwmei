import SwiftUI

struct MonitoringView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DIAGNOSTICS & NETWORK METRICS")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.8))
                        Text("Full VBAN Talkie & Receptor telemetry: Packet continuity, Jitter ms, Duplicates, and Dropped frames.")
                            .font(Theme.regularText(11))
                            .foregroundColor(Theme.mutedGray)
                    }
                    Spacer()
                    MicroCapsuleBadge(title: "500ms Throttled", color: Theme.amberGold)
                }

                Divider().background(Theme.borderSubtle)

                if model.metrics.rxStreams.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.mutedGray)
                        Text("No active stream telemetry available. Once audio streams begin arriving, real-time metrics will render below.")
                            .font(Theme.regularText(12))
                            .foregroundColor(Theme.mutedGray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // 诊断参数表
                    VStack(spacing: 0) {
                        // 表头
                        HStack(spacing: 12) {
                            Text("STREAM")
                                .frame(width: 120, alignment: .leading)
                            Text("THROUGHPUT")
                                .frame(width: 110, alignment: .trailing)
                            Text("FRAMES")
                                .frame(width: 100, alignment: .trailing)
                            Text("JITTER")
                                .frame(width: 80, alignment: .trailing)
                            Text("LOST")
                                .frame(width: 70, alignment: .trailing)
                            Text("DUP")
                                .frame(width: 60, alignment: .trailing)
                            Text("ORDER")
                                .frame(width: 70, alignment: .trailing)
                            Spacer()
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.5))
                        .padding(.vertical, 8)

                        Divider().background(Theme.borderSubtle)

                        ForEach(model.metrics.rxStreams, id: \.name) { strm in
                            HStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(strm.status == "Active" ? Theme.activeGreen : Theme.offlineRed)
                                        .frame(width: 6, height: 6)
                                    Text(strm.name)
                                        .font(Theme.monoDigit(12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(width: 120, alignment: .leading)

                                Text("\(strm.kbps) kbps")
                                    .font(Theme.monoDigit(12))
                                    .foregroundColor(Theme.neonCyan)
                                    .frame(width: 110, alignment: .trailing)

                                Text("\(strm.frameCount)")
                                    .font(Theme.monoDigit(12))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 100, alignment: .trailing)

                                Text(String(format: "%.1f ms", strm.jitterMs))
                                    .font(Theme.monoDigit(12))
                                    .foregroundColor(strm.jitterMs > 20.0 ? Theme.warningAmber : Theme.activeGreen)
                                    .frame(width: 80, alignment: .trailing)

                                Text("\(strm.lostCount)")
                                    .font(Theme.monoDigit(12, weight: .semibold))
                                    .foregroundColor(strm.lostCount > 0 ? Theme.offlineRed : Theme.activeGreen)
                                    .frame(width: 70, alignment: .trailing)

                                Text("\(strm.duplicateCount)")
                                    .font(Theme.monoDigit(12))
                                    .foregroundColor(strm.duplicateCount > 0 ? Theme.warningAmber : Theme.mutedGray)
                                    .frame(width: 60, alignment: .trailing)

                                Text("\(strm.orderErrorCount)")
                                    .font(Theme.monoDigit(12))
                                    .foregroundColor(strm.orderErrorCount > 0 ? Theme.warningAmber : Theme.mutedGray)
                                    .frame(width: 70, alignment: .trailing)

                                Spacer()
                            }
                            .padding(.vertical, 10)
                            Divider().background(Theme.borderSubtle)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}
