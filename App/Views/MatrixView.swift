import SwiftUI

struct MatrixView: View {
    @ObservedObject var model: AppModel

    @State private var selectedSrcId   = ""
    @State private var selectedSrcName = ""
    @State private var selectedDstId   = ""
    @State private var selectedDstName = ""

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏操作条
            HStack(spacing: 12) {
                Text("矩阵交叉连接")
                    .font(Theme.cnText(12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                // 源信号端点下拉
                Menu {
                    Section("物理输入设备") {
                        ForEach(model.devices.filter { $0.inChannels > 0 }, id: \.uid) { d in
                            Button("麦克风: \(d.name)") {
                                selectedSrcId = d.uid
                                selectedSrcName = d.name
                            }
                        }
                    }
                    Section("虚拟线缆输出") {
                        ForEach(model.cables, id: \.cableId) { c in
                            Button("线缆输出: \(c.name)") {
                                selectedSrcId = c.cableId
                                selectedSrcName = c.name
                            }
                        }
                    }
                    Section("网络接收流 (VBAN RX)") {
                        ForEach(model.metrics.rxStreams, id: \.name) { s in
                            Button("网络流: \(s.name)") {
                                selectedSrcId = s.name
                                selectedSrcName = "VBAN RX [\(s.name)]"
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 10))
                        Text(selectedSrcName.isEmpty ? "选择输入源..." : selectedSrcName)
                            .font(Theme.cnText(11))
                    }
                }
                .menuStyle(.borderedButton)
                .frame(width: 170)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textTertiary)

                // 目标端点下拉
                Menu {
                    Section("物理输出设备") {
                        ForEach(model.devices.filter { $0.outChannels > 0 }, id: \.uid) { d in
                            Button("扬声器: \(d.name)") {
                                selectedDstId = d.uid
                                selectedDstName = d.name
                            }
                        }
                    }
                    Section("虚拟线缆输入") {
                        ForEach(model.cables, id: \.cableId) { c in
                            Button("线缆输入: \(c.name)") {
                                selectedDstId = c.cableId
                                selectedDstName = c.name
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.and.arrow.down.left")
                            .font(.system(size: 10))
                        Text(selectedDstName.isEmpty ? "选择输出目标..." : selectedDstName)
                            .font(Theme.cnText(11))
                    }
                }
                .menuStyle(.borderedButton)
                .frame(width: 170)

                Button(action: {
                    guard !selectedSrcId.isEmpty, !selectedDstId.isEmpty else { return }
                    model.addRoute(srcId: selectedSrcId, srcName: selectedSrcName,
                                   dstId: selectedDstId, dstName: selectedDstName, gain: 1.0)
                    selectedSrcId = ""
                    selectedSrcName = ""
                    selectedDstId = ""
                    selectedDstName = ""
                }) {
                    Label("建立路由", systemImage: "link")
                        .font(Theme.cnText(11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.neonCyan)
                .disabled(selectedSrcId.isEmpty || selectedDstId.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.03))

            Divider().background(Theme.borderSubtle)

            // 表头
            HStack(spacing: 12) {
                Text("状态")
                    .frame(width: 40, alignment: .center)
                Text("输入源 (Source)")
                    .frame(width: 200, alignment: .leading)
                Text("")
                    .frame(width: 20, alignment: .center)
                Text("输出目标 (Destination)")
                    .frame(width: 200, alignment: .leading)
                Text("路由增益")
                    .frame(width: 130, alignment: .center)
                Text("静音")
                    .frame(width: 50, alignment: .center)
                Spacer()
                Text("操作")
                    .frame(width: 40, alignment: .center)
            }
            .font(Theme.cnText(11, weight: .semibold))
            .foregroundColor(Theme.textTertiary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.2))

            Divider().background(Theme.borderSubtle)

            // 路由规则列表
            if model.routes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.textTertiary)
                    Text("当前矩阵无活动路由连接。请在上方选择输入源与输出目标后点击“建立路由”。")
                        .font(Theme.cnText(11))
                        .foregroundColor(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(model.routes.enumerated()), id: \.element.routeId) { idx, r in
                            HStack(spacing: 12) {
                                StatusLed(isActive: r.enabled, activeColor: Theme.neonCyan)
                                    .frame(width: 40, alignment: .center)

                                Text(r.srcName)
                                    .font(Theme.cnText(12, weight: .medium))
                                    .foregroundColor(Theme.textPrimary)
                                    .frame(width: 200, alignment: .leading)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Theme.textTertiary)
                                    .frame(width: 20, alignment: .center)

                                Text(r.dstName)
                                    .font(Theme.cnText(12, weight: .medium))
                                    .foregroundColor(Theme.textPrimary)
                                    .frame(width: 200, alignment: .leading)

                                HStack(spacing: 6) {
                                    Text(String(format: "%+.1f dB", (r.gain - 1.0) * 12.0))
                                        .font(Theme.monoDigit(11))
                                        .foregroundColor(Theme.neonCyan)
                                        .frame(width: 55, alignment: .trailing)

                                    Slider(value: Binding(
                                        get: { r.gain },
                                        set: { newVal in
                                            // 预留微调
                                        }
                                    ), in: 0.0...2.0)
                                    .frame(width: 65)
                                }
                                .frame(width: 130, alignment: .center)

                                Button(action: {
                                    model.toggleRoute(id: r.routeId, enabled: !r.enabled)
                                }) {
                                    Image(systemName: r.enabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(r.enabled ? Theme.meterGreen : Theme.textTertiary)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 50, alignment: .center)

                                Spacer()

                                Button(action: {
                                    model.removeRoute(id: r.routeId)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.alertRed)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 40, alignment: .center)
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
