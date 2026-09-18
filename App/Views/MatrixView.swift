import SwiftUI

// 视图展示模式
enum MatrixViewMode: String, CaseIterable {
    case list
    case matrix
}

// 矩阵槽位端点描述
struct MatrixSlot: Identifiable, Equatable {
    var id: String
    var endpointId: String
    var name: String
    var typeDesc: String
    var iconName: String
}

struct MatrixView: View {
    @ObservedObject var model: AppModel

    @State private var viewMode: MatrixViewMode = .list
    @State private var showAddRouteSheet = false
    @Namespace private var viewSwitcherAnimation

    // 矩阵输入输出槽位
    @State private var inputSlots: [MatrixSlot] = []
    @State private var outputSlots: [MatrixSlot] = []
    @State private var isInitialized = false

    var body: some View {
        VStack(spacing: 0) {
            topToolbar

            Divider().background(Theme.borderSubtle)

            if viewMode == .list {
                MatrixListView(model: model)
            } else {
                MatrixCanvasView(
                    model: model,
                    inputSlots: $inputSlots,
                    outputSlots: $outputSlots,
                    onOpenAddSheet: { showAddRouteSheet = true }
                )
            }
        }
        .background(Theme.windowBg)
        .sheet(isPresented: $showAddRouteSheet) {
            AddRouteSheet(model: model, isPresented: $showAddRouteSheet)
        }
        .onAppear {
            if !isInitialized {
                initSlots()
                isInitialized = true
            }
        }
    }

    // 顶部操作工具栏
    private var topToolbar: some View {
        HStack(spacing: 12) {
            // 视图切换胶囊
            viewModeCapsule

            Spacer()

            // 建立路由按钮
            addRouteButton
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(Color.white.opacity(0.03))
    }

    // 视图切换胶囊
    private var viewModeCapsule: some View {
        HStack(spacing: 0) {
            viewModeItem(mode: .list, icon: "list.bullet", tooltip: model.t("列表视图", "List View"))
            viewModeItem(mode: .matrix, icon: "square.grid.2x2", tooltip: model.t("矩阵画布视图", "Matrix View"))
        }
        .padding(2)
        .background(Color.black.opacity(0.35))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // 视图切换单元
    private func viewModeItem(mode: MatrixViewMode, icon: String, tooltip: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.16)) {
                viewMode = mode
            }
        }) {
            ZStack {
                if viewMode == mode {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.neonCyan.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.neonCyan.opacity(0.45), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "viewModeActiveHighlight", in: viewSwitcherAnimation)
                }

                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(viewMode == mode ? Theme.neonCyan : Theme.textTertiary)
                    .frame(width: 26, height: 20)
            }
            .frame(width: 26, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    // 建立路由按钮
    private var addRouteButton: some View {
        Button(action: { showAddRouteSheet = true }) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text(model.t("建立路由", "Add Route"))
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
        .help(model.t("新建输入源到输出目标的交叉连接路由", "Configure and add a new routing connection"))
    }

    // 初始化矩阵槽位
    private func initSlots() {
        var availableInputs: [MatrixSlot] = []
        for dev in model.devices.filter({ $0.inChannels > 0 }) {
            availableInputs.append(MatrixSlot(id: "dev_in_\(dev.uid)", endpointId: dev.uid, name: dev.name, typeDesc: model.t("物理输入", "Device In"), iconName: "mic.fill"))
        }
        for cable in model.cables {
            availableInputs.append(MatrixSlot(id: "cable_out_\(cable.cableId)", endpointId: cable.cableId, name: cable.name, typeDesc: model.t("线缆输出", "Cable Out"), iconName: "cable.connector"))
        }
        for s in model.metrics.rxStreams {
            availableInputs.append(MatrixSlot(id: "rx_\(s.name)", endpointId: s.name, name: "VBAN [\(s.name)]", typeDesc: model.t("网络流", "VBAN RX"), iconName: "waveform"))
        }

        var availableOutputs: [MatrixSlot] = []
        for dev in model.devices.filter({ $0.outChannels > 0 }) {
            availableOutputs.append(MatrixSlot(id: "dev_out_\(dev.uid)", endpointId: dev.uid, name: dev.name, typeDesc: model.t("物理输出", "Device Out"), iconName: "speaker.wave.2.fill"))
        }
        for cable in model.cables {
            availableOutputs.append(MatrixSlot(id: "cable_in_\(cable.cableId)", endpointId: cable.cableId, name: cable.name, typeDesc: model.t("线缆输入", "Cable In"), iconName: "cable.connector"))
        }
        for tx in model.txStreams {
            availableOutputs.append(MatrixSlot(id: "tx_\(tx.name)", endpointId: tx.name, name: "VBAN [\(tx.name)]", typeDesc: model.t("网络流", "VBAN TX"), iconName: "waveform"))
        }

        var ins = Array(availableInputs.prefix(4))
        var inIndex = ins.count + 1
        while ins.count < 4 {
            ins.append(MatrixSlot(id: "slot_in_\(inIndex)", endpointId: "", name: model.t("输入 \(inIndex)", "Input \(inIndex)"), typeDesc: model.t("未配置", "Unassigned"), iconName: "arrow.down.right.and.arrow.up.left"))
            inIndex += 1
        }
        self.inputSlots = ins

        var outs = Array(availableOutputs.prefix(4))
        var outIndex = outs.count + 1
        while outs.count < 4 {
            outs.append(MatrixSlot(id: "slot_out_\(outIndex)", endpointId: "", name: model.t("输出 \(outIndex)", "Output \(outIndex)"), typeDesc: model.t("未配置", "Unassigned"), iconName: "arrow.up.right.and.arrow.down.left"))
            outIndex += 1
        }
        self.outputSlots = outs
    }
}

// -------------------------------------------------------------
// 路由列表视图
// -------------------------------------------------------------
struct MatrixListView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            tableHeader

            Divider().background(Theme.borderSubtle)

            if model.routes.isEmpty {
                emptyState
            } else {
                routesScrollView
            }
        }
    }

    private var tableHeader: some View {
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
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 28))
                .foregroundColor(Theme.textTertiary)
            Text(model.t("无活动路由连接", "No Active Routes"))
                .font(Theme.cnText(13.5, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .help(model.t("点击右上角 [+ 建立路由] 或切换至矩阵视图建立通道连接", "Click [+ Add Route] or switch to Matrix view to connect channels"))
    }

    private var routesScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(model.routes.enumerated()), id: \.element.routeId) { idx, r in
                    routeRow(idx: idx, r: r)
                    Divider().background(Theme.borderSubtle)
                }
            }
        }
    }

    private func routeRow(idx: Int, r: VbanRouteDesc) -> some View {
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
                    set: { _ in }
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
    }
}

// -------------------------------------------------------------
// 矩阵画布视图
// -------------------------------------------------------------
struct MatrixCanvasView: View {
    @ObservedObject var model: AppModel
    @Binding var inputSlots: [MatrixSlot]
    @Binding var outputSlots: [MatrixSlot]
    var onOpenAddSheet: () -> Void

    let cellSize: CGFloat = 100
    let inLabelWidth: CGFloat = 210
    let dashedThickness: CGFloat = 44

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            ZStack(alignment: .topLeading) {
                // 点阵画布背景
                InfiniteDotGridCanvas()
                    .frame(minWidth: 1600, minHeight: 1200)

                // 核心矩阵网格
                matrixGridWrapper
                    .padding(36)
            }
        }
    }

    // 矩阵网格布局
    private var matrixGridWrapper: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            // 输出列标头
            GridRow {
                // 左上角透明占位单元
                Color.clear
                    .frame(width: inLabelWidth, height: cellSize)

                ForEach(Array(outputSlots.enumerated()), id: \.element.id) { colIdx, outSlot in
                    OutputEndpointHeader(
                        slot: outSlot,
                        colIndex: colIdx,
                        model: model,
                        width: cellSize,
                        height: cellSize,
                        onSelectEndpoint: { newId, newName, newType in
                            outputSlots[colIdx].endpointId = newId
                            outputSlots[colIdx].name = newName
                            outputSlots[colIdx].typeDesc = newType
                        },
                        onDelete: {
                            deleteOutputSlot(at: colIdx)
                        }
                    )
                }

                MatrixDashedPlusCell(
                    width: dashedThickness,
                    height: cellSize,
                    label: "+",
                    tooltip: model.t("在右侧添加输出通道", "Add Output Channel at right")
                ) {
                    appendOutputSlot()
                }
            }

            // 输入行与交叉连接单元
            ForEach(Array(inputSlots.enumerated()), id: \.element.id) { rowIdx, inSlot in
                GridRow {
                    InputEndpointHeader(
                        slot: inSlot,
                        rowIndex: rowIdx,
                        model: model,
                        width: inLabelWidth,
                        height: cellSize,
                        onSelectEndpoint: { newId, newName, newType in
                            inputSlots[rowIdx].endpointId = newId
                            inputSlots[rowIdx].name = newName
                            inputSlots[rowIdx].typeDesc = newType
                        },
                        onDelete: {
                            deleteInputSlot(at: rowIdx)
                        }
                    )

                    ForEach(Array(outputSlots.enumerated()), id: \.element.id) { _, outSlot in
                        CrossPointCell(
                            model: model,
                            inSlot: inSlot,
                            outSlot: outSlot,
                            size: cellSize,
                            onOpenAddSheet: onOpenAddSheet
                        )
                    }

                    MatrixDashedPlusCell(
                        width: dashedThickness,
                        height: cellSize,
                        label: "+",
                        tooltip: model.t("向右扩展输出通道", "Expand output channel")
                    ) {
                        appendOutputSlot()
                    }
                }
            }

            // 底部外围虚线槽位
            GridRow {
                MatrixDashedPlusCell(
                    width: inLabelWidth,
                    height: dashedThickness,
                    label: "+",
                    tooltip: model.t("添加输入通道", "Add input channel")
                ) {
                    appendInputSlot()
                }

                ForEach(0..<outputSlots.count, id: \.self) { _ in
                    MatrixDashedPlusCell(
                        width: cellSize,
                        height: dashedThickness,
                        label: "+",
                        tooltip: model.t("向下扩充输入通道", "Expand input channel")
                    ) {
                        appendInputSlot()
                    }
                }

                MatrixDashedPlusCell(
                    width: dashedThickness,
                    height: dashedThickness,
                    label: "+",
                    tooltip: model.t("新建路由规则", "Add Route")
                ) {
                    onOpenAddSheet()
                }
            }
        }
    }

    // 追加输入槽位
    private func appendInputSlot() {
        let idx = inputSlots.count + 1
        inputSlots.append(MatrixSlot(
            id: "input_slot_\(UUID().uuidString.prefix(6))",
            endpointId: "",
            name: model.t("输入 \(idx)", "Input \(idx)"),
            typeDesc: model.t("未配置", "Unassigned"),
            iconName: "mic"
        ))
    }

    // 插入输入槽位
    private func insertInputSlot(at index: Int) {
        let idx = inputSlots.count + 1
        inputSlots.insert(MatrixSlot(
            id: "input_slot_\(UUID().uuidString.prefix(6))",
            endpointId: "",
            name: model.t("输入 \(idx)", "Input \(idx)"),
            typeDesc: model.t("未配置", "Unassigned"),
            iconName: "mic"
        ), at: index)
    }

    // 删除输入槽位
    private func deleteInputSlot(at index: Int) {
        guard index < inputSlots.count else { return }
        let slot = inputSlots[index]
        if !slot.endpointId.isEmpty {
            let routesToRemove = model.routes.filter { $0.srcId == slot.endpointId }
            for r in routesToRemove {
                model.removeRoute(id: r.routeId)
            }
        }
        inputSlots.remove(at: index)
    }

    // 追加输出槽位
    private func appendOutputSlot() {
        let idx = outputSlots.count + 1
        outputSlots.append(MatrixSlot(
            id: "output_slot_\(UUID().uuidString.prefix(6))",
            endpointId: "",
            name: model.t("输出 \(idx)", "Output \(idx)"),
            typeDesc: model.t("未配置", "Unassigned"),
            iconName: "speaker.wave.2"
        ))
    }

    // 插入输出槽位
    private func insertOutputSlot(at index: Int) {
        let idx = outputSlots.count + 1
        outputSlots.insert(MatrixSlot(
            id: "output_slot_\(UUID().uuidString.prefix(6))",
            endpointId: "",
            name: model.t("输出 \(idx)", "Output \(idx)"),
            typeDesc: model.t("未配置", "Unassigned"),
            iconName: "speaker.wave.2"
        ), at: index)
    }

    // 删除输出槽位
    private func deleteOutputSlot(at index: Int) {
        guard index < outputSlots.count else { return }
        let slot = outputSlots[index]
        if !slot.endpointId.isEmpty {
            let routesToRemove = model.routes.filter { $0.dstId == slot.endpointId }
            for r in routesToRemove {
                model.removeRoute(id: r.routeId)
            }
        }
        outputSlots.remove(at: index)
    }
}

// -------------------------------------------------------------
// 滚动标签组件
// -------------------------------------------------------------
struct RollingLabel: View {
    let text: String
    let font: Font
    let color: Color
    var alignment: Alignment = .leading

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text)
                .font(font)
                .foregroundColor(color)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 2)
        }
        .help(text)
    }
}

// -------------------------------------------------------------
// 虚线槽位组件
// -------------------------------------------------------------
struct MatrixDashedPlusCell: View {
    let width: CGFloat
    let height: CGFloat
    let label: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovered ? Theme.neonCyan.opacity(0.08) : Color.white.opacity(0.015))

                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])
                    )
                    .foregroundColor(isHovered ? Theme.neonCyan : Color.white.opacity(0.22))

                Text(label)
                    .font(Theme.cnText(14, weight: .bold))
                    .foregroundColor(isHovered ? Theme.neonCyan : Theme.textTertiary)
            }
            .frame(width: width, height: height)
        }
        .buttonStyle(.plain)
        .onHover { h in
            isHovered = h
        }
        .help(tooltip)
    }
}

// -------------------------------------------------------------
// 输出列标头组件
// -------------------------------------------------------------
struct OutputEndpointHeader: View {
    let slot: MatrixSlot
    let colIndex: Int
    @ObservedObject var model: AppModel
    let width: CGFloat
    let height: CGFloat
    let onSelectEndpoint: (String, String, String) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text("Out \(colIndex + 1)")
                .font(Theme.monoDigit(14, weight: .bold))
                .foregroundColor(Theme.amberWarn)

            RollingLabel(
                text: slot.name,
                font: Theme.cnText(12, weight: .medium),
                color: Theme.textPrimary,
                alignment: .center
            )
            .frame(height: 18)

            HStack(spacing: 6) {
                Menu {
                    Section(model.t("物理输出设备", "Physical Outputs")) {
                        ForEach(model.devices.filter { $0.outChannels > 0 }, id: \.uid) { d in
                            Button(d.name) {
                                onSelectEndpoint(d.uid, d.name, model.t("物理输出", "Device Out"))
                            }
                        }
                    }
                    Section(model.t("虚拟线缆输入端", "Virtual Cable Inputs")) {
                        ForEach(model.cables, id: \.cableId) { c in
                            Button(c.name) {
                                onSelectEndpoint(c.cableId, c.name, model.t("线缆输入", "Cable In"))
                            }
                        }
                    }
                    Section(model.t("网络发送流", "Network Outgoing Streams")) {
                        ForEach(model.txStreams, id: \.name) { tx in
                            Button(tx.name) {
                                onSelectEndpoint(tx.name, "VBAN [\(tx.name)]", model.t("网络流", "VBAN TX"))
                            }
                        }
                    }
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.neonCyan)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 22, height: 22)
                .help(model.t("修改/切换此输出端点", "Change output destination"))

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.alertRed.opacity(0.8))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(model.t("删除此输出通道", "Remove this output channel"))
            }
        }
        .padding(6)
        .frame(width: width, height: height)
        .background(Color.white.opacity(0.025))
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// -------------------------------------------------------------
// 输入行标头组件
// -------------------------------------------------------------
struct InputEndpointHeader: View {
    let slot: MatrixSlot
    let rowIndex: Int
    @ObservedObject var model: AppModel
    let width: CGFloat
    let height: CGFloat
    let onSelectEndpoint: (String, String, String) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("In \(rowIndex + 1)")
                    .font(Theme.monoDigit(14, weight: .bold))
                    .foregroundColor(Theme.neonCyan)

                RollingLabel(
                    text: slot.name,
                    font: Theme.cnText(12.5, weight: .semibold),
                    color: Theme.textPrimary,
                    alignment: .leading
                )
                .frame(height: 18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Menu {
                    Section(model.t("物理输入设备", "Physical Inputs")) {
                        ForEach(model.devices.filter { $0.inChannels > 0 }, id: \.uid) { d in
                            Button(d.name) {
                                onSelectEndpoint(d.uid, d.name, model.t("物理输入", "Device In"))
                            }
                        }
                    }
                    Section(model.t("虚拟线缆输出端", "Virtual Cable Outputs")) {
                        ForEach(model.cables, id: \.cableId) { c in
                            Button(c.name) {
                                onSelectEndpoint(c.cableId, c.name, model.t("线缆输出", "Cable Out"))
                            }
                        }
                    }
                    Section(model.t("网络接收流", "Network Incoming Streams")) {
                        ForEach(model.metrics.rxStreams, id: \.name) { s in
                            Button(s.name) {
                                onSelectEndpoint(s.name, "VBAN [\(s.name)]", model.t("网络流", "VBAN RX"))
                            }
                        }
                    }
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.neonCyan)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 22, height: 22)
                .help(model.t("修改/切换此输入端点", "Change input source"))

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.alertRed.opacity(0.8))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(model.t("删除此输入通道", "Remove this input channel"))
            }
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: height)
        .background(Color.white.opacity(0.025))
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// -------------------------------------------------------------
// 交叉连接单元组件
// -------------------------------------------------------------
struct CrossPointCell: View {
    @ObservedObject var model: AppModel
    let inSlot: MatrixSlot
    let outSlot: MatrixSlot
    let size: CGFloat
    let onOpenAddSheet: () -> Void

    @State private var isHovered = false

    private var route: VbanRouteDesc? {
        guard !inSlot.endpointId.isEmpty, !outSlot.endpointId.isEmpty else { return nil }
        return model.routes.first(where: {
            $0.srcId == inSlot.endpointId && $0.dstId == outSlot.endpointId
        })
    }

    var body: some View {
        Button(action: handleCellClick) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(route != nil ? Theme.neonCyan.opacity(0.08) : Color.white.opacity(isHovered ? 0.04 : 0.015))

                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        route != nil ? Theme.neonCyan : Color.white.opacity(isHovered ? 0.18 : 0.08),
                        lineWidth: route != nil ? 2 : 1
                    )

                if route != nil {
                    Text("ON")
                        .font(Theme.monoDigit(15, weight: .heavy))
                        .foregroundColor(Theme.neonCyan)
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .onHover { h in
            isHovered = h
        }
        .help(tooltipText)
    }

    private var tooltipText: String {
        let path = "\(inSlot.name) → \(outSlot.name)"
        if route != nil {
            return model.t("\(path) (已连接 · 点击断开)", "\(path) (Connected · Click to disconnect)")
        }
        if inSlot.endpointId.isEmpty || outSlot.endpointId.isEmpty {
            return model.t("\(path) (未配置端点)", "\(path) (Endpoints unassigned)")
        }
        return model.t("\(path) (点击建立路由)", "\(path) (Click to connect)")
    }

    private func handleCellClick() {
        if let r = route {
            model.removeRoute(id: r.routeId)
        } else {
            if !inSlot.endpointId.isEmpty && !outSlot.endpointId.isEmpty {
                // 单输入路由切换
                if let existing = model.routes.first(where: { $0.dstId == outSlot.endpointId }) {
                    model.removeRoute(id: existing.routeId)
                }
                model.addRoute(
                    srcId: inSlot.endpointId,
                    srcName: inSlot.name,
                    dstId: outSlot.endpointId,
                    dstName: outSlot.name,
                    gain: 1.0
                )
            } else {
                onOpenAddSheet()
            }
        }
    }
}

// -------------------------------------------------------------
// 点阵背景组件
// -------------------------------------------------------------
struct InfiniteDotGridCanvas: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 30
            var x: CGFloat = 15
            while x < size.width {
                var y: CGFloat = 15
                while y < size.height {
                    let rect = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.09)))
                    y += step
                }
                x += step
            }
        }
    }
}

// -------------------------------------------------------------
// 新建路由面板
// -------------------------------------------------------------
struct AddRouteSheet: View {
    @ObservedObject var model: AppModel
    @Binding var isPresented: Bool

    @State private var srcId: String = ""
    @State private var srcName: String = ""
    @State private var dstId: String = ""
    @State private var dstName: String = ""
    @State private var gain: Float = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sheetHeader

            Divider().background(Theme.borderSubtle)

            sheetForm

            Divider().background(Theme.borderSubtle)

            sheetActions
        }
        .padding(20)
        .frame(width: 460)
        .background(Theme.windowBg)
        .onAppear {
            if srcId.isEmpty {
                if let f = model.devices.first(where: { $0.inChannels > 0 }) {
                    srcId = f.uid
                    srcName = f.name
                } else if let c = model.cables.first {
                    srcId = c.cableId
                    srcName = c.name
                }
            }
            if dstId.isEmpty {
                if let f = model.devices.first(where: { $0.outChannels > 0 }) {
                    dstId = f.uid
                    dstName = f.name
                } else if let c = model.cables.first {
                    dstId = c.cableId
                    dstName = c.name
                } else if let tx = model.txStreams.first {
                    dstId = tx.name
                    dstName = "VBAN [\(tx.name)]"
                }
            }
        }
    }

    private var sheetHeader: some View {
        HStack {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 16))
                .foregroundColor(Theme.neonCyan)
            Text(model.t("新建音频路由", "New Audio Route"))
                .font(Theme.cnText(14, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
        }
    }

    private var sheetForm: some View {
        VStack(spacing: 14) {
            sourcePickerRow

            destinationPickerRow

            gainSliderRow
        }
    }

    private var sourcePickerRow: some View {
        HStack {
            Text(model.t("输入源:", "Source:"))
                .font(Theme.cnText(12.5, weight: .semibold))
                .frame(width: 80, alignment: .trailing)

            Menu {
                Section(model.t("物理输入设备", "Physical Inputs")) {
                    ForEach(model.devices.filter { $0.inChannels > 0 }, id: \.uid) { d in
                        Button(d.name) {
                            srcId = d.uid
                            srcName = d.name
                        }
                    }
                }
                Section(model.t("虚拟线缆输出", "Virtual Cable Outputs")) {
                    ForEach(model.cables, id: \.cableId) { c in
                        Button(c.name) {
                            srcId = c.cableId
                            srcName = c.name
                        }
                    }
                }
                Section(model.t("网络接收流", "Network Incoming Streams")) {
                    ForEach(model.metrics.rxStreams, id: \.name) { s in
                        Button(s.name) {
                            srcId = s.name
                            srcName = "VBAN [\(s.name)]"
                        }
                    }
                }
            } label: {
                HStack {
                    Text(srcName.isEmpty ? model.t("选择输入源...", "Select Source...") : srcName)
                        .font(Theme.cnText(12.5, weight: .medium))
                    Spacer()
                }
            }
            .menuStyle(.borderedButton)
        }
    }

    private var destinationPickerRow: some View {
        HStack {
            Text(model.t("输出目标:", "Destination:"))
                .font(Theme.cnText(12.5, weight: .semibold))
                .frame(width: 80, alignment: .trailing)

            Menu {
                Section(model.t("物理输出设备", "Physical Outputs")) {
                    ForEach(model.devices.filter { $0.outChannels > 0 }, id: \.uid) { d in
                        Button(d.name) {
                            dstId = d.uid
                            dstName = d.name
                        }
                    }
                }
                Section(model.t("虚拟线缆输入", "Virtual Cable Inputs")) {
                    ForEach(model.cables, id: \.cableId) { c in
                        Button(c.name) {
                            dstId = c.cableId
                            dstName = c.name
                        }
                    }
                }
                Section(model.t("网络发送流", "Network Outgoing Streams")) {
                    ForEach(model.txStreams, id: \.name) { tx in
                        Button(tx.name) {
                            dstId = tx.name
                            dstName = "VBAN [\(tx.name)]"
                        }
                    }
                }
            } label: {
                HStack {
                    Text(dstName.isEmpty ? model.t("选择输出目标...", "Select Destination...") : dstName)
                        .font(Theme.cnText(12.5, weight: .medium))
                    Spacer()
                }
            }
            .menuStyle(.borderedButton)
        }
    }

    private var gainSliderRow: some View {
        HStack {
            Text(model.t("通道增益:", "Gain:"))
                .font(Theme.cnText(12.5, weight: .semibold))
                .frame(width: 80, alignment: .trailing)

            Slider(value: $gain, in: 0.0...2.0)

            Text(String(format: "%+.1f dB", (gain - 1.0) * 12.0))
                .font(Theme.monoDigit(12, weight: .bold))
                .foregroundColor(Theme.neonCyan)
                .frame(width: 64, alignment: .trailing)

            Button(action: { gain = 1.0 }) {
                Text("0 dB")
                    .font(Theme.monoDigit(11, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help(model.t("重置为 0dB 标准无衰减增益", "Reset to 0dB standard gain"))
        }
    }

    private var sheetActions: some View {
        HStack {
            Spacer()
            Button(model.t("取消", "Cancel")) {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)

            Button(action: {
                guard !srcId.isEmpty, !dstId.isEmpty else { return }
                if let existing = model.routes.first(where: { $0.dstId == dstId }) {
                    model.removeRoute(id: existing.routeId)
                }
                model.addRoute(srcId: srcId, srcName: srcName, dstId: dstId, dstName: dstName, gain: gain)
                isPresented = false
            }) {
                Text(model.t("创建并连接", "Create & Connect"))
                    .font(Theme.cnText(12.5, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.neonCyan)
            .keyboardShortcut(.defaultAction)
            .disabled(srcId.isEmpty || dstId.isEmpty)
        }
    }
}
