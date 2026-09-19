import SwiftUI

// 监控诊断主视图
struct MonitoringView: View {
    @ObservedObject var model: AppModel
    @State private var showPingSheet: Bool = false
    @State private var selectedPingIp: String? = nil

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
        .sheet(isPresented: $showPingSheet) {
            VbanPingSheet(model: model, targetIp: selectedPingIp, isPresented: $showPingSheet)
        }
    }

    // 全流是否为空判断
    private var isAllStreamsEmpty: Bool {
        model.metrics.rxStreams.isEmpty && model.txStreams.isEmpty
    }

    // 顶部操作工具条
    private var topToolbar: some View {
        HStack(spacing: 8) {
            Button(action: {
                selectedPingIp = nil
                showPingSheet = true
            }) {
                Text("VBAN Ping")
                    .font(Theme.monoDigit(11.5, weight: .bold))
                    .foregroundColor(Theme.neonCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(Theme.neonCyan.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Theme.neonCyan.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .help(model.t("打开 VBAN Ping 服务节点诊断面板", "Open VBAN Ping diagnostic inspector"))

            Spacer()

            ParamCapsule(
                text: model.metrics.totalUnderrun > 0 ? "\(model.t("欠载", "Underrun")) \(model.metrics.totalUnderrun)" : model.t("缓冲稳定", "Buffer Healthy"),
                color: model.metrics.totalUnderrun > 0 ? Theme.alertRed : Theme.meterGreen
            )
            .help(model.t("Underrun (欠载抽空)：接收端未及时获取数据包或缓冲耗尽，导致音频静音补零或爆音。当前累计：\(model.metrics.totalUnderrun) 次", "Buffer starvation. Audio was silenced or dropped. Total: \(model.metrics.totalUnderrun)"))

            ParamCapsule(
                text: totalLostPackets > 0 ? "\(totalLostPackets) \(model.t("丢包", "Lost"))" : model.t("传输健康", "Healthy"),
                color: totalLostPackets > 0 ? Theme.alertRed : Theme.meterGreen
            )
            .help(model.t("全系统累计网络丢包总数。大于零时提示网络存在丢包，可能导致音频断音或顿挫。", "Total network packet loss. Greater than zero indicates dropouts."))

            ParamCapsule(
                text: (model.metrics.totalCorrupt + model.metrics.totalError) > 0 ? "\(model.t("异常", "Errors")) \(model.metrics.totalCorrupt + model.metrics.totalError)" : model.t("协议合规", "Valid"),
                color: (model.metrics.totalCorrupt + model.metrics.totalError) > 0 ? Theme.alertRed : Theme.textSecondary
            )
            .help(model.t("Corrupt (报文损坏畸变) 与 Error (网络套接字错误) 统计。损坏：\(model.metrics.totalCorrupt)，错误：\(model.metrics.totalError)", "Corrupt packets and socket errors"))

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
        .background(Theme.cardBg)
    }

    // 遥测数据表头
    private var tableHeader: some View {
        HStack(spacing: 6) {
            Text(model.t("状态", "Status"))
                .frame(width: 24, alignment: .center)
            Text(model.t("类型", "Type"))
                .frame(width: 32, alignment: .center)
            Text(model.t("流标识", "Stream ID"))
                .frame(width: 105, alignment: .leading)
            Text(model.t("端点地址", "Endpoint"))
                .frame(width: 125, alignment: .leading)
            Text(model.t("音频规格", "Format"))
                .frame(width: 130, alignment: .leading)

            Spacer()

            Text(model.t("有效带宽", "Bandwidth"))
                .frame(width: 72, alignment: .trailing)
            Text(model.t("网络包率", "Packet Rate"))
                .frame(width: 64, alignment: .trailing)
            Text(model.t("丢包", "Missing"))
                .frame(width: 40, alignment: .trailing)
            Text(model.t("乱序", "Disorder"))
                .frame(width: 40, alignment: .trailing)
            Text(model.t("欠载", "Underrun"))
                .frame(width: 40, alignment: .trailing)
            Text(model.t("过载", "Overload"))
                .frame(width: 40, alignment: .trailing)
            Text(model.t("损坏", "Corrupt"))
                .frame(width: 40, alignment: .trailing)
            Text(model.t("网络抖动", "Jitter"))
                .frame(width: 56, alignment: .trailing)
        }
        .font(Theme.cnText(11, weight: .bold))
        .foregroundColor(Theme.textTertiary)
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(Theme.tableHeaderBg)
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
                ForEach(Array(model.txStreams.enumerated()), id: \.element.id) { idx, tx in
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
                .frame(width: 24, alignment: .center)

            Text("RX")
                .font(Theme.monoDigit(10.5, weight: .bold))
                .foregroundColor(Theme.neonCyan)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Theme.neonCyan.opacity(0.15))
                .cornerRadius(3)
                .frame(width: 32, alignment: .center)

            RollingLabel(text: strm.name, font: Theme.monoDigit(13, weight: .bold), color: Theme.textPrimary)
                .frame(width: 105, alignment: .leading)

            Button(action: {
                selectedPingIp = strm.srcIp
                showPingSheet = true
            }) {
                Text("\(strm.srcIp):\(strm.srcPort)")
                    .font(Theme.monoDigit(11.5, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 125, alignment: .leading)
            .help(model.t("点击查看端点 \(strm.srcIp) 的 VBAN Ping 属性", "Click to inspect VBAN Ping for \(strm.srcIp)"))

            formatCapsuleGroup(sr: strm.sampleRate, ch: strm.channels, bit: strm.bitDepth)
                .frame(width: 130, alignment: .leading)

            Spacer()

            Text("\(fmtKbps(strm.kbps)) kbps")
                .font(Theme.monoDigit(12, weight: .bold))
                .foregroundColor(Theme.neonCyan)
                .frame(width: 72, alignment: .trailing)

            Text("\(strm.packetsPerSec) pkt/s")
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 64, alignment: .trailing)

            Text("\(strm.lostCount)")
                .font(Theme.monoDigit(11.5, weight: .bold))
                .foregroundColor(strm.lostCount > 0 ? Theme.alertRed : Theme.meterGreen)
                .frame(width: 40, alignment: .trailing)

            Text("\(strm.orderErrorCount)")
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(strm.orderErrorCount > 0 ? Theme.amberWarn : Theme.textTertiary)
                .frame(width: 40, alignment: .trailing)

            Text("\(strm.underrunCount)")
                .font(Theme.monoDigit(11.5, weight: .bold))
                .foregroundColor(strm.underrunCount > 0 ? Theme.alertRed : Theme.textTertiary)
                .frame(width: 40, alignment: .trailing)

            Text("\(strm.overloadCount)")
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(strm.overloadCount > 0 ? Theme.amberWarn : Theme.textTertiary)
                .frame(width: 40, alignment: .trailing)

            Text("\(strm.corruptCount)")
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(strm.corruptCount > 0 ? Theme.alertRed : Theme.textTertiary)
                .frame(width: 40, alignment: .trailing)

            Text(String(format: "%.1f ms", strm.jitterMs))
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(strm.jitterMs > 20.0 ? Theme.amberWarn : Theme.meterGreen)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(idx % 2 == 0 ? Color.clear : Theme.rowAltBg)
    }

    // 发送流数据行
    private func txTelemetryRow(idx: Int, tx: VbanTxStreamDesc) -> some View {
        let m = model.metrics.txStreams.first(where: { $0.name == tx.name })
        let liveKbps = (m?.kbps ?? tx.kbps)
        let curKbps = tx.enabled ? (liveKbps > 0 ? liveKbps : tx.realKbps) : 0
        let pps = tx.enabled ? (m?.packetsPerSec ?? tx.packetsPerSec) : 0

        return HStack(spacing: 6) {
            StatusLed(isActive: tx.enabled)
                .frame(width: 24, alignment: .center)

            Text("TX")
                .font(Theme.monoDigit(10.5, weight: .bold))
                .foregroundColor(Theme.amberWarn)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Theme.amberWarn.opacity(0.15))
                .cornerRadius(3)
                .frame(width: 32, alignment: .center)

            RollingLabel(text: tx.name, font: Theme.monoDigit(13, weight: .bold), color: Theme.textPrimary)
                .frame(width: 105, alignment: .leading)

            Button(action: {
                selectedPingIp = tx.targetIp
                showPingSheet = true
            }) {
                Text("\(tx.targetIp):\(tx.targetPort)")
                    .font(Theme.monoDigit(11.5, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 125, alignment: .leading)
            .help(model.t("点击查看端点 \(tx.targetIp) 的 VBAN Ping 属性", "Click to inspect VBAN Ping for \(tx.targetIp)"))

            formatCapsuleGroup(sr: tx.sampleRate, ch: tx.channels, bit: tx.bitDepth)
                .frame(width: 130, alignment: .leading)

            Spacer()

            Text("\(fmtKbps(curKbps)) kbps")
                .font(Theme.monoDigit(12, weight: .bold))
                .foregroundColor(tx.enabled && curKbps > 0 ? Theme.neonCyan : Theme.textTertiary)
                .frame(width: 72, alignment: .trailing)

            Text("\(pps) pkt/s")
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(tx.enabled && pps > 0 ? Theme.textSecondary : Theme.textTertiary)
                .frame(width: 64, alignment: .trailing)

            Text("0")
                .font(Theme.monoDigit(11.5, weight: .bold))
                .foregroundColor(Theme.meterGreen)
                .frame(width: 40, alignment: .trailing)

            Text("-")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 40, alignment: .trailing)

            Text("-")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 40, alignment: .trailing)

            Text("-")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 40, alignment: .trailing)

            Text("0")
                .font(Theme.monoDigit(11.5, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 40, alignment: .trailing)

            Text(String(format: "%.1f ms", m?.jitterMs ?? 0.0))
                .font(Theme.monoDigit(11.5, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(idx % 2 == 0 ? Color.clear : Theme.rowAltBg)
    }

    // 空状态面板
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "speedometer")
                .font(.system(size: 28))
                .foregroundColor(Theme.textTertiary)

            Text(model.t("暂无活动音频流遥测数据", "No Active Stream Telemetry"))
                .font(Theme.cnText(13, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .help(model.t("当存在活动接收流或启用发送流时，此处将实时展示各流吞吐、微秒抖动与包率", "Active incoming and outgoing streams will display real-time throughput and loss here"))
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

    // 音频规格卡片组
    private func formatCapsuleGroup(sr: UInt32, ch: UInt32, bit: UInt32) -> some View {
        HStack(spacing: 4) {
            formatTag("\(sr / 1000)kHz")
            formatTag("\(ch)CH")
            formatTag("\(bit)bit")
        }
    }

    // 单个微型胶囊
    private func formatTag(_ text: String) -> some View {
        Text(text)
            .font(Theme.monoDigit(10.5, weight: .semibold))
            .foregroundColor(Theme.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(Theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .stroke(Theme.borderSubtle, lineWidth: 1)
            )
    }
}
