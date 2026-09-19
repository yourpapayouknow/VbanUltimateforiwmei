import SwiftUI

// 监控诊断主视图
struct MonitoringView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            topToolbar

            Divider().background(Theme.borderSubtle)

            tableHeader

            Divider().background(Theme.borderSubtle)

            if isAllStreamsEmpty {
                emptyState
            } else {
                telemetryList
            }
        }
        .background(Theme.windowBg)
    }

    // 全流是否为空判断
    private var isAllStreamsEmpty: Bool {
        model.metrics.rxStreams.isEmpty && model.txStreams.filter(\.enabled).isEmpty
    }

    // 顶部操作工具条
    private var topToolbar: some View {
        HStack(spacing: 8) {
            Text(model.t("监控诊断", "Monitoring & Diagnostics"))
                .font(Theme.cnText(16.5, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .help(model.t("实时遥测各音频流网络吞吐、微秒抖动、丢包与时钟漂移", "Real-time telemetry of network throughput, jitter, loss, and clock drift"))

            Spacer()

            ParamCapsule(
                text: totalLostPackets > 0 ? "\(totalLostPackets) \(model.t("丢包", "Lost"))" : model.t("传输健康", "Healthy"),
                color: totalLostPackets > 0 ? Theme.alertRed : Theme.meterGreen
            )
            .help(model.t("全系统累计网络丢包总数。大于零时提示网络存在丢包，可能导致音频断音或顿挫。", "Total network packet loss. Greater than zero indicates dropouts."))

            ParamCapsule(
                text: model.networkQuality.title(for: model.language),
                color: Theme.textSecondary
            )
            .help(model.t("当前网络抗抖动平滑缓冲预设档位", "Current network jitter buffer preset"))

            ParamCapsule(
                text: model.t("500ms 刷新", "500ms Interval"),
                color: Theme.neonCyan.opacity(0.85)
            )
            .help(model.t("后台调度定时器每 500ms 刷新一次微秒级网络统计数据", "Background timer polls microsecond network stats every 500ms"))
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(Color.white.opacity(0.03))
    }

    // 遥测数据表头
    private var tableHeader: some View {
        HStack(spacing: 6) {
            Text(model.t("状态", "Status"))
                .frame(width: 32, alignment: .center)
            Text(model.t("类型", "Type"))
                .frame(width: 44, alignment: .center)
            Text(model.t("流标识", "Stream ID"))
                .frame(width: 130, alignment: .leading)
            Text(model.t("端点地址", "Endpoint"))
                .frame(width: 130, alignment: .leading)
            Text(model.t("音频规格", "Format"))
                .frame(width: 140, alignment: .leading)
            Text(model.t("有效带宽", "Bandwidth"))
                .frame(width: 85, alignment: .trailing)
            Text(model.t("网络包率", "Packet Rate"))
                .frame(width: 75, alignment: .trailing)
            Text(model.t("丢包", "Loss"))
                .frame(width: 60, alignment: .trailing)
            Text(model.t("乱序", "Disorder"))
                .frame(width: 60, alignment: .trailing)
            Text(model.t("重复", "Duplicates"))
                .frame(width: 60, alignment: .trailing)
            Text(model.t("网络抖动", "Jitter"))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(Theme.cnText(12, weight: .bold))
        .foregroundColor(Theme.textTertiary)
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(Color.black.opacity(0.2))
    }

    // 遥测明细列表
    private var telemetryList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 接收流遥测行
                ForEach(Array(model.metrics.rxStreams.enumerated()), id: \.element.name) { idx, strm in
                    rxTelemetryRow(idx: idx, strm: strm)
                    Divider().background(Theme.borderSubtle)
                }

                // 发送流遥测行
                ForEach(Array(model.txStreams.filter(\.enabled).enumerated()), id: \.element.id) { idx, tx in
                    txTelemetryRow(idx: model.metrics.rxStreams.count + idx, tx: tx)
                    Divider().background(Theme.borderSubtle)
                }
            }
        }
    }

    // 接收流数据行
    private func rxTelemetryRow(idx: Int, strm: VbanStrmMetric) -> some View {
        HStack(spacing: 6) {
            StatusLed(isActive: strm.status == "Active")
                .frame(width: 32, alignment: .center)

            Text(model.t("接收", "RCV"))
                .font(Theme.cnText(10.5, weight: .bold))
                .foregroundColor(Theme.neonCyan)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Theme.neonCyan.opacity(0.15))
                .cornerRadius(3)
                .frame(width: 44, alignment: .center)

            RollingLabel(text: strm.name, font: Theme.monoDigit(13, weight: .bold), color: Theme.textPrimary)
                .frame(width: 130, alignment: .leading)

            Text("\(strm.srcIp):\(strm.srcPort)")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .frame(width: 130, alignment: .leading)

            Text("\(strm.sampleRate / 1000)kHz · \(strm.channels)CH · \(strm.bitDepth)bit")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Text("\(fmtKbps(strm.kbps)) kbps")
                .font(Theme.monoDigit(12, weight: .bold))
                .foregroundColor(Theme.neonCyan)
                .frame(width: 85, alignment: .trailing)

            Text("\(strm.packetsPerSec) pkt/s")
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 75, alignment: .trailing)

            Text("\(strm.lostCount)")
                .font(Theme.monoDigit(12, weight: .bold))
                .foregroundColor(strm.lostCount > 0 ? Theme.alertRed : Theme.meterGreen)
                .frame(width: 60, alignment: .trailing)

            Text("\(strm.orderErrorCount)")
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(strm.orderErrorCount > 0 ? Theme.amberWarn : Theme.textTertiary)
                .frame(width: 60, alignment: .trailing)

            Text("\(strm.duplicateCount)")
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(strm.duplicateCount > 0 ? Theme.amberWarn : Theme.textTertiary)
                .frame(width: 60, alignment: .trailing)

            Text(String(format: "%.1f ms", strm.jitterMs))
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(strm.jitterMs > 20.0 ? Theme.amberWarn : Theme.meterGreen)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(idx % 2 == 0 ? Color.clear : Theme.rowAltBg)
    }

    // 发送流数据行
    private func txTelemetryRow(idx: Int, tx: VbanTxStreamDesc) -> some View {
        HStack(spacing: 6) {
            StatusLed(isActive: tx.enabled)
                .frame(width: 32, alignment: .center)

            Text(model.t("发送", "SND"))
                .font(Theme.cnText(10.5, weight: .bold))
                .foregroundColor(Theme.amberWarn)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Theme.amberWarn.opacity(0.15))
                .cornerRadius(3)
                .frame(width: 44, alignment: .center)

            RollingLabel(text: tx.name, font: Theme.monoDigit(13, weight: .bold), color: Theme.textPrimary)
                .frame(width: 130, alignment: .leading)

            Text("\(tx.targetIp):\(tx.targetPort)")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .frame(width: 130, alignment: .leading)

            Text("\(tx.sampleRate / 1000)kHz · \(tx.channels)CH · \(tx.bitDepth)bit")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Text("\(fmtKbps(tx.realKbps)) kbps")
                .font(Theme.monoDigit(12, weight: .bold))
                .foregroundColor(Theme.neonCyan)
                .frame(width: 85, alignment: .trailing)

            Text("\(tx.sampleRate / max(1, model.bufferingFrames)) pkt/s")
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 75, alignment: .trailing)

            Text("0")
                .font(Theme.monoDigit(12, weight: .bold))
                .foregroundColor(Theme.meterGreen)
                .frame(width: 60, alignment: .trailing)

            Text("-")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 60, alignment: .trailing)

            Text("-")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 60, alignment: .trailing)

            Text("-")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(idx % 2 == 0 ? Color.clear : Theme.rowAltBg)
    }

    // 空状态面板
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "speedometer")
                .font(.system(size: 34))
                .foregroundColor(Theme.textTertiary)

            Text(model.t("暂无活动音频流遥测数据", "No Active Stream Telemetry"))
                .font(Theme.cnText(14, weight: .bold))
                .foregroundColor(Theme.textSecondary)

            Text(model.t("当存在活动接收流或启用发送流时，此处将实时展示各流吞吐、微秒抖动与包率", "Active incoming and outgoing streams will display real-time throughput and loss here"))
                .font(Theme.cnText(12, weight: .medium))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .help(model.t("在“音频流”页面配置并启动发送流，或从局域网对端发送音频至本机", "Configure and start streams in the Streams tab"))
    }

    // 全局总丢包数
    private var totalLostPackets: UInt64 {
        model.metrics.rxStreams.reduce(0) { $0 + UInt64($1.lostCount) }
    }

    // 格式化千分位数字
    private func fmtKbps(_ val: UInt32) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: val)) ?? "\(val)"
    }
}
