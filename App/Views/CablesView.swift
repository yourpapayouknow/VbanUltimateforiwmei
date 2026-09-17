import SwiftUI

struct CablesView: View {
    @ObservedObject var model: AppModel

    @State private var newCableName = "VBAN - PC A"
    @State private var newChannels: UInt32 = 2
    @State private var newSampleRate: UInt32 = 48000

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DYNAMIC VIRTUAL AUDIO CABLES")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.8))
                        Text("Manage macOS AudioServerPlugIn virtual cables. Devices are dynamically added and removed in real-time.")
                            .font(Theme.regularText(11))
                            .foregroundColor(Theme.mutedGray)
                    }
                    Spacer()
                    MicroCapsuleBadge(title: "\(model.cables.count) Cables Active", color: Theme.neonCyan)
                }

                Divider().background(Theme.borderSubtle)

                // 快速创建新虚拟线缆输入栏
                VStack(alignment: .leading, spacing: 12) {
                    Text("CREATE VIRTUAL CABLE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.amberGold)

                    HStack(spacing: 16) {
                        TextField("Cable Name (e.g. VBAN - PC A)", text: $newCableName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(8)
                            .background(Theme.surfaceBg)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .font(Theme.regularText(12))

                        Picker("Channels", selection: $newChannels) {
                            Text("Mono (1ch)").tag(UInt32(1))
                            Text("Stereo (2ch)").tag(UInt32(2))
                        }
                        .frame(width: 130)

                        Picker("Rate", selection: $newSampleRate) {
                            Text("44.1 kHz").tag(UInt32(44100))
                            Text("48.0 kHz").tag(UInt32(48000))
                            Text("96.0 kHz").tag(UInt32(96000))
                        }
                        .frame(width: 120)

                        Button(action: {
                            guard !newCableName.isEmpty else { return }
                            let cid = "cbl_\(UUID().uuidString.prefix(8).lowercased())"
                            _ = model.addCable(id: cid, name: newCableName, channels: newChannels, sampleRate: newSampleRate)
                            newCableName = ""
                        }) {
                            Text("Create Cable")
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

                // 已激活虚拟设备列表 (去卡片化行式布局)
                VStack(alignment: .leading, spacing: 12) {
                    Text("MANAGED COREAUDIO VIRTUAL DEVICES")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.6))

                    if model.cables.isEmpty {
                        Text("No virtual cables registered. Add a cable above to expose it to system audio.")
                            .font(Theme.regularText(12))
                            .foregroundColor(Theme.mutedGray)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(model.cables, id: \.cableId) { cbl in
                                HStack(spacing: 16) {
                                    Image(systemName: "cable.connector")
                                        .foregroundColor(Theme.neonCyan)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cbl.name)
                                            .font(Theme.regularText(13, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("UID: com.iwmei.vbanultimate.audio.\(cbl.cableId)")
                                            .font(Theme.monoDigit(10))
                                            .foregroundColor(Theme.mutedGray)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    MicroCapsuleBadge(title: "\(cbl.channels) CH", color: .white.opacity(0.8))
                                    MicroCapsuleBadge(title: "\(cbl.sampleRate / 1000) kHz", color: Theme.amberGold)
                                    MicroCapsuleBadge(title: "HAL Loopback", color: Theme.activeGreen)

                                    Button(action: {
                                        model.removeCable(id: cbl.cableId)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(Theme.offlineRed)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.vertical, 12)
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
