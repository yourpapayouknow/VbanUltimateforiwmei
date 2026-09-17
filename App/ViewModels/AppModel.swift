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
    @Published var isAudioRunning: Bool = false
    @Published var udpPort: String = "6980"

    private var timer: Timer?
    private let bridge = VbanBridge.shared()

    init() {
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
