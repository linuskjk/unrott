import SwiftUI
import Combine

struct RootView: View {
    @EnvironmentObject private var appStateManager: AppStateManager
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            AppSelectionView()
                .tabItem {
                    Label("Setup", systemImage: "slider.horizontal.3")
                }

            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            PushUpWorkoutView()
                .tabItem {
                    Label("Push-Ups", systemImage: "figure.strengthtraining.traditional")
                }
        }
        .tint(AppTheme.tint)
        .toolbarBackground(Color.white.opacity(0.88), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .fontDesign(.rounded)
        .task {
            await screenTimeManager.requestAuthorizationIfNeeded()
            appStateManager.refreshFromStore()
            screenTimeManager.syncMonitoring(with: appStateManager.state)
        }
        .onReceive(appStateManager.$state.dropFirst()) { state in
            screenTimeManager.syncMonitoring(with: state)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                appStateManager.refreshFromStore()
                screenTimeManager.refreshAuthorizationStatus()
                screenTimeManager.syncMonitoring(with: appStateManager.state)
            case .background:
                screenTimeManager.syncMonitoring(with: appStateManager.state)
            default:
                break
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        let appStateManager = AppStateManager()
        let screenTimeManager = ScreenTimeManager(appStateManager: appStateManager)

        RootView()
            .environmentObject(appStateManager)
            .environmentObject(screenTimeManager)
    }
}
