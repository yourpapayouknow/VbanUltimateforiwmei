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
        .frame(minWidth: 840, minHeight: 520)
        .toolbar {
            // 原生居中分段控制器 (Xcode / Logic Pro 原生风格)
            ToolbarItem(placement: .principal) {
                Picker("", selection: $model.activeTab) {
                    ForEach(AppTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 420)
            }

            // 右侧状态与核心引擎启停
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    StatusLed(isActive: model.isAudioRunning)

                    Text(model.isAudioRunning ? "引擎就绪" : "引擎暂停")
                        .font(Theme.cnText(11, weight: .medium))
                        .foregroundColor(model.isAudioRunning ? Theme.meterGreen : Theme.alertRed)

                    Button(action: {
                        if model.isAudioRunning {
                            model.stop()
                        } else {
                            model.start()
                        }
                    }) {
                        Image(systemName: model.isAudioRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 10))
                    }
                    .help(model.isAudioRunning ? "停止网络与音频引擎" : "启动网络与音频引擎")
                }
            }
        }
    }
}
