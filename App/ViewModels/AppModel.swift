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
        case .settings: return lang == .chinese ? "设置与概览" : "Settings"
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
    @Published var udpPort: String = "6980"

    private var timer: Timer?
    private let bridge = VbanBridge.shared()

    init() {
        loadTxStreams()
        start()
    }

    deinit {
        stop()
    }

    func start() {
        // 启动底层工作引擎并载入初态
        _ = bridge.startAll()
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

    func refreshAll() {
        cables = bridge.getCables()
        devices = bridge.getDevices()
        routes = bridge.getRoutes()
        pollMetrics()
    }

    func pollMetrics() {
        metrics = bridge.getSnapshot()
        metrics.activeTx = UInt32(txStreams.filter(\.enabled).count)
    }

    // 发送流管理
    private func loadTxStreams() {
        if let data = UserDefaults.standard.data(forKey: "vban_tx_streams"),
           let list = try? JSONDecoder().decode([VbanTxStreamDesc].self, from: data) {
            txStreams = list
        } else {
            txStreams = [
                VbanTxStreamDesc(id: "tx_1", name: "MasterOut", sourceName: "VBAN Cable A", targetIp: "192.168.1.50", targetPort: 6980, sampleRate: 48000, channels: 2, bitDepth: 24, enabled: true, kbps: 2304, packetsPerSec: 188)
            ]
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
        }
        return ok
    }

    func removeCable(id: String) {
        if bridge.removeCable(withId: id) {
            cables = bridge.getCables()
        }
    }

    func renameCable(id: String, newName: String) {
        if bridge.renameCable(withId: id, newName: newName) {
            cables = bridge.getCables()
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
