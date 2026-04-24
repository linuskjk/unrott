import DeviceActivity
import FamilyControls
import ManagedSettings

@main
final class ScreenTimeMonitorExtension: DeviceActivityMonitor {
    private let managedStore = ManagedSettingsStore(named: SharedConstants.managedSettingsStoreName)

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard activity == SharedConstants.monitorName else {
            return
        }

        _ = SharedStore.shared.update { state in
            state.resetForNewDayIfNeeded()
            state.isBlocked = false
        }

        clearShield()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        guard activity == SharedConstants.monitorName,
              event == SharedConstants.limitReachedEventName else {
            return
        }

        let state = SharedStore.shared.update { mutable in
            mutable.totalUsedMinutesToday = max(mutable.totalUsedMinutesToday, mutable.totalAllowanceMinutes)
            mutable.isBlocked = true
        }

        applyShield(from: state.selection)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard activity == SharedConstants.monitorName else {
            return
        }

        clearShield()
    }

    private func applyShield(from selection: FamilyActivitySelection) {
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

    private func clearShield() {
        managedStore.shield.applications = nil
        managedStore.shield.applicationCategories = nil
        managedStore.shield.webDomains = nil
        managedStore.shield.webDomainCategories = nil
    }
}
