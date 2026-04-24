//
//  ScreenTimeReportExtention.swift
//  ScreenTimeReportExtention
//
//  Created by Linus on 24.04.26.
//

import DeviceActivity
import SwiftUI

@main
struct ScreenTimeReportExtention: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // Create a report for each DeviceActivityReport.Context that your app supports.
        TotalActivityReport { totalActivity in
            TotalActivityView(totalActivity: totalActivity)
        }
        // Add more reports here...
    }
}
