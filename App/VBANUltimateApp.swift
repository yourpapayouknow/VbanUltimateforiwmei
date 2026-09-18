import SwiftUI

@main
struct VBANUltimateApp: App {
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
