import SwiftUI

struct CablesView: View {
    @ObservedObject var model: AppModel

    @State private var newCableName = "VBAN - PC A"
    @State private var newChannels: UInt32 = 2
    @State private var newSampleRate: UInt32 = 48000

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作工具条
            HStack(spacing: 12) {
                Text("虚拟音频线缆管理")
                    .font(Theme.cnText(12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                HStack(spacing: 8) {
                    Text("名称:")
                        .font(Theme.cnText(11))
                        .foregroundColor(Theme.textSecondary)

                    TextField("", text: $newCableName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(11))
                        .frame(width: 140)

                    Picker("声道", selection: $newChannels) {
                        Text("立体声 (2CH)").tag(UInt32(2))
                        Text("单声道 (1CH)").tag(UInt32(1))
                    }
                    .frame(width: 110)

                    Picker("采样率", selection: $newSampleRate) {
                        Text("44.1 kHz").tag(UInt32(44100))
                        Text("48.0 kHz").tag(UInt32(48000))
                        Text("96.0 kHz").tag(UInt32(96000))
                    }
                    .frame(width: 100)

                    Button(action: {
                        guard !newCableName.isEmpty else { return }
                        let cid = "cbl_\(UUID().uuidString.prefix(6).lowercased())"
                        _ = model.addCable(id: cid, name: newCableName, channels: newChannels, sampleRate: newSampleRate)
                        newCableName = ""
                    }) {
                        Label("新建线缆", systemImage: "plus")
                            .font(Theme.cnText(11, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.neonCyan)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.03))

            Divider().background(Theme.borderSubtle)

            // 表头
            HStack(spacing: 12) {
                Text("设备名称")
                    .frame(width: 180, alignment: .leading)
                Text("CoreAudio 设备唯一标识 (UID)")
                    .frame(width: 280, alignment: .leading)
                Text("配置")
                    .frame(width: 130, alignment: .leading)
                Text("驱动总线")
                    .frame(width: 90, alignment: .center)
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

            // 虚拟线缆列表
            if model.cables.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cable.connector.slash")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.textTertiary)
                    Text("当前系统无托管的虚拟音频线缆。可在右上角配置名称与格式后点击“新建线缆”。")
                        .font(Theme.cnText(11))
                        .foregroundColor(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(model.cables.enumerated()), id: \.element.cableId) { idx, cbl in
                            HStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "cable.connector")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.neonCyan)
                                    Text(cbl.name)
                                        .font(Theme.cnText(12, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                }
                                .frame(width: 180, alignment: .leading)

                                Text("com.iwmei.vbanultimate.audio.\(cbl.cableId)")
                                    .font(Theme.monoDigit(11))
                                    .foregroundColor(Theme.textTertiary)
                                    .frame(width: 280, alignment: .leading)

                                HStack(spacing: 4) {
                                    ParamCapsule(text: "\(cbl.channels) CH")
                                    ParamCapsule(text: "\(cbl.sampleRate / 1000) kHz", color: Theme.amberWarn)
                                }
                                .frame(width: 130, alignment: .leading)

                                Text("双向回环")
                                    .font(Theme.cnText(11))
                                    .foregroundColor(Theme.meterGreen)
                                    .frame(width: 90, alignment: .center)

                                Spacer()

                                Button(action: {
                                    model.removeCable(id: cbl.cableId)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.alertRed)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 40, alignment: .center)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
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
