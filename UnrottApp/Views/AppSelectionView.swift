import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    @EnvironmentObject private var appStateManager: AppStateManager
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager

    @State private var isPickerPresented = false

    private var setupProgress: Double {
        var completed = 0
        if screenTimeManager.authorizationStatus == .approved {
            completed += 1
        }
        if appStateManager.state.hasSelection {
            completed += 1
        }
        if appStateManager.state.dailyLimitMinutes > 0 {
            completed += 1
        }
        return Double(completed) / 3.0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HeroHeaderView(
                        title: "Set Your Daily Guardrails",
                        subtitle: "Choose protected apps, then lock in one shared limit for all of them.",
                        systemImage: "shield.checkered",
                        badgeText: "Setup \(Int(setupProgress * 100))%"
                    )

                    SectionCard(title: "How It Works", icon: "sparkles") {
                        Text("Pick social apps once, set one shared daily limit, then earn extra minutes with push-ups whenever the limit is reached.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    SectionCard(title: "Authorization", icon: "lock.shield") {
                        HStack {
                            Label("Status", systemImage: "checkmark.shield")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(authorizationText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(screenTimeManager.authorizationStatus == .approved ? .green : .orange)
                        }

                        Button {
                            Task {
                                await screenTimeManager.requestAuthorizationIfNeeded()
                            }
                        } label: {
                            if screenTimeManager.isAuthorizing {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Request Screen Time Access", systemImage: "hand.tap.fill")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(screenTimeManager.authorizationStatus == .approved || screenTimeManager.isAuthorizing)
                        
                        // Fehlermeldung unter dem Button anzeigen
                        if let error = screenTimeManager.lastErrorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                    }

                    SectionCard(title: "Shared Daily Limit", icon: "timer") {
                        HStack {
                            Text("Current")
                                .font(.subheadline)
                            Spacer()
                            Text(DurationFormatter.minutesString(appStateManager.state.dailyLimitMinutes))
                                .font(.headline)
                        }

                        Stepper(value: dailyLimitBinding, in: 1...300, step: 1) {
                            Text("Adjust limit")
                                .font(.subheadline)
                        }

                        Text("All selected apps use this one combined pool.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    SectionCard(title: "Protected Apps", icon: "app.badge") {
                        Button {
                            isPickerPresented = true
                        } label: {
                            Label("Choose Apps", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())

                        Text(selectionSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !appStateManager.state.hasSelection {
                            Label("Pick at least one app to activate blocking.", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    SectionCard(title: "Important", icon: "info.circle") {
                        Text("Do not include this app in the blocked list, otherwise you can lock yourself out of the unlock flow.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(AppBackgroundView())
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isPickerPresented) {
                NavigationStack {
                    FamilyActivityPicker(selection: selectionBinding)
                        .navigationTitle("Select Apps")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    isPickerPresented = false
                                }
                            }
                        }
                }
            }
        }
    }

    private var selectionBinding: Binding<FamilyActivitySelection> {
        Binding(
            get: { appStateManager.state.selection },
            set: { appStateManager.setSelection($0) }
        )
    }

    private var dailyLimitBinding: Binding<Int> {
        Binding(
            get: { appStateManager.state.dailyLimitMinutes },
            set: { appStateManager.setDailyLimitMinutes($0) }
        )
    }

    private var selectionSummary: String {
        let apps = appStateManager.state.selection.applicationTokens.count
        let categories = appStateManager.state.selection.categoryTokens.count
        let domains = appStateManager.state.selection.webDomainTokens.count
        return "Selected: \(apps) apps, \(categories) categories, \(domains) domains"
    }

    private var authorizationText: String {
        switch screenTimeManager.authorizationStatus {
        case .approved:
            return "Approved"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }
}

struct AppSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let appStateManager = AppStateManager()
        let screenTimeManager = ScreenTimeManager(appStateManager: appStateManager)

        AppSelectionView()
            .environmentObject(appStateManager)
            .environmentObject(screenTimeManager)
    }
}
