import Foundation
import DeviceActivity
import ManagedSettings

enum SharedConstants {
    static let appGroupIdentifier = "group.com.example.unrott"
    static let stateStorageKey = "com.example.unrott.shared-state"

    static let monitorName = DeviceActivityName("com.example.unrott.monitor")
    static let limitReachedEventName = DeviceActivityEvent.Name("com.example.unrott.limit-reached")

    static let managedSettingsStoreName = ManagedSettingsStore.Name("com.example.unrott.shield-store")

    static let reportContext = DeviceActivityReport.Context("com.example.unrott.usage-context")
}
