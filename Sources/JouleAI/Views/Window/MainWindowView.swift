import SwiftUI

/// The JouleAI window: a tab bar across the top, and the chosen page below.
struct MainWindowView: View {

    @Environment(MainWindowModel.self) private var model
    @Environment(SessionCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.top, 14)       // clears the window's close/minimise buttons
                .padding(.bottom, Theme.Space.m)
            Rectangle().fill(Theme.border).frame(height: 1)

            Group {
                switch model.page {
                case .commitments: CommitmentsPage()
                case .history: HistoryPage()
                case .settings: SettingsPage(actions: settingsActions)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 780, height: 580)
        .background(Theme.background)
        .ignoresSafeArea()   // draw under the transparent title bar too
    }

    /// Connects the Settings page's buttons to the coordinator.
    private var settingsActions: SettingsActions {
        SettingsActions(
            isPreviewingNoise: coordinator.isPreviewingNoise,
            inSession: coordinator.activeSession != nil,
            setNoiseVolume: { coordinator.setNoiseVolume($0) },
            toggleNoisePreview: { coordinator.toggleNoisePreview() },
            stopNoisePreview: { coordinator.stopNoisePreview() },
            testOverlay: { coordinator.testOverlay() },
            addTestSession: { coordinator.addTestSession() }
        )
    }

    private var tabBar: some View {
        HStack(spacing: Theme.Space.xs) {
            ForEach(MainWindowModel.Page.allCases, id: \.self) { page in
                let isSelected = model.page == page
                Button { model.page = page } label: {
                    Text(page.rawValue)
                        .font(Theme.Font.detail.weight(.semibold))
                        .foregroundStyle(isSelected ? Theme.text : Theme.textSecondary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background(isSelected ? Theme.surface : Color.clear, in: Capsule())
                        .overlay(Capsule().stroke(isSelected ? Theme.border : Color.clear, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
