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
    var kbps: UInt32
    var packetsPerSec: UInt32

    // 真实的无压缩 PCM 传输比特率（kbps）
    var realKbps: UInt32 {
        guard enabled else { return 0 }
        return (sampleRate * channels * bitDepth) / 1000
    }
}

// 网络质量预设枚举
enum VbanNetworkQuality: UInt8, CaseIterable, Identifiable {
    case optimal = 0
    case fast = 1
    case medium = 2
    case slow = 3
    case verySlow = 4

    var id: UInt8 { rawValue }

    var displayName: String {
        switch self {
        case .optimal:  return "Optimal"
        case .fast:     return "Fast"
        case .medium:   return "Medium"
        case .slow:     return "Slow"
        case .verySlow: return "Very slow"
        }
    }

    func desc(for lang: AppLanguage) -> String {
        switch self {
        case .optimal:
            return lang == .chinese ? "极低延迟 (~5ms · 适合千兆有线局域网)" : "Ultra-low latency (~5ms · Wired LAN)"
        case .fast:
            return lang == .chinese ? "快速响应 (~10ms · 优质网络推荐)" : "Fast response (~10ms · Recommended)"
        case .medium:
            return lang == .chinese ? "平衡模式 (~20ms · 标准 Wi-Fi 环境)" : "Balanced (~20ms · Typical Wi-Fi)"
        case .slow:
            return lang == .chinese ? "抗抖动模式 (~40ms · 拥塞网络环境)" : "Jitter resistant (~40ms · Busy network)"
        case .verySlow:
            return lang == .chinese ? "极端抗抖动 (~80ms · 最大安全缓冲)" : "Max protection (~80ms · High jitter)"
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

    func t(_ zh: String, _ en: String) -> String {
        return language == .chinese ? zh : en
    }
    @Published var metrics: VbanAppMetric = VbanAppMetric()
    @Published var cables: [VbanCableDesc] = []
    @Published var devices: [VbanAudioDevDesc] = []
    @Published var routes: [VbanRouteDesc] = []
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
        switch frames {
        case 128:  return t("128 采样 (~2.67ms @48k · 极低延迟 I/O 块)", "128 samples (~2.67ms @48k · Ultra-low latency)")
        case 256:  return t("256 采样 (~5.33ms @48k · 低延迟专业音频块)", "256 samples (~5.33ms @48k · Low latency audio)")
        case 441:  return t("441 采样 (44.1kHz 下 10ms 标称网络包帧长)", "441 samples (10ms nominal packet at 44.1kHz)")
        case 480:  return t("480 采样 (48.0kHz 下 10ms 广播标准包帧长)", "480 samples (10ms nominal packet at 48kHz)")
        case 512:  return t("512 采样 (~10.67ms @48k · 标准音频 I/O 块)", "512 samples (~10.67ms @48k · Standard I/O buffer)")
        case 1024: return t("1024 采样 (~21.33ms @48k · 大缓冲安全防欠载)", "1024 samples (~21.33ms @48k · Large safety buffer)")
        default:   return "\(frames) samples"
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

    private var timer: Timer?
    private let bridge = VbanBridge.shared()

    init() {
        refreshHostIpAddress()
        bridge.setNetworkQuality(networkQuality.rawValue)
        bridge.setBufferingFrames(bufferingFrames)
        loadTxStreams()
        start()
    }

    deinit {
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
        metrics.activeTx = UInt32(txStreams.filter(\.enabled).count)
        isPortConflict = metrics.portConflict
    }

    // 发送流管理
    private func loadTxStreams() {
        if let data = UserDefaults.standard.data(forKey: "vban_tx_streams"),
           let list = try? JSONDecoder().decode([VbanTxStreamDesc].self, from: data) {
            txStreams = list.filter { $0.id != "tx_1" }
        } else {
            txStreams = []
        }
    }

    private func saveTxStreams() {
        if let data = try? JSONEncoder().encode(txStreams) {
            UserDefaults.standard.set(data, forKey: "vban_tx_streams")
        }
    }

    func addTxStream(name: String, sourceName: String, targetIp: String, targetPort: UInt16, sampleRate: UInt32, channels: UInt32, bitDepth: UInt32) {
        let kbps = sampleRate * channels * bitDepth / 1000
        let pps: UInt32 = sampleRate / 256
        let item = VbanTxStreamDesc(id: "tx_\(UUID().uuidString.prefix(8))", name: name, sourceName: sourceName, targetIp: targetIp, targetPort: targetPort, sampleRate: sampleRate, channels: channels, bitDepth: bitDepth, enabled: true, kbps: kbps, packetsPerSec: pps)
        txStreams.append(item)
    }

    func removeTxStream(id: String) {
        txStreams.removeAll { $0.id == id }
    }

    func updateTxStream(id: String, name: String, sourceName: String, targetIp: String, targetPort: UInt16, sampleRate: UInt32, channels: UInt32, bitDepth: UInt32) {
        if let idx = txStreams.firstIndex(where: { $0.id == id }) {
            let kbps = (sampleRate * channels * bitDepth) / 1000
            let pps: UInt32 = sampleRate / 256
            txStreams[idx].name = name
            txStreams[idx].sourceName = sourceName
            txStreams[idx].targetIp = targetIp
            txStreams[idx].targetPort = targetPort
            txStreams[idx].sampleRate = sampleRate
            txStreams[idx].channels = channels
            txStreams[idx].bitDepth = bitDepth
            txStreams[idx].kbps = kbps
            txStreams[idx].packetsPerSec = pps
            saveTxStreams()
        }
    }

    func toggleTxStream(id: String) {
        if let idx = txStreams.firstIndex(where: { $0.id == id }) {
            txStreams[idx].enabled.toggle()
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
            routes = bridge.getRoutes()
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

    // 矩阵路由操作
    func addRoute(srcId: String, srcName: String, dstId: String, dstName: String, gain: Float = 1.0) {
        let rId = "r_\(UUID().uuidString.prefix(8))"
        if bridge.addRoute(withId: rId, srcId: srcId, srcName: srcName, dstId: dstId, dstName: dstName, gain: gain) {
            routes = bridge.getRoutes()
        }
    }

    func removeRoute(id: String) {
        if bridge.removeRoute(withId: id) {
            routes = bridge.getRoutes()
        }
    }

    func toggleRoute(id: String, enabled: Bool) {
        bridge.toggleRoute(withId: id, enabled: enabled)
        routes = bridge.getRoutes()
    }
}
