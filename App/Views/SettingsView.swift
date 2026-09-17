import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var bufferPreset = 2 // Normal

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SYSTEM & NETWORK SETTINGS")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.8))
                        Text("Configure VBAN UDP communication ports, buffering latency, and virtual audio driver status.")
                            .font(Theme.regularText(11))
                            .foregroundColor(Theme.mutedGray)
                    }
                    Spacer()
                }

                Divider().background(Theme.borderSubtle)

                // 网络端口设定
                VStack(alignment: .leading, spacing: 12) {
                    Text("VBAN NETWORK PROTOCOL")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.amberGold)

                    HStack(spacing: 16) {
                        Text("Default UDP Port:")
                            .font(Theme.regularText(13))
                            .foregroundColor(.white)

                        TextField("Port", text: $model.udpPort)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(6)
                            .background(Theme.surfaceBg)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .font(Theme.monoDigit(12))
                            .frame(width: 80)

                        Text("(Standard default: 6980)")
                            .font(Theme.regularText(11))
                            .foregroundColor(Theme.mutedGray)
                    }
                }

                Divider().background(Theme.borderSubtle)

                // 虚拟驱动安装与维护
                VStack(alignment: .leading, spacing: 14) {
                    Text("VIRTUAL AUDIO DRIVER (AudioServerPlugIn)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.amberGold)

                    HStack(spacing: 12) {
                        Circle()
                            .fill(model.metrics.driverInstalled ? Theme.activeGreen : Theme.warningAmber)
                            .frame(width: 8, height: 8)

                        Text(model.metrics.driverInstalled ? "Status: Driver Installed & Running" : "Status: Driver Not Installed")
                            .font(Theme.regularText(13, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        Button(action: {
                            // 执行安装驱动脚本
                            let p = Process()
                            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                            p.arguments = ["-lc", "Scripts/install_driver.zsh"]
                            try? p.run()
                            p.waitUntilExit()
                            model.refreshAll()
                        }) {
                            Label(model.metrics.driverInstalled ? "Reinstall / Repair Driver" : "Install Driver",
                                  systemImage: "wrench.and.screwdriver")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Theme.neonCyan)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Text("The driver plugin is installed into /Library/Audio/Plug-Ins/HAL/ and enables true zero-restart dynamic cable creation across all macOS applications.")
                        .font(Theme.regularText(11))
                        .foregroundColor(Theme.mutedGray)
                }

                Divider().background(Theme.borderSubtle)

                // 关于与开源协议
                VStack(alignment: .leading, spacing: 6) {
                    Text("VBAN ULTIMATE FOR MAC")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.6))
                    Text("High-performance native VBAN Audio Matrix & CoreAudio Virtual Cable Infrastructure.")
                        .font(Theme.regularText(12))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Protocol by Vincent Burel (VB-Audio). Driver foundation powered by libASPL.")
                        .font(Theme.regularText(11))
                        .foregroundColor(Theme.mutedGray)
                }
            }
            .padding(24)
        }
    }
}
