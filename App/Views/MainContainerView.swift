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
        .frame(minWidth: 920, idealWidth: 960, minHeight: 560, idealHeight: 580)
        .toolbar {
            // 原生居中分段控制器 (Logic Pro / Xcode 原生风格，严格固定宽度)
            ToolbarItem(placement: .principal) {
                Picker("", selection: $model.activeTab) {
                    ForEach(AppTab.allCases) { tab in
                        Text(tab.title(for: model.language)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 440)
            }
        }
    }
}
