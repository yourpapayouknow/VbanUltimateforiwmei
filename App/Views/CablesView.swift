import SwiftUI

struct CablesView: View {
    @ObservedObject var model: AppModel

    @State private var newCableName = "VBAN - PC A"
    @State private var newChannels: UInt32 = 2
    @State private var newSampleRate: UInt32 = 48000

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作工具条 (固定高度 40pt)
            HStack(spacing: 12) {
                Text(model.t("虚拟音频线缆", "Virtual Audio Cables"))
                    .font(Theme.cnText(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .help(model.t("基于 CoreAudio AudioServerPlugIn 架构的低延迟虚拟声卡管理", "Low-latency virtual audio cable management based on CoreAudio AudioServerPlugIn"))

                Spacer()

                HStack(spacing: 8) {
                    Text(model.t("名称:", "Name:"))
                        .font(Theme.cnText(12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)

                    TextField("", text: $newCableName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(12.5, weight: .semibold))
                        .frame(width: 130)
                        .help(model.t("虚拟音频设备在系统中显示的名称", "Virtual audio device display name in macOS"))

                    Picker("", selection: $newChannels) {
                        Text(model.t("立体声 (2CH)", "Stereo (2CH)")).tag(UInt32(2))
                        Text(model.t("单声道 (1CH)", "Mono (1CH)")).tag(UInt32(1))
                    }
                    .font(Theme.cnText(12))
                    .frame(width: 120)
                    .help(model.t("虚拟线缆的声道数量", "Channel count for virtual cable"))

                    Picker("", selection: $newSampleRate) {
                        Text("44.1 kHz").tag(UInt32(44100))
                        Text("48.0 kHz").tag(UInt32(48000))
                        Text("96.0 kHz").tag(UInt32(96000))
                    }
                    .font(Theme.cnText(12))
                    .frame(width: 100)
                    .help(model.t("虚拟线缆运行的硬件采样率", "Virtual cable hardware sample rate"))

                    Button(action: {
                        guard !newCableName.isEmpty else { return }
                        let cid = "cbl_\(UUID().uuidString.prefix(6).lowercased())"
                        _ = model.addCable(id: cid, name: newCableName, channels: newChannels, sampleRate: newSampleRate)
                        newCableName = ""
                    }) {
                        Label(model.t("新建线缆", "Add Cable"), systemImage: "plus")
                            .font(Theme.cnText(12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.neonCyan)
                    .help(model.t("动态创建并向 CoreAudio HAL 注册虚拟声卡设备", "Dynamically create and register virtual audio device with CoreAudio HAL"))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(Color.white.opacity(0.03))

            Divider().background(Theme.borderSubtle)

            // 表头 (固定高度 30pt)
            HStack(spacing: 12) {
                Text(model.t("设备名称", "Device Name"))
                    .frame(width: 190, alignment: .leading)
                Text(model.t("设备标识", "Device Identifier"))
                    .frame(width: 290, alignment: .leading)
                Text(model.t("配置格式", "Configuration"))
                    .frame(width: 140, alignment: .leading)
                Text(model.t("驱动总线", "Driver Bus"))
                    .frame(width: 90, alignment: .center)
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

            // 虚拟线缆列表
            if model.cables.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cable.connector.slash")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.textTertiary)
                    Text(model.t("无托管虚拟线缆", "No Virtual Cables"))
                        .font(Theme.cnText(14, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .help(model.t("在上方工具栏配置名称与声道后点击“新建线缆”即可动态注入系统", "Configure name and format above and click Add Cable to register"))
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(model.cables.enumerated()), id: \.element.cableId) { idx, cbl in
                            HStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "cable.connector")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.neonCyan)
                                    Text(cbl.name)
                                        .font(Theme.cnText(13.5, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                }
                                .frame(width: 190, alignment: .leading)

                                Text("com.iwmei.vbanultimate.audio.\(cbl.cableId)")
                                    .font(Theme.monoDigit(12, weight: .medium))
                                    .foregroundColor(Theme.textTertiary)
                                    .frame(width: 290, alignment: .leading)

                                HStack(spacing: 4) {
                                    ParamCapsule(text: "\(cbl.channels) CH")
                                    ParamCapsule(text: "\(cbl.sampleRate / 1000) kHz", color: Theme.amberWarn)
                                }
                                .frame(width: 140, alignment: .leading)

                                Text(model.t("双向回环", "Loopback"))
                                    .font(Theme.cnText(12.5, weight: .semibold))
                                    .foregroundColor(Theme.meterGreen)
                                    .frame(width: 90, alignment: .center)

                                Spacer()

                                Button(action: {
                                    model.removeCable(id: cbl.cableId)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.alertRed)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 44, alignment: .center)
                                .help(model.t("删除该条虚拟线缆设备", "Remove this virtual cable device"))
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
