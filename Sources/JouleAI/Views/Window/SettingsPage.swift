import SwiftUI

/// What the Settings page's buttons do, and the bits of live state it shows.
/// MainWindowView fills this in from the SessionCoordinator.
struct SettingsActions {
    var isPreviewingNoise = false
    var inSession = false
    var setNoiseVolume: (Float) -> Void = { _ in }
    var toggleNoisePreview: () -> Void = {}
    var stopNoisePreview: () -> Void = {}
    var testOverlay: () -> Void = {}
    var addTestSession: () -> Void = {}
}

/// The Settings tab.
///
/// `@AppStorage` reads and writes a `UserDefaults` value directly, using the
/// same keys as `AppSettings`, so changes here take effect immediately.
struct SettingsPage: View {

    var actions = SettingsActions()

    @AppStorage(AppSettings.Key.sessionBrowser) private var sessionBrowser = "com.google.Chrome"

    @AppStorage(AppSettings.Key.focusEnabled) private var focusEnabled = true
    @AppStorage(AppSettings.Key.focusOnShortcut) private var focusOnShortcut = "JouleAI Focus On"
    @AppStorage(AppSettings.Key.focusOffShortcut) private var focusOffShortcut = "JouleAI Focus Off"
    @AppStorage(AppSettings.Key.focusShortcutMissing) private var focusShortcutMissing = false

    @AppStorage(AppSettings.Key.brownNoiseEnabled) private var brownNoiseEnabled = true
    @AppStorage(AppSettings.Key.brownNoiseVolume) private var brownNoiseVolume = 0.3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xxl) {
                Text("Settings").font(Theme.Font.title).foregroundStyle(Theme.text)
                browserSection
                PresetsSection()
                focusSection
                noiseSection
                debugSection
                Button("Quit JouleAI") { NSApp.terminate(nil) }
                    .buttonStyle(TextButtonStyle(color: Theme.danger))
            }
            .padding(Theme.Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Don't leave the preview playing after leaving this page.
        .onDisappear { actions.stopNoisePreview() }
    }

    // MARK: - Sections

    /// A titled group of rows on a card, with hairlines between rows.
    private func group<Content: View>(_ title: String, footer: String? = nil,
                                      @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            SectionLabel(title)
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: Theme.Space.l)
            if let footer {
                Text(footer)
                    .font(Theme.Font.detail)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var divider: some View { Rectangle().fill(Theme.border).frame(height: 1) }

    private var browserSection: some View {
        group("Browser", footer: "Task links open in this browser. During a session with website rules, tabs are checked in Safari, Chrome, Arc, Brave and Edge. Firefox-based browsers like Zen can’t be checked, so they’re allowed whole.") {
            SettingRow(title: "Open web links in") {
                Picker("", selection: $sessionBrowser) {
                    ForEach(BrowserTabs.installed, id: \.bundleID) { browser in
                        Text(browser.name).tag(browser.bundleID)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    private var focusSection: some View {
        group("Focus") {
            SettingRow(title: "Turn on Focus during sessions",
                       subtitle: "Runs your Shortcuts by name when a session starts and ends.") {
                Toggle("", isOn: $focusEnabled).toggleStyle(.switch).tint(Theme.accent).labelsHidden()
            }
            divider
            SettingRow(title: "“On” shortcut") {
                TextField("", text: $focusOnShortcut).fieldStyle().frame(width: 200)
            }
            .disabled(!focusEnabled)
            SettingRow(title: "“Off” shortcut") {
                TextField("", text: $focusOffShortcut).fieldStyle().frame(width: 200)
            }
            .disabled(!focusEnabled)

            if focusShortcutMissing {
                divider
                focusHint
            }
        }
    }

    /// Shown once JouleAI has tried to run a Focus shortcut that doesn't exist.
    private var focusHint: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Label("JouleAI couldn’t find your Focus shortcut", systemImage: "exclamationmark.triangle")
                .font(Theme.Font.bodyEmphasis)
                .foregroundStyle(Theme.warning)
            Text("""
            1. Open the Shortcuts app and click +.
            2. Name it exactly “\(focusOnShortcut)”.
            3. Add “Set Focus”, choose Do Not Disturb, and set it to On.
            4. Make “\(focusOffShortcut)” the same way, set to Off.
            """)
            .font(Theme.Font.detail)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Space.s) {
                Button("Open Shortcuts") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                }
                .buttonStyle(OutlineButtonStyle())
                Button("Got it") {
                    focusShortcutMissing = false
                    UserDefaults.standard.set(true, forKey: AppSettings.Key.focusHintDismissed)
                }
                .buttonStyle(TextButtonStyle())
            }
        }
    }

    private var noiseSection: some View {
        group("Brown noise") {
            SettingRow(title: "Play brown noise during sessions") {
                Toggle("", isOn: $brownNoiseEnabled).toggleStyle(.switch).tint(Theme.accent).labelsHidden()
            }
            divider
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "speaker.fill").foregroundStyle(Theme.textTertiary)
                Slider(value: $brownNoiseVolume, in: 0...1)
                    .tint(Theme.accent)
                    // Apply volume changes live to anything already playing.
                    .onChange(of: brownNoiseVolume) { _, newValue in
                        actions.setNoiseVolume(Float(newValue))
                    }
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(Theme.textTertiary)
                Button(actions.isPreviewingNoise ? "Stop" : "Preview", action: actions.toggleNoisePreview)
                    .buttonStyle(OutlineButtonStyle())
                    .disabled(actions.inSession)
            }
            .disabled(!brownNoiseEnabled)
        }
    }

    private var debugSection: some View {
        group("Testing") {
            HStack(spacing: Theme.Space.s) {
                Button("Test overlay now", action: actions.testOverlay)
                    .buttonStyle(OutlineButtonStyle())
                Button("Add test session in 6 min", action: actions.addTestSession)
                    .buttonStyle(OutlineButtonStyle())
                Spacer()
                Button("Data folder") { NSWorkspace.shared.open(Storage.directory) }
                    .buttonStyle(TextButtonStyle())
            }
        }
    }
}
