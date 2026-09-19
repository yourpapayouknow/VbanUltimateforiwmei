import SwiftUI

// VBAN Ping 属性面板视图
struct VbanPingSheet: View {
    @ObservedObject var model: AppModel
    var targetIp: String? = nil
    @Binding var isPresented: Bool

    @State private var sendFeedback: String? = nil

    @State private var isCloseHovered: Bool = false

    // 当前展示的 Ping 记录
    private var record: VbanPingRecord? {
        if let tip = targetIp, !tip.isEmpty {
            if let match = model.pingRecords.first(where: { $0.ip == tip }) {
                return match
            }
        }
        return model.latestPing ?? model.pingRecords.last
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏标头
            HStack {
                Button(action: { isPresented = false }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.36, blue: 0.34))
                            .frame(width: 12, height: 12)

                        if isCloseHovered {
                            Image(systemName: "xmark")
                                .font(.system(size: 7, weight: .black))
                                .foregroundColor(Color.black.opacity(0.65))
                        }
                    }
                    .frame(width: 14, height: 14)
                    .contentShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.cancelAction)
                .onHover { hovering in
                    isCloseHovered = hovering
                }
                .help(model.t("关闭窗口 (Esc)", "Close Window (Esc)"))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().background(Theme.borderSubtle)

            Spacer()

            // 属性列表阵列
            VStack(spacing: 9) {
                propertyRow(label: "Username:", value: record?.username ?? "-")
                propertyRow(label: "IPV4:", value: record?.ip ?? (targetIp ?? "-"))
                propertyRow(label: "Hostname:", value: record?.hostname ?? "-")
                propertyRow(label: "Application:", value: record?.application ?? "-")
                propertyRow(label: "Language / Country:", value: record?.langCountry ?? "-")
                propertyRow(label: "TimeStamp:", value: record?.timeStamp ?? "-")
            }

            Spacer()

            // 底部操作区
            VStack(spacing: 8) {
                if let feedback = sendFeedback {
                    Text(feedback)
                        .font(Theme.cnText(11.5, weight: .medium))
                        .foregroundColor(Theme.meterGreen)
                        .transition(.opacity)
                }

                Button(action: handleSendPing) {
                    Text("Send VBAN-Ping...")
                        .font(Theme.cnText(12, weight: .semibold))
                        .foregroundColor(Theme.neonCyan)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 6)
                        .background(Theme.neonCyan.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Theme.neonCyan.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 16)
        }
        .frame(width: 500, height: 290)
        .background(Theme.windowBg)
    }

    // 属性键值行
    private func propertyRow(label: String, value: String) -> some View {
        HStack(spacing: 16) {
            Text(label)
                .font(Theme.cnText(12.5, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 160, alignment: .trailing)

            Text(value)
                .font(Theme.monoDigit(12.5, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 230, alignment: .leading)
        }
    }

    // 发送本机探测报文
    private func handleSendPing() {
        let dest = targetIp ?? (record?.ip ?? "255.255.255.255")
        let ok = model.sendPing(to: dest, port: 6980)
        if ok {
            withAnimation {
                sendFeedback = model.t("已向 \(dest):6980 发送本机 VBAN Ping", "Sent local VBAN Ping to \(dest):6980")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    sendFeedback = nil
                }
            }
        }
    }
}
