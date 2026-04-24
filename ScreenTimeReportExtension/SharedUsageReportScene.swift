import DeviceActivity
import SwiftUI

struct SharedUsageConfiguration {
    let usedMinutes: Int
}

struct SharedUsageReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = SharedConstants.reportContext

    let content: (SharedUsageConfiguration) -> SharedUsageReportView = { configuration in
        SharedUsageReportView(configuration: configuration)
    }

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> SharedUsageConfiguration {
        var totalDuration: TimeInterval = 0

        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                totalDuration += segment.totalActivityDuration
            }
        }

        let usedMinutes = max(0, Int((totalDuration / 60.0).rounded(.down)))

        _ = SharedStore.shared.update { state in
            state.totalUsedMinutesToday = usedMinutes
            state.isBlocked = state.remainingMinutes <= 0
        }

        return SharedUsageConfiguration(usedMinutes: usedMinutes)
    }
}

struct SharedUsageReportView: View {
    let configuration: SharedUsageConfiguration

    var body: some View {
        Color.clear
    }
}
