import SwiftUI

struct MainContainerView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        VStack(spacing: 0) {
            // 顶部专业多标签页集成导航栏 (Xcode / Safari Segmented TabBar)
            HStack(spacing: 16) {
                // 应用标志
                HStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundColor(Theme.neonCyan)
                        .font(.system(size: 16))
                    Text("VBAN Ultimate")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.leading, 12)

                Spacer()

                // 顶部居中选项卡
                HStack(spacing: 4) {
                    ForEach(AppTab.allCases) { tab in
                        Button(action: {
                            model.activeTab = tab
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11))
                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: model.activeTab == tab ? .semibold : .regular))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(model.activeTab == tab ? Theme.neonCyan.opacity(0.18) : Color.clear)
                            .foregroundColor(model.activeTab == tab ? Theme.neonCyan : Color.white.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Spacer()

                // 引擎启停与状态角标
                HStack(spacing: 10) {
                    Circle()
                        .fill(model.isAudioRunning ? Theme.activeGreen : Theme.offlineRed)
                        .frame(width: 8, height: 8)
                    Text(model.isAudioRunning ? "ONLINE" : "OFFLINE")
                        .font(Theme.monoDigit(11, weight: .bold))
                        .foregroundColor(model.isAudioRunning ? Theme.activeGreen : Theme.offlineRed)

                    Button(action: {
                        if model.isAudioRunning {
                            model.stop()
                        } else {
                            model.start()
                        }
                    }) {
                        Image(systemName: model.isAudioRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Theme.surfaceBg)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.trailing, 12)
            }
            .padding(.vertical, 8)
            .background(Theme.surfaceBg.opacity(0.95))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Theme.borderSubtle),
                alignment: .bottom
            )

            // 主视图内容区 (最大化展示)
            Group {
                switch model.activeTab {
                case .overview:
                    OverviewView(model: model)
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
            .background(Theme.windowBg)
        }
        .frame(minWidth: 860, minHeight: 560)
        .background(Theme.windowBg)
    }
}
