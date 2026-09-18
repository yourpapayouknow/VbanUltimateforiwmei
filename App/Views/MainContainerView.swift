import SwiftUI

struct MainContainerView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        VStack(spacing: 0) {
            // 主工作区内容展示
            Group {
                switch model.activeTab {
                case .streams:
                    StreamsView(model: model)
                case .matrix:
                    MatrixView(model: model)
                case .cables:
                    CablesView(model: model)
                case .monitor:
                    MonitoringView(model: model)
                case .settings:
                    SettingsView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.windowBg)
        .frame(minWidth: 960, idealWidth: 1020, minHeight: 580, idealHeight: 620)
        .toolbar {
            // 原生居中分段控制器 (Logic Pro / Xcode 原生风格，严格固定宽度)
            ToolbarItem(placement: .principal) {
                Picker("", selection: $model.activeTab) {
                    ForEach(AppTab.allCases) { tab in
                        Text(tab.title(for: model.language)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 480)
            }

            // 全局窗口最右上角指标状态胶囊
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    if model.isPortConflict {
                        ParamCapsule(text: "UDP \(model.udpPort) " + model.t("冲突占用", "Conflict"), color: Theme.alertRed)
                            .help(model.t("UDP \(model.udpPort) 端口被其他应用（如 VBAN Talkie）独占，无法接收外部音频流", "UDP port \(model.udpPort) is occupied by another app. Cannot receive streams."))
                    } else {
                        ParamCapsule(text: "UDP \(model.udpPort)", color: Theme.textSecondary)
                            .help(model.t("VBAN 标准网络监听端口", "Standard VBAN network listening port"))
                    }

                    ParamCapsule(
                        text: "\(model.metrics.rxStreams.count) RX · \(model.txStreams.filter(\.enabled).count) TX",
                        color: model.metrics.rxStreams.isEmpty && model.txStreams.filter(\.enabled).isEmpty ? Theme.textTertiary : Theme.meterGreen
                    )
                    .help(model.t("当前在线活动的 VBAN 接收与发送流总数", "Total count of active incoming and outgoing streams"))
                }
            }
        }
    }
}
