import SwiftUI
import AppKit

// 应用生命周期代理
final class AppDelegate: NSObject, NSApplicationDelegate {
    // 设置应用图标
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns") ?? Bundle.main.path(forResource: "AppIcon", ofType: "png"),
           let image = NSImage(contentsOfFile: iconPath) {
            NSApplication.shared.applicationIconImage = image
        }
    }
}

// 主应用入口
@main
struct VBANUltimateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainContainerView()
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            SidebarCommands()
        }
    }
}
