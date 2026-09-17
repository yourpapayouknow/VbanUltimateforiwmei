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

            // 右侧状态与核心引擎启停
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    StatusLed(isActive: model.isAudioRunning)

                    Text(model.isAudioRunning ? model.t("引擎就绪", "Engine Ready") : model.t("引擎暂停", "Engine Paused"))
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
                    .help(model.isAudioRunning ? model.t("停止网络与音频引擎", "Stop audio & network engine") : model.t("启动网络与音频引擎", "Start audio & network engine"))
                }
                .frame(width: 130, alignment: .trailing)
            }
        }
    }
}
