import SwiftUI

@main
struct TextAnonymizerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(
            width: AppTheme.defaultWindowWidth,
            height: AppTheme.defaultWindowHeight
        )
        .windowResizability(.contentSize)
    }
}
