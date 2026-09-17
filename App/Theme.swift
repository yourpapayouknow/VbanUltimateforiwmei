import SwiftUI
import AppKit

// 专业音频 macOS 原生设计系统规范 (DESIGN.md)
enum Theme {
    // 基底底色 (适配系统深色工作台)
    static let windowBg     = Color(nsColor: .windowBackgroundColor)
    static let surfaceBg    = Color(nsColor: .controlBackgroundColor)
    static let rowAltBg     = Color.white.opacity(0.02)
    static let borderSubtle = Color.white.opacity(0.08)

    // 专业音频强调色
    static let neonCyan     = Color(red: 0.0, green: 0.88, blue: 0.95)   // 霓虹青
    static let meterGreen   = Color(red: 0.06, green: 0.78, blue: 0.45)  // 电平绿
    static let amberWarn    = Color(red: 0.96, green: 0.65, blue: 0.12)  // 警告黄
    static let alertRed     = Color(red: 0.95, green: 0.28, blue: 0.28)  // 丢包/离线红
    static let textPrimary  = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary  = Color.white.opacity(0.65)  // 提升暗调下副级文本对比度，拒绝费眼

    // 等宽数字字体 (杜绝高频刷新时文字横向抖动，强化字重与可读性)
    static func monoDigit(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }

    // 中文标准系统文本 (强化默认字重，清晰易读)
    static func cnText(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }
}

// 原生风格状态指示灯
struct StatusLed: View {
    let isActive: Bool
    var activeColor: Color = Theme.meterGreen
    var offlineColor: Color = Theme.alertRed

    var body: some View {
        Circle()
            .fill(isActive ? activeColor : offlineColor)
            .frame(width: 8, height: 8)
            .shadow(color: (isActive ? activeColor : Color.clear).opacity(0.6), radius: 3)
    }
}

// 原生紧凑参数胶囊标签
struct ParamCapsule: View {
    let text: String
    var color: Color = Theme.textSecondary

    var body: some View {
        Text(text)
            .font(Theme.monoDigit(12, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
