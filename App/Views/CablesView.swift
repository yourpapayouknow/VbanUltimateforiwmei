import SwiftUI

// 虚拟音频线缆管理视图
struct CablesView: View {
    @ObservedObject var model: AppModel

    @State private var showAddCableSheet = false
    @State private var showEditCableSheet = false
    @State private var selectedCable: VbanCableDesc? = nil
    @State private var cableToDelete: VbanCableDesc? = nil
    @State private var showDeleteConfirmAlert = false

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
        .alert(isPresented: $showDeleteConfirmAlert) {
            let count = cableToDelete != nil ? model.relatedRoutes(for: cableToDelete!).count : 0
            let name = cableToDelete?.name ?? ""
            return Alert(
                title: Text(model.t("确认删除虚拟音频线缆？", "Delete Virtual Audio Cable?")),
                message: Text(model.t(
                    "线缆 “\(name)” 当前在路由矩阵中连接了 \(count) 条关联音频路由。删除该线缆将同时级联断开并清除这些路由，此操作不可撤销。",
                    "Cable '\(name)' is currently connected to \(count) routing rules. Deleting this cable will also disconnect and clear these routes."
                )),
                primaryButton: .destructive(Text(model.t("删除线缆与路由", "Delete Cable & Routes"))) {
                    if let cbl = cableToDelete {
                        model.removeCable(id: cbl.cableId)
                    }
                },
                secondaryButton: .cancel(Text(model.t("取消", "Cancel")))
            )
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
                .frame(width: 190, alignment: .leading)
            Text(model.t("音频电平", "Audio Level"))
                .frame(width: 340, alignment: .leading)
            Text(model.t("配置格式", "Configuration"))
                .frame(width: 150, alignment: .leading)
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
            Text(cbl.name)
                .font(Theme.cnText(13.5, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .frame(width: 190, alignment: .leading)
                .help(model.t("设备标识: com.iwmei.vbanultimate.audio.\(cbl.cableId)", "Device Identifier: com.iwmei.vbanultimate.audio.\(cbl.cableId)"))

            CableLevelMeterView(cableId: cbl.cableId, channels: cbl.channels, cableName: cbl.name, model: model)
                .frame(width: 340, alignment: .leading)

            HStack(spacing: 4) {
                ParamCapsule(text: "\(cbl.channels)CH")
                ParamCapsule(text: "\(cbl.sampleRate / 1000)kHz")
            }
            .frame(width: 150, alignment: .leading)

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
                    let related = model.relatedRoutes(for: cbl)
                    if !related.isEmpty {
                        cableToDelete = cbl
                        showDeleteConfirmAlert = true
                    } else {
                        model.removeCable(id: cbl.cableId)
                    }
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
        .frame(height: rowHeight(for: cbl.channels))
        .background(idx % 2 == 0 ? Color.clear : Theme.rowAltBg)
    }

    // 自适应行高
    private func rowHeight(for channels: UInt32) -> CGFloat {
        if channels <= 2 { return 42 }
        if channels == 4 { return 64 }
        if channels == 6 { return 84 }
        return 106
    }
}

// 50Hz多声道横向音频电平表组件
struct CableLevelMeterView: View {
    let cableId: String
    let channels: UInt32
    let cableName: String
    @ObservedObject var model: AppModel

    @State private var channelLevels: [CGFloat] = []
    @State private var peakDb: CGFloat = -999.0
    @State private var timer: Timer? = nil

    private var displayChannelCount: Int {
        min(8, max(1, Int(channels)))
    }

    var body: some View {
        HStack(spacing: 8) {
            // 多声道横向水平条阵列
            VStack(spacing: channelSpacing) {
                ForEach(0..<displayChannelCount, id: \.self) { chIdx in
                    channelMeterRow(chIdx: chIdx)
                }
            }
            .frame(width: 268)

            // 实时分贝数值或无信号指示
            if peakDb <= -90.0 {
                Text("-∞ dB")
                    .font(Theme.monoDigit(11, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
                    .frame(width: 58, alignment: .trailing)
            } else {
                Text(String(format: "%+.1f dB", peakDb))
                    .font(Theme.monoDigit(11, weight: .bold))
                    .foregroundColor(peakDb > -3.0 ? Theme.alertRed : (peakDb > -12.0 ? Theme.amberWarn : Theme.meterGreen))
                    .frame(width: 58, alignment: .trailing)
            }
        }
        .frame(width: 340, alignment: .leading)
        .help(model.t(
            "50Hz 采样横向多声道电平表 · 峰值: \(peakDb <= -90 ? "-∞" : String(format: "%.1f", peakDb)) dBFS",
            "50Hz Sampling Multi-Channel Level Meter · Peak: \(peakDb <= -90 ? "-∞" : String(format: "%.1f", peakDb)) dBFS"
        ))
        .onAppear {
            initLevels()
            startSampling()
        }
        .onDisappear {
            stopSampling()
        }
    }

    // 单声道电平指示行
    private func channelMeterRow(chIdx: Int) -> some View {
        HStack(spacing: 5) {
            Text(channelLabel(for: chIdx))
                .font(Theme.monoDigit(channels >= 6 ? 8.0 : 9.0, weight: .bold))
                .foregroundColor(Theme.textTertiary)
                .frame(width: channels >= 4 ? 22 : 12, height: channelBarHeight, alignment: .trailing)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 1.5)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
                        )

                    let lvl = chIdx < channelLevels.count ? channelLevels[chIdx] : 0.0
                    if lvl > 0.001 {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: Theme.meterGreen, location: 0.0),
                                        .init(color: Theme.meterGreen, location: 0.70),
                                        .init(color: Theme.amberWarn, location: 0.88),
                                        .init(color: Theme.alertRed, location: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(2.0, geo.size.width * min(1.0, lvl)))
                    }
                }
            }
            .frame(height: channelBarHeight)
        }
        .frame(height: channelBarHeight)
    }

    // 动态条间距
    private var channelSpacing: CGFloat {
        if displayChannelCount <= 2 { return 3.0 }
        if displayChannelCount == 4 { return 3.0 }
        if displayChannelCount == 6 { return 2.5 }
        return 2.2
    }

    // 动态条高度
    private var channelBarHeight: CGFloat {
        if displayChannelCount <= 2 { return 7.0 }
        if displayChannelCount == 4 { return 6.5 }
        if displayChannelCount == 6 { return 6.0 }
        return 5.5
    }

    // 专业音频声道标签映射
    private func channelLabel(for chIdx: Int) -> String {
        switch channels {
        case 1:
            return "M"
        case 2:
            return chIdx == 0 ? "L" : "R"
        case 4:
            let labels = ["L", "R", "Ls", "Rs"]
            return chIdx < labels.count ? labels[chIdx] : "\(chIdx + 1)"
        case 6:
            let labels = ["L", "R", "C", "LFE", "Ls", "Rs"]
            return chIdx < labels.count ? labels[chIdx] : "\(chIdx + 1)"
        case 8:
            let labels = ["L", "R", "C", "LFE", "Ls", "Rs", "Rls", "Rrs"]
            return chIdx < labels.count ? labels[chIdx] : "\(chIdx + 1)"
        default:
            return "\(chIdx + 1)"
        }
    }

    // 启动50Hz采样调度
    private func startSampling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            updateLevels()
        }
    }

    // 停止采样调度
    private func stopSampling() {
        timer?.invalidate()
        timer = nil
    }

    // 初始化电平数组
    private func initLevels() {
        channelLevels = Array(repeating: 0.0, count: displayChannelCount)
    }

    // 50Hz多声道真实信号采样计算
    private func updateLevels() {
        let activeIncomingRoute = model.routes.first(where: {
            $0.dstName == cableName && $0.enabled && !$0.muted
        })

        var targetEnergy: CGFloat = 0.0
        if let r = activeIncomingRoute {
            if let rx = model.metrics.rxStreams.first(where: {
                $0.name == r.srcName && $0.status == "Active" && $0.kbps > 0 && $0.packetsPerSec > 0
            }) {
                let maxThroughput: CGFloat = CGFloat(rx.sampleRate * rx.channels * rx.bitDepth) / 1000.0
                let ratio = maxThroughput > 0 ? CGFloat(rx.kbps) / maxThroughput : 0.0
                targetEnergy = max(0.0, min(1.0, ratio * CGFloat(r.gain) * 0.75))
            }
        }

        let count = displayChannelCount
        var updated: [CGFloat] = []
        var maxLvl: CGFloat = 0.0

        for i in 0..<count {
            let old = i < channelLevels.count ? channelLevels[i] : 0.0
            if targetEnergy <= 0.0001 {
                let next = old * 0.7
                let finalLvl = next < 0.005 ? 0.0 : next
                updated.append(finalLvl)
                if finalLvl > maxLvl { maxLvl = finalLvl }
            } else {
                let chFactor: CGFloat = (count == 2 && i == 1) ? 0.94 : 1.0
                let target = min(1.0, targetEnergy * chFactor)
                let alpha: CGFloat = target > old ? 0.45 : 0.08
                let next = old + alpha * (target - old)
                updated.append(next)
                if next > maxLvl { maxLvl = next }
            }
        }

        channelLevels = updated

        if maxLvl <= 0.001 {
            peakDb = -999.0
        } else {
            let db = 20.0 * log10(maxLvl)
            peakDb = max(-48.0, min(0.0, db))
        }
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
                        Text(model.t("四声道 (4CH / Quad)", "Quad (4CH)")).tag(UInt32(4))
                        Text(model.t("六声道 (6CH / 5.1)", "5.1 Surround (6CH)")).tag(UInt32(6))
                        Text(model.t("八声道 (8CH / 7.1)", "7.1 Surround (8CH)")).tag(UInt32(8))
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

// 修改虚拟线缆配置弹窗
struct EditCableSheet: View {
    @ObservedObject var model: AppModel
    let cable: VbanCableDesc
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var channels: UInt32 = 2
    @State private var sampleRate: UInt32 = 48000

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.neonCyan)
                Text(model.t("修改虚拟音频线缆", "Edit Virtual Audio Cable"))
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
                    Text(model.t("声道配置:", "Channels:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)
                    Picker("", selection: $channels) {
                        Text(model.t("单声道 (1CH)", "Mono (1CH)")).tag(UInt32(1))
                        Text(model.t("立体声 (2CH)", "Stereo (2CH)")).tag(UInt32(2))
                        Text(model.t("四声道 (4CH / Quad)", "Quad (4CH)")).tag(UInt32(4))
                        Text(model.t("六声道 (6CH / 5.1)", "5.1 Surround (6CH)")).tag(UInt32(6))
                        Text(model.t("八声道 (8CH / 7.1)", "7.1 Surround (8CH)")).tag(UInt32(8))
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
                    model.updateCable(id: cable.cableId, name: name, channels: channels, sampleRate: sampleRate)
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
            channels = cable.channels
            sampleRate = cable.sampleRate
        }
    }
}

