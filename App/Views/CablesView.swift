import SwiftUI

// 虚拟音频线缆管理视图
struct CablesView: View {
    @ObservedObject var model: AppModel

    @State private var showAddCableSheet = false
    @State private var showEditCableSheet = false
    @State private var selectedCable: VbanCableDesc? = nil

    var body: some View {
        VStack(spacing: 0) {
            topToolbar

            Divider().background(Theme.borderSubtle)

            tableHeader

            Divider().background(Theme.borderSubtle)

            if model.cables.isEmpty {
                emptyState
            } else {
                cablesScrollView
            }
        }
        .background(Theme.windowBg)
        .sheet(isPresented: $showAddCableSheet) {
            AddCableSheet(model: model, isPresented: $showAddCableSheet)
        }
        .sheet(isPresented: $showEditCableSheet) {
            if let cable = selectedCable {
                EditCableSheet(model: model, cable: cable, isPresented: $showEditCableSheet)
            }
        }
    }

    // 顶部操作工具条
    private var topToolbar: some View {
        HStack(spacing: 8) {
            Text(model.t("虚拟音频线缆", "Virtual Audio Cables"))
                .font(Theme.cnText(14, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .help(model.t("基于 CoreAudio AudioServerPlugIn 架构的低延迟虚拟声卡管理", "Low-latency virtual audio cable management based on CoreAudio AudioServerPlugIn"))

            Spacer()

            Button(action: { showAddCableSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text(model.t("新建线缆", "Add Cable"))
                        .font(Theme.cnText(12, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.neonCyan.opacity(0.18))
                .foregroundColor(Theme.neonCyan)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Theme.neonCyan.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(model.t("新建一条由 CoreAudio 托管的双向虚拟音频线缆", "Create a new bidirectional virtual audio cable managed by CoreAudio"))
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(Color.white.opacity(0.03))
    }

    // 数据表头
    private var tableHeader: some View {
        HStack(spacing: 12) {
            Text(model.t("设备名称", "Device Name"))
                .frame(width: 220, alignment: .leading)
            Text(model.t("设备标识", "Device Identifier"))
                .frame(width: 360, alignment: .leading)
            Text(model.t("配置格式", "Configuration"))
                .frame(width: 160, alignment: .leading)
            Spacer()
            Text(model.t("操作", "Action"))
                .frame(width: 64, alignment: .center)
        }
        .font(Theme.cnText(12.5, weight: .bold))
        .foregroundColor(Theme.textTertiary)
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(Color.black.opacity(0.2))
    }

    // 空状态视图
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cable.connector.slash")
                .font(.system(size: 28))
                .foregroundColor(Theme.textTertiary)
            Text(model.t("无托管虚拟线缆", "No Virtual Cables"))
                .font(Theme.cnText(13.5, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .help(model.t("点击右上角 [+ 新建线缆] 即可向 CoreAudio HAL 动态注册虚拟声卡", "Click [+ Add Cable] to dynamically register virtual audio device with CoreAudio HAL"))
    }

    // 线缆列表滚动区
    private var cablesScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(model.cables.enumerated()), id: \.element.cableId) { idx, cbl in
                    cableRow(idx: idx, cbl: cbl)
                    Divider().background(Theme.borderSubtle)
                }
            }
        }
    }

    // 线缆单行项目
    private func cableRow(idx: Int, cbl: VbanCableDesc) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "cable.connector")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.neonCyan)
                Text(cbl.name)
                    .font(Theme.cnText(13.5, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
            }
            .frame(width: 220, alignment: .leading)

            Text("com.iwmei.vbanultimate.audio.\(cbl.cableId)")
                .font(Theme.monoDigit(12, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 360, alignment: .leading)
                .lineLimit(1)

            HStack(spacing: 4) {
                ParamCapsule(text: "\(cbl.channels)CH")
                ParamCapsule(text: "\(cbl.sampleRate / 1000)kHz")
            }
            .frame(width: 160, alignment: .leading)

            Spacer()

            HStack(spacing: 6) {
                // 修改重命名按钮
                Button(action: {
                    selectedCable = cbl
                    showEditCableSheet = true
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.neonCyan)
                        .frame(width: 22, height: 22)
                        .background(Theme.neonCyan.opacity(0.12))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.neonCyan.opacity(0.85), lineWidth: 1.2)
                        )
                }
                .buttonStyle(.plain)
                .help(model.t("修改/重命名此虚拟线缆设备", "Rename this virtual cable device"))

                // 删除按钮
                Button(action: {
                    model.removeCable(id: cbl.cableId)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.alertRed.opacity(0.8))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(model.t("删除该条虚拟线缆设备", "Remove this virtual cable device"))
            }
            .frame(width: 64, alignment: .center)
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(idx % 2 == 0 ? Color.clear : Theme.rowAltBg)
    }
}

// 新建虚拟线缆弹窗
struct AddCableSheet: View {
    @ObservedObject var model: AppModel
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var channels: UInt32 = 2
    @State private var sampleRate: UInt32 = 48000

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cable.connector")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.neonCyan)
                Text(model.t("新建虚拟音频线缆", "New Virtual Audio Cable"))
                    .font(Theme.cnText(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }

            Divider().background(Theme.borderSubtle)

            VStack(spacing: 12) {
                HStack {
                    Text(model.t("线缆名称:", "Cable Name:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)
                    TextField("", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(12.5, weight: .semibold))
                }

                HStack {
                    Text(model.t("声道配置:", "Channels:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)
                    Picker("", selection: $channels) {
                        Text(model.t("单声道 (1CH)", "Mono (1CH)")).tag(UInt32(1))
                        Text(model.t("立体声 (2CH)", "Stereo (2CH)")).tag(UInt32(2))
                        Text(model.t("四声道 (4CH)", "Quad (4CH)")).tag(UInt32(4))
                        Text(model.t("八声道 (8CH)", "8-Channel (8CH)")).tag(UInt32(8))
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                HStack {
                    Text(model.t("硬件采样率:", "Sample Rate:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)
                    Picker("", selection: $sampleRate) {
                        Text("44.1 kHz").tag(UInt32(44100))
                        Text("48.0 kHz").tag(UInt32(48000))
                        Text("96.0 kHz").tag(UInt32(96000))
                        Text("192.0 kHz").tag(UInt32(192000))
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }

            Divider().background(Theme.borderSubtle)

            HStack {
                Spacer()
                Button(model.t("取消", "Cancel")) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button(action: {
                    guard !name.isEmpty else { return }
                    let cid = "cbl_\(UUID().uuidString.prefix(6).lowercased())"
                    _ = model.addCable(id: cid, name: name, channels: channels, sampleRate: sampleRate)
                    isPresented = false
                }) {
                    Text(model.t("创建并注入", "Create & Register"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.neonCyan)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(Theme.windowBg)
        .onAppear {
            if name.isEmpty {
                let count = model.cables.count
                let letter = Character(UnicodeScalar(65 + (count % 26))!)
                name = "VBAN Cable \(letter)"
            }
        }
    }
}

// 重命名虚拟线缆弹窗
struct EditCableSheet: View {
    @ObservedObject var model: AppModel
    let cable: VbanCableDesc
    @Binding var isPresented: Bool

    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.neonCyan)
                Text(model.t("重命名虚拟音频线缆", "Rename Virtual Audio Cable"))
                    .font(Theme.cnText(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }

            Divider().background(Theme.borderSubtle)

            VStack(spacing: 12) {
                HStack {
                    Text(model.t("设备标识:", "Identifier:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 90, alignment: .trailing)
                    Text("com.iwmei.vbanultimate.audio.\(cable.cableId)")
                        .font(Theme.monoDigit(12, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                    Spacer()
                }

                HStack {
                    Text(model.t("线缆名称:", "Cable Name:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)
                    TextField("", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(12.5, weight: .semibold))
                }

                HStack {
                    Text(model.t("配置格式:", "Format:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 90, alignment: .trailing)
                    HStack(spacing: 4) {
                        ParamCapsule(text: "\(cable.channels)CH")
                        ParamCapsule(text: "\(cable.sampleRate / 1000)kHz")
                    }
                    Spacer()
                }
            }

            Divider().background(Theme.borderSubtle)

            HStack {
                Spacer()
                Button(model.t("取消", "Cancel")) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button(action: {
                    guard !name.isEmpty else { return }
                    model.renameCable(id: cable.cableId, newName: name)
                    isPresented = false
                }) {
                    Text(model.t("保存修改", "Save"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.neonCyan)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(Theme.windowBg)
        .onAppear {
            name = cable.name
        }
    }
}

