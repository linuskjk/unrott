import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings

@MainActor
final class ScreenTimeManager: ObservableObject {
    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published var isAuthorizing = false
    @Published var lastErrorMessage: String?

    private let activityCenter = DeviceActivityCenter()
    // Nutzt jetzt die Store-Name Konstante korrekt
    private let managedStore = ManagedSettingsStore(named: ManagedSettingsStore.Name("com.linuskjk.unrott.shield-store"))
    private weak var appStateManager: AppStateManager?
    private let calendar = Calendar.current

    init(appStateManager: AppStateManager) {
        self.appStateManager = appStateManager
        self.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func requestAuthorizationIfNeeded() async {
        refreshAuthorizationStatus()
        
        // Wenn bereits genehmigt, nichts tun
        if authorizationStatus == .approved { return }

        isAuthorizing = true
        
        do {
            // Wichtig: Request explizit auf dem Main-Thread ausführen
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshAuthorizationStatus()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Zugriff verweigert: \(error.localizedDescription)"
            print("ScreenTime Error: \(error)")
        }
        
        isAuthorizing = false
    }

    func syncMonitoring(with state: SharedAppState) {
        refreshAuthorizationStatus()

        guard authorizationStatus == .approved, state.hasSelection else {
            stopMonitoringAndClearShield()
            return
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        let thresholdMinutes = max(1, state.totalAllowanceMinutes)
        
        // FIX für den Build-Fehler (iOS 17.4 Kompatibilität)
        let event: DeviceActivityEvent
        if #available(iOS 17.4, *) {
            event = DeviceActivityEvent(
                applications: state.selection.applicationTokens,
                categories: state.selection.categoryTokens,
                webDomains: state.selection.webDomainTokens,
                threshold: DateComponents(minute: thresholdMinutes),
                includesPastActivity: true
            )
        } else {
            event = DeviceActivityEvent(
                applications: state.selection.applicationTokens,
                categories: state.selection.categoryTokens,
                webDomains: state.selection.webDomainTokens,
                threshold: DateComponents(minute: thresholdMinutes)
            )
        }

        do {
            activityCenter.stopMonitoring([DeviceActivityName("com.linuskjk.unrott.monitor")])
            try activityCenter.startMonitoring(
                DeviceActivityName("com.linuskjk.unrott.monitor"),
                during: schedule,
                events: [DeviceActivityEvent.Name("com.linuskjk.unrott.limit-reached"): event]
            )
        } catch {
            lastErrorMessage = "Monitoring Fehler: \(error.localizedDescription)"
        }

        if state.isBlocked || state.remainingMinutes <= 0 {
            applyShield(for: state.selection)
        } else {
            clearShield()
        }
    }

    func stopMonitoringAndClearShield() {
        activityCenter.stopMonitoring([DeviceActivityName("com.linuskjk.unrott.monitor")])
        clearShield()
    }

    private func applyShield(for selection: FamilyActivitySelection) {
        managedStore.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        managedStore.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        
        if !selection.categoryTokens.isEmpty {
            managedStore.shield.applicationCategories = .specific(selection.categoryTokens)
            managedStore.shield.webDomainCategories = .specific(selection.categoryTokens)
        }
    }

    func clearShield() {
        managedStore.shield.applications = nil
        managedStore.shield.applicationCategories = nil
        managedStore.shield.webDomains = nil
        managedStore.shield.webDomainCategories = nil
    }
    
    // Hilfsfunktion für den Report-Filter
    func reportFilter(for selection: FamilyActivitySelection) -> DeviceActivityFilter {
        let interval = DateInterval(start: calendar.startOfDay(for: Date()), end: Date())
        return DeviceActivityFilter(
            segment: .daily(during: interval),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens
        )
    }
}
