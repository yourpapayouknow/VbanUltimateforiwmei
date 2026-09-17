import SwiftUI

// 专业音频深色暗调设计系统主题规范 (严格对应 DESIGN.md)
enum Theme {
    // 基底底色
    static let windowBg  = Color(red: 0.07, green: 0.07, blue: 0.08) // #121214
    static let surfaceBg = Color(red: 0.12, green: 0.12, blue: 0.14) // #1E1E24
    static let borderSubtle = Color.white.opacity(0.08)

    // 强调色
    static let neonCyan  = Color(red: 0.0, green: 0.95, blue: 1.0)   // #00F2FE
    static let amberGold = Color(red: 1.0, green: 0.70, blue: 0.0)   // #FFB300

    // 状态语义色
    static let activeGreen = Color(red: 0.06, green: 0.73, blue: 0.51) // #10B981
    static let warningAmber = Color(red: 0.96, green: 0.62, blue: 0.07) // #F59E0B
    static let offlineRed   = Color(red: 0.94, green: 0.27, blue: 0.27) // #EF4444
    static let mutedGray    = Color(red: 0.42, green: 0.45, blue: 0.50) // #6B7280

    // 字体规范 (确保数字等宽等高防抖动)
    static func monoDigit(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }

    static func regularText(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }
}

// 通用微胶囊状态徽章
struct MicroCapsuleBadge: View {
    let title: String
    var color: Color = Theme.neonCyan
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let ic = icon {
                Image(systemName: ic)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(title)
                .font(Theme.monoDigit(11, weight: .semibold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
