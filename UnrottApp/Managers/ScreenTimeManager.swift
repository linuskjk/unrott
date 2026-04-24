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
    private let managedStore = ManagedSettingsStore(named: SharedConstants.managedSettingsStoreName)
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
        guard authorizationStatus != .approved else {
            return
        }

        isAuthorizing = true
        defer { isAuthorizing = false }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshAuthorizationStatus()
            lastErrorMessage = nil
        } catch {
            refreshAuthorizationStatus()
            lastErrorMessage = "Authorization failed: \(error.localizedDescription)"
        }
    }

    func syncMonitoring(with state: SharedAppState) {
        refreshAuthorizationStatus()

        guard authorizationStatus == .approved else {
            stopMonitoringAndClearShield()
            return
        }

        guard state.hasSelection else {
            stopMonitoringAndClearShield()
            return
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: DateComponents(minute: 1)
        )

        let thresholdMinutes = max(1, state.totalAllowanceMinutes)
        let event = DeviceActivityEvent(
            applications: state.selection.applicationTokens,
            categories: state.selection.categoryTokens,
            webDomains: state.selection.webDomainTokens,
            threshold: DateComponents(minute: thresholdMinutes),
            includesPastActivity: true
        )

        do {
            activityCenter.stopMonitoring([SharedConstants.monitorName])
            try activityCenter.startMonitoring(
                SharedConstants.monitorName,
                during: schedule,
                events: [SharedConstants.limitReachedEventName: event]
            )
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Monitoring failed: \(error.localizedDescription)"
        }

        if state.isBlocked || state.remainingMinutes <= 0 {
            applyShield(for: state.selection)
        } else {
            clearShield()
        }
    }

    func unblockAfterReward(using state: SharedAppState) {
        appStateManager?.setBlocked(false)
        clearShield()
        syncMonitoring(with: state)
    }

    func stopMonitoringAndClearShield() {
        activityCenter.stopMonitoring([SharedConstants.monitorName])
        clearShield()
    }

    func reportFilter(for selection: FamilyActivitySelection) -> DeviceActivityFilter {
        let interval = DateInterval(start: calendar.startOfDay(for: Date()), end: Date())

        return DeviceActivityFilter(
            segment: .daily(during: interval),
            users: .all,
            devices: .all,
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens
        )
    }

    private func applyShield(for selection: FamilyActivitySelection) {
        managedStore.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        managedStore.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        if selection.categoryTokens.isEmpty {
            managedStore.shield.applicationCategories = nil
            managedStore.shield.webDomainCategories = nil
            return
        }

        managedStore.shield.applicationCategories = .specific(
            selection.categoryTokens,
            except: Set<ApplicationToken>()
        )
        managedStore.shield.webDomainCategories = .specific(
            selection.categoryTokens,
            except: Set<WebDomainToken>()
        )
    }

    func clearShield() {
        managedStore.shield.applications = nil
        managedStore.shield.applicationCategories = nil
        managedStore.shield.webDomains = nil
        managedStore.shield.webDomainCategories = nil
    }
}
