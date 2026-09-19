import SwiftUI

// 监控诊断主视图
struct MonitoringView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            topToolbar

            Divider().background(Theme.borderSubtle)

            telemetryDeck

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

            ParamCapsule(text: model.t("500ms 采样", "500ms Interval"), color: Theme.neonCyan.opacity(0.85))
                .help(model.t("后台调度定时器每 500ms 刷新一次微秒级网络统计数据", "Background timer polls microsecond network stats every 500ms"))
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(Color.white.opacity(0.03))
    }

    // 全局遥测看板
    private var telemetryDeck: some View {
        HStack(spacing: 12) {
            // 总吞吐指标磁贴
            telemetryTile(
                title: model.t("网络总吞吐", "Total Throughput"),
                value: "\(fmtKbps(totalThroughputKbps)) kbps",
                subtitle: "\(fmtKbps(rxThroughputKbps)) RX · \(fmtKbps(txThroughputKbps)) TX",
                valueColor: Theme.neonCyan,
                tooltip: model.t("局域网内所有活动接收流与发送流的实时吞吐带宽总计", "Combined real-time bandwidth of all active incoming and outgoing streams")
            )

            // 网络包率指标磁贴
            telemetryTile(
                title: model.t("网络包率", "Packet Rate"),
                value: "\(totalPacketRate) pkt/s",
                subtitle: model.t("调度块: \(model.bufferingFrames) 帧", "Block: \(model.bufferingFrames) fr"),
                valueColor: Theme.textPrimary,
                tooltip: model.t("全系统每秒处理的网络音频数据包总数与硬件调度样本数", "Total packets processed per second and current hardware buffering size")
            )

            // 传输质量指标磁贴
            telemetryTile(
                title: model.t("网络抖动与丢包", "Jitter & Loss"),
                value: String(format: "%.1f ms · %d 丢包", maxJitterMs, totalLostPackets),
                subtitle: model.t("预设: \(model.networkQuality.title(for: model.language))", "Quality: \(model.networkQuality.title(for: model.language))"),
                valueColor: totalLostPackets > 0 ? Theme.alertRed : Theme.meterGreen,
                tooltip: model.t("网络抗抖动缓冲深度与全链路累计丢包数", "Network jitter depth and total dropped packets count")
            )

            // 传输引擎指标磁贴
            telemetryTile(
                title: model.t("音频传输引擎", "Engine & Driver"),
                value: model.isPortConflict ? "UDP -" : "UDP \(model.udpPort)",
                subtitle: model.metrics.driverInstalled ? model.t("HAL 驱动已就绪", "HAL Driver Ready") : model.t("未检测到驱动", "Driver Not Found"),
                valueColor: model.isPortConflict ? Theme.alertRed : (model.metrics.driverInstalled ? Theme.meterGreen : Theme.textTertiary),
                tooltip: model.t("VBAN 网络监听端口及 CoreAudio AudioServerPlugIn 虚拟音频驱动就绪状态", "VBAN network listening port and HAL driver status")
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.015))
    }

    // 遥测指标磁贴
    private func telemetryTile(title: String, value: String, subtitle: String, valueColor: Color, tooltip: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.cnText(11, weight: .semibold))
                .foregroundColor(Theme.textTertiary)

            Text(value)
                .font(Theme.monoDigit(15, weight: .heavy))
                .foregroundColor(valueColor)
                .lineLimit(1)

            Text(subtitle)
                .font(Theme.cnText(10.5, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.25))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .help(tooltip)
    }

    // 遥测数据表头
    private var tableHeader: some View {
        HStack(spacing: 8) {
            Text(model.t("状态", "Status"))
                .frame(width: 36, alignment: .center)
            Text(model.t("类型", "Type"))
                .frame(width: 42, alignment: .center)
            Text(model.t("流标识", "Stream ID"))
                .frame(width: 140, alignment: .leading)
            Text(model.t("端点地址", "Endpoint"))
                .frame(width: 140, alignment: .leading)
            Text(model.t("音频规格", "Format"))
                .frame(width: 150, alignment: .leading)
            Text(model.t("有效带宽", "Bandwidth"))
                .frame(width: 95, alignment: .trailing)
            Text(model.t("网络包率", "Packet Rate"))
                .frame(width: 85, alignment: .trailing)
            Text(model.t("抖动", "Jitter"))
                .frame(width: 70, alignment: .trailing)
            Text(model.t("丢包", "Loss"))
                .frame(width: 65, alignment: .trailing)
            Text(model.t("重复/乱序", "Dup/Ord"))
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
        HStack(spacing: 8) {
            StatusLed(isActive: strm.status == "Active")
                .frame(width: 36, alignment: .center)

            Text("RX")
                .font(Theme.monoDigit(10, weight: .heavy))
                .foregroundColor(Theme.neonCyan)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Theme.neonCyan.opacity(0.15))
                .cornerRadius(3)
                .frame(width: 42, alignment: .center)

            RollingLabel(text: strm.name, font: Theme.monoDigit(13, weight: .bold), color: Theme.textPrimary)
                .frame(width: 140, alignment: .leading)

            Text("\(strm.srcIp):\(strm.srcPort)")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Text("\(strm.sampleRate / 1000)kHz · \(strm.channels)CH · \(strm.bitDepth)bit")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)

            Text("\(strm.kbps) kbps")
                .font(Theme.monoDigit(12, weight: .bold))
                .foregroundColor(Theme.neonCyan)
                .frame(width: 95, alignment: .trailing)

            Text("\(strm.packetsPerSec) pkt/s")
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 85, alignment: .trailing)

            Text(String(format: "%.1f ms", strm.jitterMs))
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(strm.jitterMs > 20.0 ? Theme.amberWarn : Theme.meterGreen)
                .frame(width: 70, alignment: .trailing)

            Text("\(strm.lostCount)")
                .font(Theme.monoDigit(12, weight: .bold))
                .foregroundColor(strm.lostCount > 0 ? Theme.alertRed : Theme.meterGreen)
                .frame(width: 65, alignment: .trailing)

            Text("\(strm.duplicateCount) / \(strm.orderErrorCount)")
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor((strm.duplicateCount > 0 || strm.orderErrorCount > 0) ? Theme.amberWarn : Theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(idx % 2 == 0 ? Color.clear : Theme.rowAltBg)
    }

    // 发送流数据行
    private func txTelemetryRow(idx: Int, tx: VbanTxStreamDesc) -> some View {
        HStack(spacing: 8) {
            StatusLed(isActive: tx.enabled)
                .frame(width: 36, alignment: .center)

            Text("TX")
                .font(Theme.monoDigit(10, weight: .heavy))
                .foregroundColor(Theme.amberWarn)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Theme.amberWarn.opacity(0.15))
                .cornerRadius(3)
                .frame(width: 42, alignment: .center)

            RollingLabel(text: tx.name, font: Theme.monoDigit(13, weight: .bold), color: Theme.textPrimary)
                .frame(width: 140, alignment: .leading)

            Text("\(tx.targetIp):\(tx.targetPort)")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Text("\(tx.sampleRate / 1000)kHz · \(tx.channels)CH · \(tx.bitDepth)bit")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)

            Text("\(tx.realKbps) kbps")
                .font(Theme.monoDigit(12, weight: .bold))
                .foregroundColor(Theme.neonCyan)
                .frame(width: 95, alignment: .trailing)

            Text("\(tx.sampleRate / max(1, model.bufferingFrames)) pkt/s")
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 85, alignment: .trailing)

            Text("-")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 70, alignment: .trailing)

            Text("0")
                .font(Theme.monoDigit(12, weight: .bold))
                .foregroundColor(Theme.meterGreen)
                .frame(width: 65, alignment: .trailing)

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

    // 接收吞吐量总计
    private var rxThroughputKbps: UInt32 {
        model.metrics.rxStreams.reduce(0) { $0 + UInt32($1.kbps) }
    }

    // 发送吞吐量总计
    private var txThroughputKbps: UInt32 {
        model.txStreams.filter(\.enabled).reduce(0) { $0 + $1.realKbps }
    }

    // 全局总吞吐量
    private var totalThroughputKbps: UInt32 {
        rxThroughputKbps + txThroughputKbps
    }

    // 全局总包率
    private var totalPacketRate: UInt32 {
        let rxPkt = model.metrics.rxStreams.reduce(0) { $0 + UInt32($1.packetsPerSec) }
        let txPkt = model.txStreams.filter(\.enabled).reduce(0) { $0 + ($1.sampleRate / max(1, model.bufferingFrames)) }
        return rxPkt + txPkt
    }

    // 最大微秒抖动
    private var maxJitterMs: Double {
        model.metrics.rxStreams.map(\.jitterMs).max() ?? 0.0
    }

    // 全局丢包总数
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
