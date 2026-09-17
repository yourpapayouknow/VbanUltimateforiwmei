import SwiftUI

struct MatrixView: View {
    @ObservedObject var model: AppModel

    @State private var selectedSrcId   = ""
    @State private var selectedSrcName = ""
    @State private var selectedDstId   = ""
    @State private var selectedDstName = ""

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏操作条 (固定高度 40pt)
            HStack(spacing: 12) {
                Text(model.t("路由矩阵", "Routing Matrix"))
                    .font(Theme.cnText(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .help(model.t("在物理声卡、虚拟音频线缆与 VBAN 网络流之间建立任意通道交汇", "Interconnect physical audio devices, virtual cables, and VBAN network streams"))

                Spacer()

                // 源信号端点下拉
                Menu {
                    Section(model.t("物理输入设备", "Physical Inputs")) {
                        ForEach(model.devices.filter { $0.inChannels > 0 }, id: \.uid) { d in
                            Button(d.name) {
                                selectedSrcId = d.uid
                                selectedSrcName = d.name
                            }
                        }
                    }
                    Section(model.t("虚拟线缆输出", "Virtual Cable Outputs")) {
                        ForEach(model.cables, id: \.cableId) { c in
                            Button(c.name) {
                                selectedSrcId = c.cableId
                                selectedSrcName = c.name
                            }
                        }
                    }
                    Section(model.t("网络接收流", "Network Incoming Streams")) {
                        ForEach(model.metrics.rxStreams, id: \.name) { s in
                            Button(s.name) {
                                selectedSrcId = s.name
                                selectedSrcName = "VBAN [\(s.name)]"
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 11))
                        Text(selectedSrcName.isEmpty ? model.t("选择输入源...", "Select Source...") : selectedSrcName)
                            .font(Theme.cnText(12.5, weight: .semibold))
                    }
                }
                .menuStyle(.borderedButton)
                .frame(width: 180)
                .help(model.t("选择信号输入源端点", "Select audio signal source endpoint"))

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.textTertiary)

                // 目标端点下拉
                Menu {
                    Section(model.t("物理输出设备", "Physical Outputs")) {
                        ForEach(model.devices.filter { $0.outChannels > 0 }, id: \.uid) { d in
                            Button(d.name) {
                                selectedDstId = d.uid
                                selectedDstName = d.name
                            }
                        }
                    }
                    Section(model.t("虚拟线缆输入", "Virtual Cable Inputs")) {
                        ForEach(model.cables, id: \.cableId) { c in
                            Button(c.name) {
                                selectedDstId = c.cableId
                                selectedDstName = c.name
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.and.arrow.down.left")
                            .font(.system(size: 11))
                        Text(selectedDstName.isEmpty ? model.t("选择输出目标...", "Select Destination...") : selectedDstName)
                            .font(Theme.cnText(12.5, weight: .semibold))
                    }
                }
                .menuStyle(.borderedButton)
                .frame(width: 180)
                .help(model.t("选择信号输出目标端点", "Select audio signal destination endpoint"))

                Button(action: {
                    guard !selectedSrcId.isEmpty, !selectedDstId.isEmpty else { return }
                    model.addRoute(srcId: selectedSrcId, srcName: selectedSrcName,
                                   dstId: selectedDstId, dstName: selectedDstName, gain: 1.0)
                    selectedSrcId = ""
                    selectedSrcName = ""
                    selectedDstId = ""
                    selectedDstName = ""
                }) {
                    Label(model.t("建立路由", "Connect"), systemImage: "link")
                        .font(Theme.cnText(12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.neonCyan)
                .disabled(selectedSrcId.isEmpty || selectedDstId.isEmpty)
                .help(model.t("建立输入源到输出目标的交叉连接路由", "Establish cross-point route from source to destination"))
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(Color.white.opacity(0.03))

            Divider().background(Theme.borderSubtle)

            // 表头 (固定高度 30pt)
            HStack(spacing: 12) {
                Text(model.t("状态", "Status"))
                    .frame(width: 44, alignment: .center)
                Text(model.t("输入源", "Source"))
                    .frame(width: 210, alignment: .leading)
                Text("")
                    .frame(width: 20, alignment: .center)
                Text(model.t("输出目标", "Destination"))
                    .frame(width: 210, alignment: .leading)
                Text(model.t("路由增益", "Gain"))
                    .frame(width: 140, alignment: .center)
                Text(model.t("静音", "Mute"))
                    .frame(width: 50, alignment: .center)
                Spacer()
                Text(model.t("操作", "Action"))
                    .frame(width: 44, alignment: .center)
            }
            .font(Theme.cnText(12.5, weight: .bold))
            .foregroundColor(Theme.textTertiary)
            .padding(.horizontal, 16)
            .frame(height: 30)
            .background(Color.black.opacity(0.2))

            Divider().background(Theme.borderSubtle)

            // 路由规则列表
            if model.routes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.textTertiary)
                    Text(model.t("无活动路由连接", "No Active Routes"))
                        .font(Theme.cnText(14, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .help(model.t("在上方工具栏选择输入源与输出目标后点击“建立路由”即可添加通道连接", "Select source and destination above and click Connect to add route"))
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(model.routes.enumerated()), id: \.element.routeId) { idx, r in
                            HStack(spacing: 12) {
                                StatusLed(isActive: r.enabled, activeColor: Theme.neonCyan)
                                    .frame(width: 44, alignment: .center)

                                Text(r.srcName)
                                    .font(Theme.cnText(13.5, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                    .frame(width: 210, alignment: .leading)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Theme.textTertiary)
                                    .frame(width: 20, alignment: .center)

                                Text(r.dstName)
                                    .font(Theme.cnText(13.5, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                    .frame(width: 210, alignment: .leading)

                                HStack(spacing: 6) {
                                    Text(String(format: "%+.1f dB", (r.gain - 1.0) * 12.0))
                                        .font(Theme.monoDigit(12.5, weight: .bold))
                                        .foregroundColor(Theme.neonCyan)
                                        .frame(width: 60, alignment: .trailing)

                                    Slider(value: Binding(
                                        get: { r.gain },
                                        set: { newVal in }
                                    ), in: 0.0...2.0)
                                    .frame(width: 70)
                                    .help(model.t("调节通道增益 (-12dB 至 +12dB)", "Adjust route channel gain (-12dB to +12dB)"))
                                }
                                .frame(width: 140, alignment: .center)

                                Button(action: {
                                    model.toggleRoute(id: r.routeId, enabled: !r.enabled)
                                }) {
                                    Image(systemName: r.enabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(r.enabled ? Theme.meterGreen : Theme.textTertiary)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 50, alignment: .center)
                                .help(model.t("切换通道静音状态", "Toggle channel mute"))

                                Spacer()

                                Button(action: {
                                    model.removeRoute(id: r.routeId)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.alertRed)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 44, alignment: .center)
                                .help(model.t("删除该条路由连接", "Delete this routing connection"))
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
        .background(Theme.windowBg)
    }
}
