import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }
}

// 界面外观样式枚举
enum AppThemeStyle: String, CaseIterable, Identifiable {
    case system = "system"
    case dark = "dark"
    case light = "light"

    var id: String { rawValue }

    func title(for lang: AppLanguage) -> String {
        switch self {
        case .system: return lang == .chinese ? "跟随系统" : "System"
        case .dark:   return lang == .chinese ? "深色" : "Dark"
        case .light:  return lang == .chinese ? "浅色" : "Light"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark:   return .dark
        case .light:  return .light
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case streams
    case matrix
    case cables
    case monitor
    case settings

    var id: String { rawValue }

    func title(for lang: AppLanguage) -> String {
        switch self {
        case .streams:  return lang == .chinese ? "音频流" : "Streams"
        case .matrix:   return lang == .chinese ? "路由矩阵" : "Matrix"
        case .cables:   return lang == .chinese ? "虚拟线缆" : "Cables"
        case .monitor:  return lang == .chinese ? "监控诊断" : "Monitoring"
        case .settings: return lang == .chinese ? "设置" : "Settings"
        }
    }

    var icon: String {
        switch self {
        case .streams:  return "waveform"
        case .matrix:   return "arrow.triangle.branch"
        case .cables:   return "cable.connector"
        case .monitor:  return "speedometer"
        case .settings: return "gearshape.2"
        }
    }
}

struct VbanTxStreamDesc: Identifiable, Codable {
    var id: String
    var name: String
    var sourceName: String
    var targetIp: String
    var targetPort: UInt16
    var sampleRate: UInt32
    var channels: UInt32
    var bitDepth: UInt32
    var enabled: Bool
    var kbps: UInt32 = 0
    var packetsPerSec: UInt32 = 0

    enum CodingKeys: String, CodingKey {
        case id, name, sourceName, targetIp, targetPort, sampleRate, channels, bitDepth, enabled
    }

    // 标称无压缩 PCM 码率（非实测吞吐）
    var nominalKbps: UInt32 {
        guard enabled else { return 0 }
        return (sampleRate * channels * bitDepth) / 1000
    }
}

// 矩阵槽位端点描述
struct MatrixSlot: Identifiable, Equatable, Codable {
    var id: String
    var endpointId: String
    var name: String
    var typeDesc: String
    var iconName: String
    var kind: UInt8
}

// 矩阵路由持久化记录
struct MatrixRoute: Codable {
    var id: String
    var srcId: String
    var srcName: String
    var srcKind: UInt8
    var dstId: String
    var dstName: String
    var dstKind: UInt8
    var enabled: Bool
}

// 网络质量预设枚举
enum VbanNetworkQuality: UInt8, CaseIterable, Identifiable {
    case optimal = 0
    case fast = 1
    case medium = 2
    case slow = 3
    case verySlow = 4

    var id: UInt8 { rawValue }

    func title(for lang: AppLanguage) -> String {
        switch self {
        case .optimal:  return lang == .chinese ? "极致" : "Optimal"
        case .fast:     return lang == .chinese ? "快速" : "Fast"
        case .medium:   return lang == .chinese ? "中等" : "Medium"
        case .slow:     return lang == .chinese ? "慢速" : "Slow"
        case .verySlow: return lang == .chinese ? "极慢" : "Very slow"
        }
    }

    func desc(for lang: AppLanguage) -> String {
        switch self {
        case .optimal:
            return lang == .chinese ? "极低延迟缓冲，适用于高速有线局域网" : "Ultra-low latency buffer for wired LAN"
        case .fast:
            return lang == .chinese ? "快速响应缓冲，推荐标准配置" : "Fast response buffer, recommended"
        case .medium:
            return lang == .chinese ? "平衡模式缓冲，适用于常规无线网络" : "Balanced buffer for typical wireless network"
        case .slow:
            return lang == .chinese ? "抗抖动缓冲，适用于繁忙网络环境" : "Jitter resistant buffer for busy network"
        case .verySlow:
            return lang == .chinese ? "最大安全缓冲，极端抗丢包防爆音" : "Maximum safety buffer against dropouts"
        }
    }
}

final class AppModel: ObservableObject {
    @Published var activeTab: AppTab = .streams
    @Published var language: AppLanguage = {
        if let saved = UserDefaults.standard.string(forKey: "app_language"),
           let lang = AppLanguage(rawValue: saved) {
            return lang
        }
        return .chinese
    }() {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "app_language")
        }
    }

    // 界面外观样式（默认跟随系统）
    @Published var themeStyle: AppThemeStyle = {
        if let saved = UserDefaults.standard.string(forKey: "app_theme_style"),
           let style = AppThemeStyle(rawValue: saved) {
            return style
        }
        return .system
    }() {
        didSet {
            UserDefaults.standard.set(themeStyle.rawValue, forKey: "app_theme_style")
            applyThemeStyle(themeStyle)
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        return language == .chinese ? zh : en
    }
    @Published var metrics: VbanAppMetric = VbanAppMetric()
    @Published var cables: [VbanCableDesc] = []
    @Published var devices: [VbanAudioDevDesc] = []
    @Published var routes: [VbanRouteDesc] = []
    @Published private(set) var soloRouteId: String? = nil
    private var soloRouteStates: [String: Bool] = [:]

    // 矩阵输入行与输出列槽位
    @Published var inSlots: [MatrixSlot] = [] {
        didSet { saveSlots() }
    }
    @Published var outSlots: [MatrixSlot] = [] {
        didSet { saveSlots() }
    }
    @Published var txStreams: [VbanTxStreamDesc] = [] {
        didSet {
            saveTxStreams()
        }
    }
    @Published var isAudioRunning: Bool = false
    @Published var isPortConflict: Bool = false
    @Published var udpPort: String = "6980"
    @Published var conflictProcesses: [VbanConflictProcess] = []
    @Published var showConflictDiagAlert: Bool = false

    // VBAN Ping 记录
    @Published var pingRecords: [VbanPingRecord] = []
    @Published var latestPing: VbanPingRecord? = nil

    // 本机网络 IP 与节点用户名
    @Published var hostIpAddress: String = ""
    @Published var username: String = {
        if let saved = UserDefaults.standard.string(forKey: "vban_username"), !saved.isEmpty {
            return saved
        }
        let hostName = ProcessInfo.processInfo.hostName.components(separatedBy: ".").first ?? "mac"
        return String(hostName.prefix(16))
    }() {
        didSet {
            let truncated = String(username.prefix(16))
            if username != truncated {
                username = truncated
            }
            UserDefaults.standard.set(username, forKey: "vban_username")
        }
    }

    // 网络质量预设
    @Published var networkQuality: VbanNetworkQuality = {
        let val = UInt8(UserDefaults.standard.integer(forKey: "vban_network_quality"))
        return VbanNetworkQuality(rawValue: val) ?? .fast
    }() {
        didSet {
            UserDefaults.standard.set(Int(networkQuality.rawValue), forKey: "vban_network_quality")
            bridge.setNetworkQuality(networkQuality.rawValue)
        }
    }

    // 音频调度与发包缓冲样本数
    @Published var bufferingFrames: UInt32 = {
        let val = UInt32(UserDefaults.standard.integer(forKey: "vban_buffering_frames"))
        return val > 0 ? val : 128
    }() {
        didSet {
            UserDefaults.standard.set(Int(bufferingFrames), forKey: "vban_buffering_frames")
            bridge.setBufferingFrames(bufferingFrames)
        }
    }

    let availableBuffering: [UInt32] = [128, 256, 441, 480, 512, 1024]

    // 缓冲区样本数业务说明
    func bufferingDesc(_ frames: UInt32) -> String {
        if language == .chinese {
            switch frames {
            case 128:  return "128 采样，极低硬件调度延迟"
            case 256:  return "256 采样，专业低延迟音频调度"
            case 441:  return "441 采样，标称十毫秒网络封包"
            case 480:  return "480 采样，广播级十毫秒标称封包"
            case 512:  return "512 采样，标准音频硬件块"
            case 1024: return "1024 采样，大缓冲防欠载保护"
            default:   return "\(frames) 采样"
            }
        } else {
            switch frames {
            case 128:  return "128 samples, ultra-low latency"
            case 256:  return "256 samples, low latency audio"
            case 441:  return "441 samples, 10ms nominal packet"
            case 480:  return "480 samples, broadcast 10ms packet"
            case 512:  return "512 samples, standard hardware buffer"
            case 1024: return "1024 samples, large safety buffer"
            default:   return "\(frames) samples"
            }
        }
    }

    // 刷新本机局域网 IP
    func refreshHostIpAddress() {
        hostIpAddress = VbanBridge.detectHostIpAddress()
    }

    // 复制本机 IP 到系统剪贴板
    func copyHostIp() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hostIpAddress, forType: .string)
    }

    // 同步外观样式到系统 AppKit 窗口
    func applyThemeStyle(_ style: AppThemeStyle) {
        DispatchQueue.main.async {
            switch style {
            case .system:
                NSApp.appearance = nil
                for win in NSApp.windows {
                    win.appearance = nil
                }
            case .dark:
                let darkApp = NSAppearance(named: .darkAqua)
                NSApp.appearance = darkApp
                for win in NSApp.windows {
                    win.appearance = darkApp
                }
            case .light:
                let lightApp = NSAppearance(named: .aqua)
                NSApp.appearance = lightApp
                for win in NSApp.windows {
                    win.appearance = lightApp
                }
            }
        }
    }

    // 系统全局主题变更通知响应
    @objc private func handleSystemThemeChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.themeStyle == .system else { return }
            self.applyThemeStyle(.system)
            self.objectWillChange.send()
        }
    }

    private var timer: Timer?
    private var ratePollTick = false
    private var storedRoutes: [MatrixRoute] = []
    private let bridge = VbanBridge.shared()

    init() {
        refreshHostIpAddress()
        bridge.setNetworkQuality(networkQuality.rawValue)
        bridge.setBufferingFrames(bufferingFrames)
        loadTxStreams()
        loadSlots()
        applyThemeStyle(themeStyle)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSystemThemeChange),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        start()
        loadRoutes()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        stop()
    }

    func start() {
        // 启动底层工作引擎并载入初态 (绑定指定端口，若冲突则严格报错不降级)
        let p = UInt16(udpPort) ?? 6980
        _ = bridge.startAll(withPort: p)
        isAudioRunning = true
        refreshAll()

        // 500ms 严格节流轮询，更新UI指标，绝不争抢音频线程
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollMetrics()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        bridge.stopAll()
        isAudioRunning = false
    }

    func retryBindPort() {
        let p = UInt16(udpPort) ?? 6980
        _ = bridge.startAll(withPort: p)
        pollMetrics()
    }

    func diagnosePortConflict() {
        let p = UInt16(udpPort) ?? 6980
        conflictProcesses = bridge.scanPortOccupants(p)
        showConflictDiagAlert = true
    }

    func resolveConflictAndRestart() {
        for proc in conflictProcesses {
            _ = bridge.killProcess(byPid: proc.pid)
        }
        usleep(250000)
        retryBindPort()
    }

    func refreshAll() {
        cables = bridge.getCables()
        devices = bridge.getDevices()
        routes = bridge.getRoutes()
        pollMetrics()
    }

    func pollMetrics() {
        metrics = bridge.getSnapshot()
        // 更新音频设备当前采样率
        ratePollTick.toggle()
        if ratePollTick { devices = bridge.getDevices() }
        // 同步发送流实时监控指标
        let snaps = metrics.txStreams
        let map = Dictionary(snaps.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        for i in 0..<txStreams.count {
            if let sm = map[txStreams[i].name] {
                txStreams[i].kbps = sm.kbps
                txStreams[i].packetsPerSec = sm.packetsPerSec
            } else if !txStreams[i].enabled {
                txStreams[i].kbps = 0
                txStreams[i].packetsPerSec = 0
            }
        }
        metrics.activeTx = UInt32(txStreams.filter(\.enabled).count)
        isPortConflict = metrics.portConflict
        latestPing = bridge.getLatestPingRecord()
        pingRecords = bridge.getPingRecords()
    }

    // 查询矩阵端点的实际设备采样率
    private func deviceRate(_ endpoint: String) -> Double? {
        if let cable = cables.first(where: { $0.cableId == endpoint }) {
            return devices.first(where: { $0.name == cable.name })?.sampleRate
        }
        return devices.first(where: { $0.uid == endpoint })?.sampleRate
    }

    // 检查已连接路由的采样率
    func rateWarning(for route: VbanRouteDesc) -> String? {
        guard route.enabled else { return nil }
        let sourceRate: Double?
        if route.srcName.hasPrefix("VBAN [") {
            sourceRate = metrics.rxStreams.first(where: {
                $0.name == route.srcId && $0.status == "Active" && $0.packetsPerSec > 0
            }).map { Double($0.sampleRate) }
        } else {
            sourceRate = deviceRate(route.srcId)
        }
        let targetRate: Double?
        if route.dstName.hasPrefix("VBAN [") {
            targetRate = txStreams.first(where: { $0.name == route.dstId && $0.enabled }).map { Double($0.sampleRate) }
        } else {
            targetRate = deviceRate(route.dstId)
        }
        guard let sourceRate, let targetRate, sourceRate > 0, targetRate > 0,
              abs(sourceRate - targetRate) > 1 else { return nil }
        return "\(route.srcName) \(String(format: "%g", sourceRate / 1000)) kHz → \(route.dstName) \(String(format: "%g", targetRate / 1000)) kHz"
    }

    // 发送本机 VBAN Ping 探测
    @discardableResult
    func sendPing(to ip: String = "255.255.255.255", port: UInt16 = 6980) -> Bool {
        let langCode = language == .chinese ? "zh-cn" : "en-us"
        let host = ProcessInfo.processInfo.hostName
        let user = username
        let app = "VBAN Ultimate"
        let ok = bridge.sendVbanPing(toIp: ip, port: port, appName: app, userName: user, hostName: host, langCode: langCode)
        pollMetrics()
        return ok
    }

    // 发送流管理
    private func loadTxStreams() {
        if let data = UserDefaults.standard.data(forKey: "vban_tx_streams"),
           let list = try? JSONDecoder().decode([VbanTxStreamDesc].self, from: data) {
            txStreams = list.filter { $0.id != "tx_1" }
        } else {
            txStreams = []
        }
        // 向桥接引擎同步已加载的发送流
        for s in txStreams {
            _ = bridge.addTxStream(withId: s.id, name: s.name, source: s.sourceName, targetIp: s.targetIp, port: s.targetPort, sampleRate: s.sampleRate, channels: s.channels, bitDepth: s.bitDepth)
            _ = bridge.setTxStreamEnabled(s.id, enabled: s.enabled)
        }
    }

    private var lastSavedTxJson: Data?
    private func saveTxStreams() {
        // 仅在发送流配置真实发生变化时持久化
        if let data = try? JSONEncoder().encode(txStreams) {
            if data != lastSavedTxJson {
                lastSavedTxJson = data
                UserDefaults.standard.set(data, forKey: "vban_tx_streams")
            }
        }
    }

    func addTxStream(name: String, sourceName: String, targetIp: String, targetPort: UInt16, sampleRate: UInt32, channels: UInt32, bitDepth: UInt32) {
        let sId = "tx_\(UUID().uuidString.prefix(8))"
        let item = VbanTxStreamDesc(id: sId, name: name, sourceName: sourceName, targetIp: targetIp, targetPort: targetPort, sampleRate: sampleRate, channels: channels, bitDepth: bitDepth, enabled: true)
        txStreams.append(item)
        _ = bridge.addTxStream(withId: sId, name: name, source: sourceName, targetIp: targetIp, port: targetPort, sampleRate: sampleRate, channels: channels, bitDepth: bitDepth)
        _ = bridge.setTxStreamEnabled(sId, enabled: true)
    }

    func removeTxStream(id: String) {
        txStreams.removeAll { $0.id == id }
        _ = bridge.removeTxStream(withId: id)
    }

    func updateTxStream(id: String, name: String, sourceName: String, targetIp: String, targetPort: UInt16, sampleRate: UInt32, channels: UInt32, bitDepth: UInt32) {
        if let idx = txStreams.firstIndex(where: { $0.id == id }) {
            let oldName = txStreams[idx].name
            txStreams[idx].name = name
            txStreams[idx].sourceName = sourceName
            txStreams[idx].targetIp = targetIp
            txStreams[idx].targetPort = targetPort
            txStreams[idx].sampleRate = sampleRate
            txStreams[idx].channels = channels
            txStreams[idx].bitDepth = bitDepth
            _ = bridge.addTxStream(withId: id, name: name, source: sourceName, targetIp: targetIp, port: targetPort, sampleRate: sampleRate, channels: channels, bitDepth: bitDepth)
            _ = bridge.setTxStreamEnabled(id, enabled: txStreams[idx].enabled)
            if oldName != name {
                bridge.syncRoutes()
            }
        }
    }

    func toggleTxStream(id: String) {
        if let idx = txStreams.firstIndex(where: { $0.id == id }) {
            txStreams[idx].enabled.toggle()
            _ = bridge.setTxStreamEnabled(id, enabled: txStreams[idx].enabled)
        }
    }

    // 虚拟线缆操作
    func addCable(id: String, name: String, channels: UInt32, sampleRate: UInt32) -> Bool {
        let ok = bridge.addCable(withId: id, name: name, channels: channels, sampleRate: sampleRate)
        if ok {
            cables = bridge.getCables()
            devices = bridge.getDevices()
        }
        return ok
    }

    // 查询与指定线缆关联的矩阵路由
    func relatedRoutes(for cable: VbanCableDesc) -> [VbanRouteDesc] {
        return routes.filter {
            $0.srcId == cable.cableId || $0.dstId == cable.cableId ||
            $0.srcName == cable.name || $0.dstName == cable.name
        }
    }

    // 启动线缆电平采样
    func startCableMeter(_ id: String) -> Bool {
        bridge.startCableMeter(id)
    }

    // 读取线缆声道峰值
    func readCablePeaks(_ id: String) -> [Float] {
        bridge.readCablePeaks(id).map { $0.floatValue }
    }

    // 停止线缆电平采样
    func stopCableMeter(_ id: String) {
        bridge.stopCableMeter(id)
    }

    // 级联删除虚拟线缆及其关联路由
    func removeCable(id: String) {
        let oldCable = cables.first(where: { $0.cableId == id })
        if bridge.removeCable(withId: id) {
            if let cbl = oldCable {
                let toRemove = routes.filter {
                    $0.srcId == id || $0.dstId == id ||
                    $0.srcName == cbl.name || $0.dstName == cbl.name
                }
                for r in toRemove {
                    _ = bridge.removeRoute(withId: r.routeId)
                }
            }
            cables = bridge.getCables()
            bridge.syncRoutes()
            routes = bridge.getRoutes()
            saveRoutes()
            devices = bridge.getDevices()
        }
    }

    // 更新虚拟线缆配置并同步路由端点
    func updateCable(id: String, name: String, channels: UInt32, sampleRate: UInt32) {
        let oldCable = cables.first(where: { $0.cableId == id })
        if bridge.updateCable(withId: id, name: name, channels: channels, sampleRate: sampleRate) {
            if let cbl = oldCable, cbl.name != name {
                // 同步更新发送流中引用的旧名称
                for i in 0..<txStreams.count {
                    if txStreams[i].sourceName == cbl.name {
                        txStreams[i].sourceName = name
                    }
                }
                saveTxStreams()
            }
            cables = bridge.getCables()
            routes = bridge.getRoutes()
            devices = bridge.getDevices()
        }
    }

    // 矩阵槽位管理
    private func loadSlots() {
        // 载入矩阵槽位，缺省时建立 2x2 空矩阵
        let dec = JSONDecoder()
        if let d = UserDefaults.standard.data(forKey: "vban_matrix_in"),
           let list = try? dec.decode([MatrixSlot].self, from: d), !list.isEmpty {
            inSlots = list
        } else {
            inSlots = Self.blnkslts("in", 2)
        }
        if let d = UserDefaults.standard.data(forKey: "vban_matrix_out"),
           let list = try? dec.decode([MatrixSlot].self, from: d), !list.isEmpty {
            outSlots = list
        } else {
            outSlots = Self.blnkslts("out", 2)
        }
    }

    // 建立指定数量的空槽位
    static func blnkslts(_ pfx: String, _ cnt: Int) -> [MatrixSlot] {
        // 生成未配置端点的占位槽位
        (1...max(1, cnt)).map { i in
            MatrixSlot(id: "\(pfx)_\(UUID().uuidString.prefix(6))", endpointId: "",
                       name: "", typeDesc: "", iconName: "", kind: 0)
        }
    }

    private func saveSlots() {
        // 持久化矩阵槽位排布
        let enc = JSONEncoder()
        if let d = try? enc.encode(inSlots) {
            UserDefaults.standard.set(d, forKey: "vban_matrix_in")
        }
        if let d = try? enc.encode(outSlots) {
            UserDefaults.standard.set(d, forKey: "vban_matrix_out")
        }
    }

    // 恢复已保存的矩阵路由
    private func loadRoutes() {
        guard let data = UserDefaults.standard.data(forKey: "vban_matrix_routes"),
              let saved = try? JSONDecoder().decode([MatrixRoute].self, from: data) else { return }
        storedRoutes = saved
        for route in saved {
            if bridge.addRoute(withId: route.id, srcKind: route.srcKind, srcId: route.srcId,
                               srcName: route.srcName, dstKind: route.dstKind, dstId: route.dstId,
                               dstName: route.dstName), !route.enabled {
                bridge.toggleRoute(withId: route.id, enabled: false)
            }
            fillSlot(route.srcId, name: route.srcName, kind: route.srcKind, input: true)
            fillSlot(route.dstId, name: route.dstName, kind: route.dstKind, input: false)
        }
        bridge.syncRoutes()
        routes = bridge.getRoutes()
    }

    // 保存当前矩阵路由
    private func saveRoutes() {
        let ids = Set(routes.map(\.routeId))
        storedRoutes.removeAll { !ids.contains($0.id) }
        if let data = try? JSONEncoder().encode(storedRoutes) {
            UserDefaults.standard.set(data, forKey: "vban_matrix_routes")
        }
    }

    // 将路由端点填入矩阵槽位
    private func fillSlot(_ endpoint: String, name: String, kind: UInt8, input: Bool) {
        var slots = input ? inSlots : outSlots
        guard !slots.contains(where: { $0.endpointId == endpoint }) else { return }
        let idx = slots.firstIndex(where: { $0.endpointId.isEmpty }) ?? slots.count
        if idx == slots.count { slots.append(contentsOf: Self.blnkslts(input ? "in" : "out", 1)) }
        slots[idx].endpointId = endpoint
        slots[idx].name = name
        slots[idx].kind = kind
        slots[idx].typeDesc = kind == 2 ? t("网络流", "VBAN RX") : kind == 1 ? t("虚拟线缆", "Cable") : t("物理设备", "Device")
        if input { inSlots = slots } else { outSlots = slots }
    }

    // 追加输入行
    func addInSlot() {
        inSlots.append(contentsOf: Self.blnkslts("in", 1))
    }

    // 追加输出列
    func addOutSlot() {
        outSlots.append(contentsOf: Self.blnkslts("out", 1))
    }

    // 删除输入行并级联清理相关路由
    func removeInSlot(id: String) {
        guard let idx = inSlots.firstIndex(where: { $0.id == id }) else { return }
        let ep = inSlots[idx].endpointId
        if !ep.isEmpty {
            for r in routes where r.srcId == ep {
                _ = bridge.removeRoute(withId: r.routeId)
            }
        }
        inSlots.remove(at: idx)
        bridge.syncRoutes()
        routes = bridge.getRoutes()
        saveRoutes()
    }

    // 删除输出列并级联清理相关路由
    func removeOutSlot(id: String) {
        guard let idx = outSlots.firstIndex(where: { $0.id == id }) else { return }
        let ep = outSlots[idx].endpointId
        if !ep.isEmpty {
            for r in routes where r.dstId == ep {
                _ = bridge.removeRoute(withId: r.routeId)
            }
        }
        outSlots.remove(at: idx)
        bridge.syncRoutes()
        routes = bridge.getRoutes()
        saveRoutes()
    }

    // 填入输入行端点
    func setInSlot(id: String, endpointId: String, name: String, typeDesc: String) {
        // 更新输入槽位端点并清理其失效路由
        guard let idx = inSlots.firstIndex(where: { $0.id == id }) else { return }
        let old = inSlots[idx].endpointId
        if !old.isEmpty && old != endpointId {
            for r in routes where r.srcId == old {
                _ = bridge.removeRoute(withId: r.routeId)
            }
        }
        inSlots[idx].endpointId = endpointId
        inSlots[idx].name = name
        inSlots[idx].typeDesc = typeDesc
        inSlots[idx].kind = kndof(typeDesc)
        bridge.syncRoutes()
        routes = bridge.getRoutes()
        saveRoutes()
    }

    // 填入输出列端点
    func setOutSlot(id: String, endpointId: String, name: String, typeDesc: String) {
        // 更新输出槽位端点并清理其失效路由
        guard let idx = outSlots.firstIndex(where: { $0.id == id }) else { return }
        let old = outSlots[idx].endpointId
        if !old.isEmpty && old != endpointId {
            for r in routes where r.dstId == old {
                _ = bridge.removeRoute(withId: r.routeId)
            }
        }
        outSlots[idx].endpointId = endpointId
        outSlots[idx].name = name
        outSlots[idx].typeDesc = typeDesc
        outSlots[idx].kind = kndof(typeDesc)
        bridge.syncRoutes()
        routes = bridge.getRoutes()
        saveRoutes()
    }

    // 依据端点说明判定端点类型
    private func kndof(_ typeDesc: String) -> UInt8 {
        // 线缆为一类，网络流为二类，其余归物理端点
        if typeDesc.contains("线缆") || typeDesc.contains("Cable") { return 1 }
        if typeDesc.contains("网络") || typeDesc.contains("VBAN") { return 2 }
        return 0
    }

    // 矩阵路由操作
    func addRoute(srcId: String, srcName: String, srcKind: UInt8, dstId: String, dstName: String, dstKind: UInt8) {
        let rId = "r_\(UUID().uuidString.prefix(8))"
        if bridge.addRoute(withId: rId, srcKind: srcKind, srcId: srcId, srcName: srcName, dstKind: dstKind, dstId: dstId, dstName: dstName) {
            bridge.syncRoutes()
            routes = bridge.getRoutes()
            storedRoutes.append(MatrixRoute(id: rId, srcId: srcId, srcName: srcName, srcKind: srcKind,
                                            dstId: dstId, dstName: dstName, dstKind: dstKind, enabled: true))
            fillSlot(srcId, name: srcName, kind: srcKind, input: true)
            fillSlot(dstId, name: dstName, kind: dstKind, input: false)
            saveRoutes()
        }
    }

    // 查询路由的持久化端点资料
    func routeRecord(id: String) -> MatrixRoute? {
        storedRoutes.first { $0.id == id }
    }

    // 更新路由端点并保留路由身份与启用状态
    func updateRoute(id: String, srcId: String, srcName: String, srcKind: UInt8,
                     dstId: String, dstName: String, dstKind: UInt8) {
        guard let current = storedRoutes.first(where: { $0.id == id }) else { return }
        if let conflict = routes.first(where: { $0.routeId != id && $0.dstId == dstId }) {
            removeRoute(id: conflict.routeId)
        }
        guard let idx = storedRoutes.firstIndex(where: { $0.id == id }) else { return }
        let enabled = routes.first(where: { $0.routeId == id })?.enabled ?? current.enabled
        guard bridge.addRoute(withId: id, srcKind: srcKind, srcId: srcId, srcName: srcName,
                              dstKind: dstKind, dstId: dstId, dstName: dstName) else { return }
        if !enabled { bridge.toggleRoute(withId: id, enabled: false) }
        storedRoutes[idx] = MatrixRoute(id: id, srcId: srcId, srcName: srcName, srcKind: srcKind,
                                        dstId: dstId, dstName: dstName, dstKind: dstKind, enabled: enabled)
        fillSlot(srcId, name: srcName, kind: srcKind, input: true)
        fillSlot(dstId, name: dstName, kind: dstKind, input: false)
        bridge.syncRoutes()
        routes = bridge.getRoutes()
        saveRoutes()
    }

    // 临时独奏指定路由或恢复独奏前状态
    func toggleRouteSolo(id: String) {
        if soloRouteId == id {
            clearRouteSolo()
            return
        }
        if soloRouteId == nil {
            soloRouteStates = Dictionary(uniqueKeysWithValues: routes.map { ($0.routeId, $0.enabled) })
        }
        soloRouteId = id
        for route in routes {
            bridge.toggleRoute(withId: route.routeId, enabled: route.routeId == id)
        }
        bridge.syncRoutes()
        routes = bridge.getRoutes()
    }

    // 恢复进入独奏前的路由状态
    func clearRouteSolo() {
        guard soloRouteId != nil else { return }
        for route in routes {
            bridge.toggleRoute(withId: route.routeId, enabled: soloRouteStates[route.routeId] ?? route.enabled)
        }
        bridge.syncRoutes()
        routes = bridge.getRoutes()
        soloRouteStates.removeAll()
        soloRouteId = nil
    }

    func removeRoute(id: String) {
        if bridge.removeRoute(withId: id) {
            bridge.syncRoutes()
            routes = bridge.getRoutes()
            saveRoutes()
        }
    }

    func toggleRoute(id: String, enabled: Bool) {
        bridge.toggleRoute(withId: id, enabled: enabled)
        bridge.syncRoutes()
        routes = bridge.getRoutes()
        if let idx = storedRoutes.firstIndex(where: { $0.id == id }) {
            storedRoutes[idx].enabled = enabled
        }
        saveRoutes()
    }
}
