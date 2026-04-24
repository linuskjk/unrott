import SwiftUI

@main
struct UnrottApp: App {
    @StateObject private var appStateManager = AppStateManager()
    @StateObject private var screenTimeManager: ScreenTimeManager

    init() {
        let stateManager = AppStateManager()
        _appStateManager = StateObject(wrappedValue: stateManager)
        _screenTimeManager = StateObject(wrappedValue: ScreenTimeManager(appStateManager: stateManager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appStateManager)
                .environmentObject(screenTimeManager)
        }
    }
}
