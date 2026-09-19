import SwiftUI
import AppKit

// 动态外观色彩扩展
extension NSColor {
    // 动态色彩构建函数
    static func dynamic(dark: NSColor, light: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        }
    }
}

// 专业音频 macOS 原生设计系统规范 (DESIGN.md)
enum Theme {
    // 基底底色 (深色专业深黑 / 浅色纯净灰白)
    static let windowBg = Color(nsColor: .dynamic(
        dark: NSColor(red: 0.051, green: 0.055, blue: 0.067, alpha: 1.0),   // #0D0E11 专业音频深黑
        light: NSColor(red: 0.961, green: 0.965, blue: 0.973, alpha: 1.0)   // #F5F6F8 纯净浅灰白
    ))

    static let surfaceBg = Color(nsColor: .dynamic(
        dark: NSColor(red: 0.086, green: 0.090, blue: 0.114, alpha: 1.0),   // #16171D
        light: NSColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1.0)   // #FFFFFF
    ))

    // 容器与卡片底色
    static let cardBg = Color(nsColor: .dynamic(
        dark: NSColor(white: 1.0, alpha: 0.025),
        light: NSColor(white: 0.0, alpha: 0.025)
    ))

    // 斑马纹交替行底色
    static let rowAltBg = Color(nsColor: .dynamic(
        dark: NSColor(white: 1.0, alpha: 0.015),
        light: NSColor(white: 0.0, alpha: 0.025)
    ))

    // 结构微细边框与分割线
    static let borderSubtle = Color(nsColor: .dynamic(
        dark: NSColor(white: 1.0, alpha: 0.08),
        light: NSColor(white: 0.0, alpha: 0.09)
    ))

    // 表头背景底色
    static let tableHeaderBg = Color(nsColor: .dynamic(
        dark: NSColor(white: 0.0, alpha: 0.28),
        light: NSColor(white: 0.0, alpha: 0.035)
    ))

    // 滑块底槽背景
    static let capsuleBg = Color(nsColor: .dynamic(
        dark: NSColor(white: 0.0, alpha: 0.40),
        light: NSColor(white: 0.0, alpha: 0.06)
    ))

    // 操作小按钮背景
    static let btnBg = Color(nsColor: .dynamic(
        dark: NSColor(white: 1.0, alpha: 0.06),
        light: NSColor(white: 0.0, alpha: 0.05)
    ))

    // 矩阵点阵圆点色彩
    static let dotGrid = Color(nsColor: .dynamic(
        dark: NSColor(white: 1.0, alpha: 0.18),
        light: NSColor(white: 0.0, alpha: 0.15)
    ))

    // 电平条凹槽底色与边框
    static let meterSlotBg = Color(nsColor: .dynamic(
        dark: NSColor(white: 0.0, alpha: 0.40),
        light: NSColor(white: 0.0, alpha: 0.08)
    ))

    static let meterSlotBorder = Color(nsColor: .dynamic(
        dark: NSColor(white: 1.0, alpha: 0.06),
        light: NSColor(white: 0.0, alpha: 0.08)
    ))

    // 声场中轴指示线
    static let centerAxisLine = Color(nsColor: .dynamic(
        dark: NSColor(white: 1.0, alpha: 0.10),
        light: NSColor(white: 0.0, alpha: 0.12)
    ))

    // 专业音频强调色 (动态适配深浅模式，保证浅色底对比度 > 4.5:1)
    static let neonCyan = Color(nsColor: .dynamic(
        dark: NSColor(red: 0.00, green: 0.88, blue: 0.95, alpha: 1.0),   // 电光青
        light: NSColor(red: 0.00, green: 0.48, blue: 0.55, alpha: 1.0)   // 深青
    ))

    static let meterGreen = Color(nsColor: .dynamic(
        dark: NSColor(red: 0.06, green: 0.78, blue: 0.45, alpha: 1.0),
        light: NSColor(red: 0.05, green: 0.62, blue: 0.35, alpha: 1.0)
    ))

    static let amberWarn = Color(nsColor: .dynamic(
        dark: NSColor(red: 0.96, green: 0.65, blue: 0.12, alpha: 1.0),
        light: NSColor(red: 0.85, green: 0.50, blue: 0.05, alpha: 1.0)
    ))

    static let alertRed = Color(nsColor: .dynamic(
        dark: NSColor(red: 0.95, green: 0.28, blue: 0.28, alpha: 1.0),
        light: NSColor(red: 0.85, green: 0.18, blue: 0.18, alpha: 1.0)
    ))

    // 文字色彩梯度 (符合专业可读性规范)
    static let textPrimary = Color(nsColor: .dynamic(
        dark: NSColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1.0),
        light: NSColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 1.0)
    ))

    static let textSecondary = Color(nsColor: .dynamic(
        dark: NSColor(red: 0.61, green: 0.64, blue: 0.69, alpha: 1.0),
        light: NSColor(red: 0.29, green: 0.33, blue: 0.39, alpha: 1.0)
    ))

    static let textTertiary = Color(nsColor: .dynamic(
        dark: NSColor(red: 0.75, green: 0.78, blue: 0.82, alpha: 1.0),   // 清晰三级文本，拒绝发灰发虚
        light: NSColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1.0)   // 浅色模式高对比度三级文本，彻底杜绝隐形
    ))

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
            .background(Theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Theme.borderSubtle, lineWidth: 1)
            )
    }
}
