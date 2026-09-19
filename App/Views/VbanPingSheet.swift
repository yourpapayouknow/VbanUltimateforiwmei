import SwiftUI

// VBAN Ping 属性面板视图
struct VbanPingSheet: View {
    @ObservedObject var model: AppModel
    var targetIp: String? = nil
    @Binding var isPresented: Bool

    @State private var sendFeedback: String? = nil

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
                Text("VBAN Ping")
                    .font(Theme.cnText(13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                Button(action: { isPresented = false }) {
                    Text("✕")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                        .padding(4)
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.cancelAction)
                .help(model.t("关闭窗口 (Esc)", "Close Window (Esc)"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().background(Color.white.opacity(0.12))

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

                HStack(spacing: 14) {
                    Button(model.t("关闭", "Close")) {
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)
                    .font(Theme.cnText(12.5, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                    Button(action: handleSendPing) {
                        Text("Send VBAN-Ping...")
                            .font(Theme.cnText(12.5, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 16)
        }
        .frame(width: 520, height: 300)
        .background(Color(red: 0.16, green: 0.19, blue: 0.22))
    }

    // 属性键值行
    private func propertyRow(label: String, value: String) -> some View {
        HStack(spacing: 16) {
            Text(label)
                .font(Theme.cnText(13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.70))
                .frame(width: 170, alignment: .trailing)

            Text(value)
                .font(Theme.monoDigit(13, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.92))
                .frame(width: 220, alignment: .leading)
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
