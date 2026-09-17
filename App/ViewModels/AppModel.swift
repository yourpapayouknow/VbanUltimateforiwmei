import SwiftUI
import Combine

enum AppTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case streams  = "Streams"
    case matrix   = "Matrix"
    case cables   = "Virtual Cables"
    case monitor  = "Monitoring"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "waveform.circle.fill"
        case .streams:  return "antenna.radiowaves.left.and.right"
        case .matrix:   return "arrow.triangle.branch"
        case .cables:   return "cable.connector"
        case .monitor:  return "gauge.with.dots.needle.bottom.50percent"
        case .settings: return "gearshape.fill"
        }
    }
}

final class AppModel: ObservableObject {
    @Published var activeTab: AppTab = .overview
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
