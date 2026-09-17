import SwiftUI

struct StreamsView: View {
    @ObservedObject var model: AppModel
    @State private var showAddTxSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // 固定高度双列操作顶栏 (40pt)
            HStack(spacing: 0) {
                // 左侧表头：接收流 RX
                HStack(spacing: 8) {
                    Text(model.t("接收流 RX", "Incoming Streams RX"))
                        .font(Theme.cnText(16.5, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .help(model.t("局域网内向本机传输的 VBAN 接收流", "Incoming audio streams received from the local network"))

                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 右侧表头：发送流 TX
                HStack(spacing: 8) {
                    Text(model.t("发送流 TX", "Outgoing Streams TX"))
                        .font(Theme.cnText(16.5, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .help(model.t("从本机音频源采集并推向局域网的音频流", "Locally captured audio streams transmitted over the network"))

                    Spacer()

                    Button(action: { showAddTxSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text(model.t("新建发送流", "Add Stream"))
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
                    .help(model.t("新建一条向外部网络传输的 VBAN 音频发送通道", "Configure and add a new outgoing VBAN stream"))
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 40)
            .background(Color.white.opacity(0.03))

            Divider().background(Theme.borderSubtle)

            // 双列内容区：左侧接收，右侧发送
            HStack(spacing: 0) {
                // 左列：接收流 (RX)
                VStack(spacing: 0) {
                    if model.metrics.rxStreams.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "waveform.badge.magnifyingglass")
                                .font(.system(size: 26))
                                .foregroundColor(Theme.textTertiary)
                            Text(model.t("等待网络音频流接入...", "Waiting for incoming streams..."))
                                .font(Theme.cnText(13, weight: .semibold))
                                .foregroundColor(Theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .help(model.t("局域网设备向本机 UDP 6980 发送音频包时将自动显示在此", "Streams sent to UDP 6980 will appear here automatically"))
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(model.metrics.rxStreams, id: \.name) { strm in
                                    RxStreamCard(strm: strm, model: model)
                                }
                            }
                            .padding(12)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().background(Theme.borderSubtle)

                // 右列：发送流 (TX)
                VStack(spacing: 0) {
                    if model.txStreams.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.up.forward.circle")
                                .font(.system(size: 26))
                                .foregroundColor(Theme.textTertiary)
                            Text(model.t("暂无发送通道", "No Outgoing Streams"))
                                .font(Theme.cnText(13, weight: .semibold))
                                .foregroundColor(Theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .help(model.t("点击右上角 [+ 新建发送流] 创建向网络推送音频的通道", "Click [+ Add Stream] to create outgoing audio stream"))
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(model.txStreams) { tx in
                                    TxStreamCard(tx: tx, model: model)
                                }
                            }
                            .padding(12)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.windowBg)
        .sheet(isPresented: $showAddTxSheet) {
            AddTxStreamSheet(model: model, isPresented: $showAddTxSheet)
        }
    }
}

// 接收流规范化隐形卡片
struct RxStreamCard: View {
    let strm: VbanStrmMetric
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 卡片顶栏：状态 + 流名称 + 采样格式胶囊
            HStack(spacing: 8) {
                StatusLed(isActive: strm.status == "Active")

                Text(strm.name)
                    .font(Theme.monoDigit(13.5, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                ParamCapsule(text: "\(strm.sampleRate / 1000)kHz")
                ParamCapsule(text: "\(strm.channels)CH")
                ParamCapsule(text: "16-bit")
            }

            Divider().background(Color.white.opacity(0.06))

            // 卡片底栏：远端来源 + 吞吐速率 + 丢包抖动
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                    Text("\(strm.srcIp):\(strm.srcPort)")
                        .font(Theme.monoDigit(12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("\(strm.kbps) kbps")
                        .font(Theme.monoDigit(12, weight: .bold))
                        .foregroundColor(Theme.neonCyan)
                    Text("(\(strm.packetsPerSec)p/s)")
                        .font(Theme.monoDigit(11, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("丢:\(strm.lostCount)")
                        .font(Theme.monoDigit(11.5, weight: .bold))
                        .foregroundColor(strm.lostCount > 0 ? Theme.alertRed : Theme.meterGreen)
                    Text("·")
                        .foregroundColor(Theme.textTertiary)
                    Text(String(format: "%.1fms", strm.jitterMs))
                        .font(Theme.monoDigit(11.5, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// 发送流规范化隐形卡片
struct TxStreamCard: View {
    let tx: VbanTxStreamDesc
    @ObservedObject var model: AppModel
    @State private var showEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 卡片顶栏：状态 + 流名称 + 格式胶囊 + 启停/修改/删除按钮
            HStack(spacing: 8) {
                StatusLed(isActive: tx.enabled, activeColor: Theme.meterGreen, offlineColor: Theme.alertRed)

                Text(tx.name)
                    .font(Theme.monoDigit(13.5, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                ParamCapsule(text: "\(tx.sampleRate / 1000)kHz")
                ParamCapsule(text: "\(tx.channels)CH")
                ParamCapsule(text: "\(tx.bitDepth)b")

                // 启停按钮
                Button(action: { model.toggleTxStream(id: tx.id) }) {
                    Image(systemName: tx.enabled ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(tx.enabled ? Theme.amberWarn : Theme.meterGreen)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(model.t(tx.enabled ? "暂停此发送流" : "启动此发送流", tx.enabled ? "Pause outgoing stream" : "Start outgoing stream"))

                // 修改按钮（放在删除按钮旁边）
                Button(action: { showEditSheet = true }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.neonCyan)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(model.t("修改此发送流配置", "Edit outgoing stream settings"))

                // 删除按钮
                Button(action: { model.removeTxStream(id: tx.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.alertRed.opacity(0.8))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(model.t("删除此发送流通道", "Remove this outgoing stream"))
            }

            Divider().background(Color.white.opacity(0.06))

            // 卡片底栏：音频源（左）-> 箭头与真实带宽叠加（中）-> 目标 IP（右）
            HStack(spacing: 8) {
                // 左侧：音频源
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.amberWarn)
                    Text(tx.sourceName)
                        .font(Theme.cnText(12, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                }
                .frame(minWidth: 80, maxWidth: 110, alignment: .leading)

                // 正中间：横向箭头，真实带宽叠加显示在横线上
                ZStack {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(tx.enabled ? Theme.neonCyan.opacity(0.35) : Color.white.opacity(0.12))
                            .frame(height: 1.5)
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 6))
                            .rotationEffect(.degrees(90))
                            .foregroundColor(tx.enabled ? Theme.neonCyan : Theme.textTertiary)
                            .offset(x: -2)
                    }

                    // 带宽胶囊叠加在横线上
                    Text(tx.enabled ? "\(tx.realKbps) kbps" : model.t("已暂停", "Paused"))
                        .font(Theme.monoDigit(11, weight: .bold))
                        .foregroundColor(tx.enabled ? Theme.meterGreen : Theme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Color(red: 0.14, green: 0.14, blue: 0.15))
                        .cornerRadius(3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(tx.enabled ? Theme.meterGreen.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .frame(maxWidth: .infinity)

                // 最右侧：目标 IP 地址（无端口，无地球图标）
                Text(tx.targetIp)
                    .font(Theme.monoDigit(12.5, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(minWidth: 90, maxWidth: 120, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .sheet(isPresented: $showEditSheet) {
            EditTxStreamSheet(model: model, tx: tx, isPresented: $showEditSheet)
        }
    }
}

// 修改发送流配置面板
struct EditTxStreamSheet: View {
    @ObservedObject var model: AppModel
    let tx: VbanTxStreamDesc
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var source: String = ""
    @State private var targetIp: String = ""
    @State private var targetPort: String = ""
    @State private var sampleRate: UInt32 = 48000
    @State private var channels: UInt32 = 2
    @State private var bitDepth: UInt32 = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.neonCyan)
                Text(model.t("修改 VBAN 发送流配置", "Edit VBAN Outgoing Stream"))
                    .font(Theme.cnText(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }

            Divider().background(Theme.borderSubtle)

            VStack(spacing: 12) {
                HStack {
                    Text(model.t("流名称:", "Stream Name:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)
                    TextField("", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(12.5, weight: .semibold))
                }

                HStack {
                    Text(model.t("采集源:", "Source Audio:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)
                    Picker("", selection: $source) {
                        ForEach(model.cables, id: \.name) { c in
                            Text(model.t("线缆: \(c.name)", "Cable: \(c.name)")).tag(c.name)
                        }
                        ForEach(model.devices, id: \.name) { d in
                            Text(model.t("设备: \(d.name)", "Device: \(d.name)")).tag(d.name)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                HStack {
                    Text(model.t("目标 IP:", "Target IP:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)
                    TextField("", text: $targetIp)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(12.5, weight: .semibold))
                }

                HStack {
                    Text(model.t("目标端口:", "Target Port:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)
                    TextField("", text: $targetPort)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(12.5, weight: .semibold))
                }

                HStack {
                    Text(model.t("采样规格:", "Format:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)

                    Picker("", selection: $sampleRate) {
                        Text("44.1 kHz").tag(UInt32(44100))
                        Text("48.0 kHz").tag(UInt32(48000))
                        Text("96.0 kHz").tag(UInt32(96000))
                    }
                    .pickerStyle(MenuPickerStyle())

                    Picker("", selection: $channels) {
                        Text(model.t("1 声道", "1 CH")).tag(UInt32(1))
                        Text(model.t("2 声道", "2 CH")).tag(UInt32(2))
                        Text(model.t("4 声道", "4 CH")).tag(UInt32(4))
                        Text(model.t("8 声道", "8 CH")).tag(UInt32(8))
                    }
                    .pickerStyle(MenuPickerStyle())

                    Picker("", selection: $bitDepth) {
                        Text("16-bit").tag(UInt32(16))
                        Text("24-bit").tag(UInt32(24))
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
                    let p = UInt16(targetPort) ?? tx.targetPort
                    let src = source.isEmpty ? tx.sourceName : source
                    model.updateTxStream(id: tx.id, name: name, sourceName: src, targetIp: targetIp, targetPort: p, sampleRate: sampleRate, channels: channels, bitDepth: bitDepth)
                    isPresented = false
                }) {
                    Text(model.t("保存配置", "Save Settings"))
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
            name = tx.name
            source = tx.sourceName
            targetIp = tx.targetIp
            targetPort = String(tx.targetPort)
            sampleRate = tx.sampleRate
            channels = tx.channels
            bitDepth = tx.bitDepth
        }
    }
}

// 新建发送流原生配置面板
struct AddTxStreamSheet: View {
    @ObservedObject var model: AppModel
    @Binding var isPresented: Bool

    @State private var name = "StreamOut"
    @State private var source = ""
    @State private var targetIp = "192.168.1.50"
    @State private var targetPort = "6980"
    @State private var sampleRate: UInt32 = 48000
    @State private var channels: UInt32 = 2
    @State private var bitDepth: UInt32 = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.amberWarn)
                Text(model.t("新建 VBAN 音频发送流", "New VBAN Outgoing Stream"))
                    .font(Theme.cnText(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }

            Divider().background(Theme.borderSubtle)

            VStack(spacing: 12) {
                HStack {
                    Text(model.t("流名称:", "Stream Name:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)
                    TextField("", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(12.5, weight: .semibold))
                }

                HStack {
                    Text(model.t("采集源:", "Source Audio:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)
                    Picker("", selection: $source) {
                        ForEach(model.cables, id: \.name) { c in
                            Text(model.t("线缆: \(c.name)", "Cable: \(c.name)")).tag(c.name)
                        }
                        ForEach(model.devices, id: \.name) { d in
                            Text(model.t("设备: \(d.name)", "Device: \(d.name)")).tag(d.name)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                HStack {
                    Text(model.t("目标 IP:", "Target IP:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)
                    TextField("", text: $targetIp)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(12.5, weight: .semibold))
                }

                HStack {
                    Text(model.t("目标端口:", "Target Port:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)
                    TextField("", text: $targetPort)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Theme.monoDigit(12.5, weight: .semibold))
                }

                HStack {
                    Text(model.t("采样规格:", "Format:"))
                        .font(Theme.cnText(12.5, weight: .semibold))
                        .frame(width: 90, alignment: .trailing)

                    Picker("", selection: $sampleRate) {
                        Text("44.1 kHz").tag(UInt32(44100))
                        Text("48.0 kHz").tag(UInt32(48000))
                        Text("96.0 kHz").tag(UInt32(96000))
                    }
                    .pickerStyle(MenuPickerStyle())

                    Picker("", selection: $channels) {
                        Text(model.t("1 声道", "1 CH")).tag(UInt32(1))
                        Text(model.t("2 声道", "2 CH")).tag(UInt32(2))
                        Text(model.t("4 声道", "4 CH")).tag(UInt32(4))
                        Text(model.t("8 声道", "8 CH")).tag(UInt32(8))
                    }
                    .pickerStyle(MenuPickerStyle())

                    Picker("", selection: $bitDepth) {
                        Text("16-bit").tag(UInt32(16))
                        Text("24-bit").tag(UInt32(24))
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
                    let p = UInt16(targetPort) ?? 6980
                    let src = source.isEmpty ? (model.cables.first?.name ?? "VBAN Cable A") : source
                    model.addTxStream(name: name, sourceName: src, targetIp: targetIp, targetPort: p, sampleRate: sampleRate, channels: channels, bitDepth: bitDepth)
                    isPresented = false
                }) {
                    Text(model.t("创建并启用", "Create & Enable"))
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
            if source.isEmpty {
                source = model.cables.first?.name ?? model.devices.first?.name ?? "VBAN Cable A"
            }
        }
    }
}

