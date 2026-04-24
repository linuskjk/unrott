import SwiftUI

@available(iOS 17.0, *) // Diese Zeile MUSS nach oben
@main
struct UnrottApp: App {
    @StateObject private var appStateManager: AppStateManager
    @StateObject private var screenTimeManager: ScreenTimeManager

    init() {
        let stateManager = AppStateManager()
        _appStateManager = StateObject(wrappedValue: stateManager)
        _screenTimeManager = StateObject(wrappedValue: ScreenTimeManager(appStateManager: stateManager))
    }

    var body: some Scene {
        WindowGroup {
            RootView() // Stelle sicher, dass RootView auch in der ContentView.swift ist
                .environmentObject(appStateManager)
                .environmentObject(screenTimeManager)
        }
    }
}
