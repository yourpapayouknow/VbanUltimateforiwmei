import SwiftUI

struct MatrixView: View {
    @ObservedObject var model: AppModel

    @State private var selectedSrcId   = ""
    @State private var selectedSrcName = ""
    @State private var selectedDstId   = ""
    @State private var selectedDstName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AUDIO ROUTING MATRIX")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.8))
                        Text("Connect any Source (CoreAudio Input / Virtual Cable / VBAN RX) to any Destination (Output / Cable / TX).")
                            .font(Theme.regularText(11))
                            .foregroundColor(Theme.mutedGray)
                    }
                    Spacer()
                    MicroCapsuleBadge(title: "\(model.routes.count) Routes Active", color: Theme.neonCyan)
                }

                Divider().background(Theme.borderSubtle)

                // 快速添加新路由连接器
                VStack(alignment: .leading, spacing: 12) {
                    Text("CREATE NEW ROUTE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.amberGold)

                    HStack(spacing: 16) {
                        // 源选择
                        Menu {
                            Section("Physical Inputs") {
                                ForEach(model.devices.filter { $0.inChannels > 0 }, id: \.uid) { d in
                                    Button(d.name) {
                                        selectedSrcId = d.uid
                                        selectedSrcName = d.name
                                    }
                                }
                            }
                            Section("Virtual Cables") {
                                ForEach(model.cables, id: \.cableId) { c in
                                    Button(c.name) {
                                        selectedSrcId = c.cableId
                                        selectedSrcName = c.name
                                    }
                                }
                            }
                            Section("VBAN RX") {
                                ForEach(model.metrics.rxStreams, id: \.name) { s in
                                    Button("VBAN RX: \(s.name)") {
                                        selectedSrcId = s.name
                                        selectedSrcName = "VBAN RX (\(s.name))"
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedSrcName.isEmpty ? "Select Source..." : selectedSrcName)
                                    .font(Theme.regularText(12))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.mutedGray)
                            }
                            .padding(8)
                            .background(Theme.surfaceBg)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .frame(maxWidth: .infinity)

                        Image(systemName: "arrow.right")
                            .foregroundColor(Theme.neonCyan)
                            .font(.system(size: 14, weight: .bold))

                        // 目标选择
                        Menu {
                            Section("Physical Outputs") {
                                ForEach(model.devices.filter { $0.outChannels > 0 }, id: \.uid) { d in
                                    Button(d.name) {
                                        selectedDstId = d.uid
                                        selectedDstName = d.name
                                    }
                                }
                            }
                            Section("Virtual Cables") {
                                ForEach(model.cables, id: \.cableId) { c in
                                    Button(c.name) {
                                        selectedDstId = c.cableId
                                        selectedDstName = c.name
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedDstName.isEmpty ? "Select Destination..." : selectedDstName)
                                    .font(Theme.regularText(12))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.mutedGray)
                            }
                            .padding(8)
                            .background(Theme.surfaceBg)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .frame(maxWidth: .infinity)

                        Button(action: {
                            guard !selectedSrcId.isEmpty, !selectedDstId.isEmpty else { return }
                            model.addRoute(srcId: selectedSrcId, srcName: selectedSrcName,
                                           dstId: selectedDstId, dstName: selectedDstName, gain: 1.0)
                            selectedSrcId = ""
                            selectedSrcName = ""
                            selectedDstId = ""
                            selectedDstName = ""
                        }) {
                            Text("Connect")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Theme.neonCyan)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(14)
                .background(Theme.surfaceBg.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.borderSubtle, lineWidth: 1)
                )

                // 已激活路由列表 (去卡片化行式布局)
                VStack(alignment: .leading, spacing: 12) {
                    Text("ACTIVE MATRIX CONNECTIONS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.6))

                    if model.routes.isEmpty {
                        Text("No active cross-routes configured. Create a connection above to bridge audio streams.")
                            .font(Theme.regularText(12))
                            .foregroundColor(Theme.mutedGray)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(model.routes, id: \.routeId) { r in
                                HStack(spacing: 16) {
                                    Circle()
                                        .fill(r.enabled ? Theme.neonCyan : Theme.mutedGray)
                                        .frame(width: 8, height: 8)

                                    Text(r.srcName)
                                        .font(Theme.regularText(13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Theme.mutedGray)

                                    Text(r.dstName)
                                        .font(Theme.regularText(13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    MicroCapsuleBadge(title: String(format: "%.1f dB", (r.gain - 1.0) * 12.0), color: Theme.amberGold)

                                    Button(action: {
                                        model.toggleRoute(id: r.routeId, enabled: !r.enabled)
                                    }) {
                                        Image(systemName: r.enabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                            .foregroundColor(r.enabled ? Theme.activeGreen : Theme.mutedGray)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    Button(action: {
                                        model.removeRoute(id: r.routeId)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(Theme.offlineRed)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.vertical, 10)
                                Divider().background(Theme.borderSubtle)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}
