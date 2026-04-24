import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let managedStore = ManagedSettingsStore(named: ExtensionConstants.managedSettingsStoreName)

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard activity == ExtensionConstants.monitorName else {
            return
        }

        _ = ExtensionStore.shared.update { state in
            state.resetForNewDayIfNeeded()
            state.isBlocked = false
        }

        clearShield()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard activity == ExtensionConstants.monitorName else {
            return
        }

        clearShield()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        guard activity == ExtensionConstants.monitorName,
              event == ExtensionConstants.limitReachedEventName else {
            return
        }

        let state = ExtensionStore.shared.update { mutable in
            mutable.totalUsedMinutesToday = max(mutable.totalUsedMinutesToday, mutable.totalAllowanceMinutes)
            mutable.isBlocked = true
        }

        applyShield(from: state.selection)
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

private enum ExtensionConstants {
    static let appGroupIdentifier = "group.com.linuskjk.unrott"
    static let storageKey = "unrott-app-state"
    static let monitorName = DeviceActivityName("com.linuskjk.unrott.monitor")
    static let limitReachedEventName = DeviceActivityEvent.Name("com.linuskjk.unrott.limit-reached")
    static let managedSettingsStoreName = ManagedSettingsStore.Name("com.linuskjk.unrott.shield-store")
}

private extension Date {
    static var dayIdentifier: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private struct ExtensionState: Codable {
    var dailyLimitMinutes: Int
    var earnedMinutesToday: Int
    var totalUsedMinutesToday: Int
    var isBlocked: Bool
    var selection: FamilyActivitySelection
    var lastResetDayIdentifier: String
    var updatedAt: Date

    init(
        dailyLimitMinutes: Int = 30,
        earnedMinutesToday: Int = 0,
        totalUsedMinutesToday: Int = 0,
        isBlocked: Bool = false,
        selection: FamilyActivitySelection = FamilyActivitySelection(),
        lastResetDayIdentifier: String = Date.dayIdentifier,
        updatedAt: Date = Date()
    ) {
        self.dailyLimitMinutes = max(1, dailyLimitMinutes)
        self.earnedMinutesToday = max(0, earnedMinutesToday)
        self.totalUsedMinutesToday = max(0, totalUsedMinutesToday)
        self.isBlocked = isBlocked
        self.selection = selection
        self.lastResetDayIdentifier = lastResetDayIdentifier
        self.updatedAt = updatedAt
        clamp()
    }

    var totalAllowanceMinutes: Int {
        max(1, dailyLimitMinutes + earnedMinutesToday)
    }

    mutating func resetForNewDayIfNeeded() {
        let today = Date.dayIdentifier
        guard lastResetDayIdentifier != today else {
            clamp()
            return
        }

        earnedMinutesToday = 0
        totalUsedMinutesToday = 0
        isBlocked = false
        lastResetDayIdentifier = today
        updatedAt = Date()
        clamp()
    }

    mutating func clamp() {
        dailyLimitMinutes = max(1, dailyLimitMinutes)
        earnedMinutesToday = max(0, earnedMinutesToday)
        totalUsedMinutesToday = max(0, totalUsedMinutesToday)
    }
}

private final class ExtensionStore {
    static let shared = ExtensionStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    private init() {
        defaults = UserDefaults(suiteName: ExtensionConstants.appGroupIdentifier) ?? .standard
    }

    @discardableResult
    func update(_ mutate: (inout ExtensionState) -> Void) -> ExtensionState {
        lock.lock()
        defer { lock.unlock() }

        var state: ExtensionState
        if let data = defaults.data(forKey: ExtensionConstants.storageKey),
           let decoded = try? decoder.decode(ExtensionState.self, from: data) {
            state = decoded
        } else {
            state = ExtensionState()
        }

        state.resetForNewDayIfNeeded()
        mutate(&state)
        state.clamp()
        state.updatedAt = Date()

        if let encoded = try? encoder.encode(state) {
            defaults.set(encoded, forKey: ExtensionConstants.storageKey)
        }
        return state
    }
}
