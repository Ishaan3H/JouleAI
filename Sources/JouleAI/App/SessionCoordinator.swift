import AppKit
import Observation

/// Runs everything that happens around a commitment:
///
/// 0. **Lead-up**: 20 minutes before, a heads-up notification and a menu bar
///    countdown ("I'll be ready" / "Push 30 min" / "Not today"); 5 minutes
///    before, a plain reminder. No blur, no mute.
/// 1. **Firing**: at start time → mute audio → show the Start card
///    (Start / Reschedule 30 min / Cancel).
/// 2. **Starting**: open the launch targets, run the Focus shortcut, play brown
///    noise, start the countdown.
/// 3. **The lock**: while the session runs, switching to an app that isn't part
///    of it brings the overlay back with "Back to task" / "End early".
/// 4. **Ending**: when time runs out or you break the commitment.
///
/// `AppState` holds the data; this class holds the moving parts (timers,
/// overlay windows, audio) and decides when to use them.
@MainActor
@Observable
final class SessionCoordinator {

    /// Everything about the session that's currently running.
    struct ActiveSession {
        var commitment: Commitment
        var session: Session
        let endsAt: Date
        /// Bundle IDs of apps you may use during the session, most important first.
        let allowedApps: [String]
        /// The browser whose tabs are checked, and the web links tabs must match.
        /// Tab checking is off when either is missing.
        let browser: BrowserTabs.Browser?
        let webTargets: [URL]
        /// Test sessions (from the Debug menu) aren't saved to history.
        let isTest: Bool
    }

    // MARK: - State the UI reads

    /// The commitment whose Start card is on screen, if any.
    private(set) var firingCommitment: Commitment?
    /// The session in progress, if any.
    private(set) var activeSession: ActiveSession?
    /// Seconds left in the active session (updated every second).
    private(set) var remainingSeconds = 0
    /// True while the Settings "Preview" button is playing brown noise.
    private(set) var isPreviewingNoise = false

    /// The next committed item starting within 20 minutes, if any.
    private(set) var upcoming: Commitment?
    /// Seconds until `upcoming` starts (updated every second).
    private(set) var secondsUntilStart = 0

    /// e.g. "23:10" while a session runs, `nil` otherwise. Shown in the menu bar.
    var remainingText: String? {
        activeSession == nil ? nil : Self.clockText(seconds: remainingSeconds)
    }

    /// e.g. "12:34" while counting down to the next session, `nil` otherwise.
    var upcomingText: String? {
        upcoming == nil ? nil : Self.clockText(seconds: secondsUntilStart)
    }

    // MARK: - Parts

    // `@ObservationIgnored` means "SwiftUI doesn't need to watch this property".
    @ObservationIgnored private let appState: AppState
    @ObservationIgnored private let overlay = OverlayController()
    @ObservationIgnored private let audio = AudioMuter()
    @ObservationIgnored private let noise = BrownNoisePlayer()
    @ObservationIgnored private let endWindow = EndOfSessionWindowController()
    @ObservationIgnored private let notifier = Notifier()
    @ObservationIgnored private var scheduler: Scheduler?
    /// Ticks every second for the countdowns (session time left, time until next).
    @ObservationIgnored private var clockTimer: Timer?
    @ObservationIgnored private var appSwitchObserver: NSObjectProtocol?
    /// True while the lock card (not the Start card) is on screen.
    @ObservationIgnored private var isLockShowing = false
    /// Apps you switched to that aren't part of the session. "Back to task" hides them.
    @ObservationIgnored private var strayApps: [NSRunningApplication] = []
    /// True when the lock on screen was caused by an off-task browser tab.
    @ObservationIgnored private var lockedForTab = false
    /// The tab check waits until this time, so pages have a moment to load
    /// after Start or Back to task before being judged.
    @ObservationIgnored private var tabCheckPausedUntil = Date.distantPast

    init(appState: AppState) {
        self.appState = appState

        notifier.onAction = { [weak self] action, id in
            self?.respond(action, to: id, via: "notification")
        }
        notifier.setUp()

        scheduler = Scheduler { [weak self] in self?.tick() }
        scheduler?.start()

        let clock = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.clockTick() }
        }
        RunLoop.main.add(clock, forMode: .common)   // keep ticking while menus are open
        clockTimer = clock

        // If JouleAI quits while the overlay is up, don't leave the Mac muted.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.audio.restore() }
        }
    }

    /// Called every 30 seconds and on wake: re-read the calendar, then run each
    /// stage that's due.
    func tick() {
        appState.refresh()
        sendLeadUpNotifications()
        checkForDueCommitment()
        updateUpcoming()
    }

    // MARK: - 0. Lead-up

    private func sendLeadUpNotifications() {
        for item in appState.headsUpsDue() {
            appState.update(item.id) { $0.headsUpShownAt = Date() }
            notifier.sendHeadsUp(for: item)
            EventLog.record(.headsUpShown, item,
                            detail: "starts \(Self.time(item.startTime))")
        }
        for item in appState.remindersDue() {
            appState.update(item.id) { $0.reminderShownAt = Date() }
            notifier.sendReminder(for: item)
            EventLog.record(.reminderShown, item,
                            detail: "starts \(Self.time(item.startTime))")
        }
    }

    /// Handles a heads-up answer, from the notification's buttons or the menu bar.
    /// `via` is recorded in the log ("notification" or "menu bar").
    func respond(_ action: Notifier.Action, to id: Commitment.ID, via: String) {
        guard let item = appState.commitment(withID: id), !item.isCancelled,
              !appState.hasSession(for: id) else { return }
        notifier.removeHeadsUp(for: id)

        switch action {
        case .ready:
            appState.update(id) { $0.headsUpResponse = .ready }
            EventLog.record(.respondedReady, item, detail: "via \(via)")
        case .push:
            guard item.canReschedule else { return }
            appState.update(id) { $0.headsUpResponse = .push }
            EventLog.record(.respondedPush, item, detail: "via \(via)")
            reschedule(item, to: item.startTime.addingTimeInterval(30 * 60), from: "heads-up")
        case .notToday:
            appState.update(id) { $0.headsUpResponse = .notToday }
            EventLog.record(.respondedNotToday, item, detail: "via \(via)")
            cancel(item, from: "heads-up")
        }
        updateUpcoming()
    }

    /// Moves a commitment to `newStart` (once per commitment). Its heads-up and
    /// reminder will show again for the new time.
    private func reschedule(_ item: Commitment, to newStart: Date, from source: String) {
        guard item.canReschedule else { return }
        appState.update(item.id) { c in
            c.originalStartTime = c.originalStartTime ?? c.startTime
            c.startTime = newStart
            c.rescheduleCount = (c.rescheduleCount ?? 0) + 1
            c.headsUpShownAt = nil
            c.headsUpResponse = nil
            c.reminderShownAt = nil
        }
        EventLog.record(.rescheduled, item,
                        detail: "\(Self.time(item.startTime)) → \(Self.time(newStart)) (from \(source))")
        // If the new time is already within 20 minutes, the heads-up goes out now.
        sendLeadUpNotifications()
    }

    /// Cancels a commitment for today. It's recorded as a skipped session so it
    /// won't fire again and counts as skipped in history.
    private func cancel(_ item: Commitment, from source: String) {
        let now = Date()
        appState.update(item.id) { c in
            c.cancelledAt = now
            c.isCommitted = false
        }
        appState.saveSession(Session(
            commitmentId: item.id,
            commitmentTitle: item.title,
            startedAt: now,
            endedAt: now,
            outcome: .skipped
        ))
        EventLog.record(.cancelled, item, detail: "from \(source)")
    }

    /// Keeps the menu bar countdown pointed at the next session.
    private func updateUpcoming() {
        let next = activeSession == nil && firingCommitment == nil ? appState.upcoming() : nil
        if next != upcoming { upcoming = next }
        secondsUntilStart = next.map { max(0, Int($0.startTime.timeIntervalSinceNow.rounded(.up))) } ?? 0
    }

    /// Debug menu: adds a real 1-minute commitment starting in 6 minutes, so the
    /// whole lead-up can be tested quickly: the heads-up appears straight away
    /// (it's inside the 20-minute window), the reminder at 5 minutes, and the
    /// overlay at start time. It's logged like any other commitment.
    func addTestSession() {
        let start = Date().addingTimeInterval(6 * 60)
        var test = Commitment(title: "Test session", startTime: start,
                              durationMinutes: 1, source: .manual)
        test.isCommitted = true
        appState.save(test)
        tick()
    }

    // MARK: - 1. Firing

    /// Shows the Start card if something is due.
    func checkForDueCommitment() {
        // One thing at a time: not while a card is up or a session is running.
        guard firingCommitment == nil, activeSession == nil else { return }
        guard let due = appState.dueCommitment() else { return }
        fire(due, isTest: false)
    }

    /// Debug menu: show the Start card right now with a made-up commitment.
    /// Pressing Start runs a 2-minute session with no launch targets, so any app
    /// you switch to triggers the lock. Nothing is saved to history.
    func testOverlay() {
        guard firingCommitment == nil, activeSession == nil else { return }
        let test = Commitment(
            title: "Test commitment",
            startTime: Date(),
            durationMinutes: 2,
            source: .manual
        )
        fire(test, isTest: true,
             noteOverride: "This is where your note from last time will appear.")
    }

    private func fire(_ commitment: Commitment, isTest: Bool, noteOverride: String? = nil) {
        firingCommitment = commitment
        updateUpcoming()
        audio.mute()
        EventLog.record(.overlayShown, commitment, isTest: isTest)

        let card = StartCardView(
            title: commitment.title,
            startTime: commitment.startTime,
            durationMinutes: commitment.durationMinutes,
            leftOffNote: noteOverride ?? appState.lastLeftOffNote(for: commitment),
            canReschedule: commitment.canReschedule,
            onStart: { [weak self] in self?.start(commitment, isTest: isTest) },
            onReschedule: { [weak self] in self?.rescheduleFromOverlay(commitment, isTest: isTest) },
            onCancel: { [weak self] in self?.cancelFromOverlay(commitment, isTest: isTest) }
        )
        overlay.show(card)
    }

    /// Cancel on the Start card (unlocks after 30 seconds).
    private func cancelFromOverlay(_ commitment: Commitment, isTest: Bool) {
        if isTest {
            EventLog.record(.cancelled, commitment, detail: "from overlay", isTest: true)
        } else {
            cancel(commitment, from: "overlay")
        }
        closeStartCard()
    }

    /// "Reschedule 30 min" on the Start card (unlocks after 30 seconds; only
    /// offered if the commitment hasn't been pushed back already).
    private func rescheduleFromOverlay(_ commitment: Commitment, isTest: Bool) {
        let newStart = Date().addingTimeInterval(30 * 60)
        if isTest {
            EventLog.record(.rescheduled, commitment, detail: "test (from overlay)", isTest: true)
        } else {
            reschedule(commitment, to: newStart, from: "overlay")
        }
        closeStartCard()
    }

    private func closeStartCard() {
        overlay.hide()
        audio.restore()
        firingCommitment = nil
        checkForDueCommitment()   // another one might be due too
        updateUpcoming()
    }

    // MARK: - 2. Starting

    /// The user pressed Start.
    private func start(_ commitment: Commitment, isTest: Bool) {
        overlay.hide()
        firingCommitment = nil
        // Unmute (only if JouleAI muted it) so the task and brown noise are audible.
        audio.restore()

        let now = Date()
        let session = Session(commitmentId: commitment.id,
                              commitmentTitle: commitment.title,
                              startedAt: now)
        if !isTest { appState.saveSession(session) }
        EventLog.record(.started, commitment, isTest: isTest)

        activeSession = ActiveSession(
            commitment: commitment,
            session: session,
            endsAt: now.addingTimeInterval(TimeInterval(commitment.durationMinutes * 60)),
            allowedApps: Launcher.allowedApps(for: commitment),
            browser: Launcher.sessionBrowser,
            webTargets: Launcher.webTargets(of: commitment),
            isTest: isTest
        )
        tabCheckPausedUntil = now.addingTimeInterval(5)

        Launcher.open(commitment.launchTargets)

        if AppSettings.focusEnabled {
            runShortcut(AppSettings.focusOnShortcut)
        }
        if AppSettings.brownNoiseEnabled {
            stopNoisePreview()
            noise.start(volume: AppSettings.brownNoiseVolume)
        }

        clockTick()
        startLock()
    }

    /// Runs a Focus shortcut in the background. If it doesn't exist, fail
    /// silently and leave a hint for the Settings screen.
    private func runShortcut(_ name: String) {
        Task {
            if await FocusShortcut.run(named: name) == .missing {
                AppSettings.noteFocusShortcutMissing()
            }
        }
    }

    // MARK: - Countdowns

    /// Every second: update the session's time left, and the time until the next one.
    private func clockTick() {
        updateRemaining()
        updateUpcoming()
    }

    /// Recomputes the time left from the end time (not by counting ticks), so
    /// it stays correct even after the Mac sleeps.
    private func updateRemaining() {
        guard let active = activeSession else { return }
        remainingSeconds = max(0, Int(active.endsAt.timeIntervalSinceNow.rounded(.up)))
        if remainingSeconds == 0 {
            finishSession(outcome: nil, breakReason: nil)
        } else {
            checkBrowserTab()
        }
    }

    // MARK: - 3. The lock

    /// Starts watching which app is in front.
    private func startLock() {
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.appDidActivate(app) }
        }
    }

    private func stopLock() {
        if let appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appSwitchObserver)
        }
        appSwitchObserver = nil
        isLockShowing = false
        strayApps.removeAll()
    }

    /// Runs every second. If the session browser is in front and its selected
    /// tab is on a site that isn't one of the task's links, show the lock.
    ///
    /// Switching tabs doesn't announce itself the way switching apps does, so
    /// the only way to notice is to look regularly.
    private func checkBrowserTab() {
        guard let active = activeSession,
              let browser = active.browser,
              !active.webTargets.isEmpty,
              !isLockShowing,
              Date() >= tabCheckPausedUntil,
              NSWorkspace.shared.frontmostApplication?.bundleIdentifier == browser.bundleID,
              let address = BrowserTabs.currentURL(in: browser)
        else { return }

        if !SiteMatch.isOnTask(address, targets: active.webTargets) {
            showLock(forTab: true)
        }
    }

    /// Called whenever any app comes to the front during a session.
    private func appDidActivate(_ app: NSRunningApplication?) {
        guard let active = activeSession, let bundleID = app?.bundleIdentifier else { return }

        let allowed = bundleID == Bundle.main.bundleIdentifier ||
                      Launcher.systemApps.contains(bundleID) ||
                      active.allowedApps.contains(bundleID)
        guard !allowed, let app else { return }
        if !strayApps.contains(app) { strayApps.append(app) }

        // Already showing the lock? Leave it alone, so an End-early countdown in
        // progress isn't reset. (The overlay takes the keyboard back by itself.)
        guard !isLockShowing else { return }
        showLock(forTab: false)
    }

    private func showLock(forTab: Bool) {
        guard let active = activeSession else { return }
        isLockShowing = true
        lockedForTab = forTab
        let card = LockCardView(
            title: active.commitment.title,
            endsAt: active.endsAt,
            detail: forTab ? "That tab isn't part of this session." : nil,
            onBackToTask: { [weak self] in self?.backToTask() },
            onBreak: { [weak self] reason in self?.finishSession(outcome: .brokeEarly, breakReason: reason) }
        )
        overlay.show(card)
    }

    /// Hides the apps you strayed into and takes you back to the task:
    /// - if the lock was for a browser tab, or the task's main app is the
    ///   browser, switch to the task's tab (reopening it if it was closed);
    /// - otherwise bring the task's first app forward.
    private func backToTask() {
        overlay.hide()
        isLockShowing = false
        strayApps.forEach { $0.hide() }
        strayApps.removeAll()
        tabCheckPausedUntil = Date().addingTimeInterval(3)

        guard let active = activeSession else { return }
        let firstApp = active.allowedApps.first
        if let browser = active.browser, !active.webTargets.isEmpty,
           lockedForTab || firstApp == browser.bundleID {
            BrowserTabs.showTaskTab(for: active.webTargets, in: browser)
        } else if let firstApp {
            Launcher.bringToFront(bundleID: firstApp)
        }
        lockedForTab = false
    }

    // MARK: - 4. Ending

    /// Stops everything, records how the session ended, turns Focus off, and
    /// opens the end-of-session window.
    ///
    /// `outcome` is `nil` when time simply ran out (the window then asks
    /// Done / Partly / Didn't), or `.brokeEarly` after the End-early flow.
    private func finishSession(outcome: Session.Outcome?, breakReason: String?) {
        guard var active = activeSession else { return }

        stopLock()
        overlay.hide()
        noise.stop()
        if AppSettings.focusEnabled {
            runShortcut(AppSettings.focusOffShortcut)
        }

        active.session.endedAt = Date()
        active.session.outcome = outcome
        active.session.breakReason = breakReason
        if !active.isTest { appState.saveSession(active.session) }
        if outcome == .brokeEarly {
            EventLog.record(.brokeOut, active.commitment,
                            detail: breakReason.map { "reason: \($0)" }, isTest: active.isTest)
        } else if outcome == nil {
            EventLog.record(.completed, active.commitment, isTest: active.isTest)
        }

        activeSession = nil
        remainingSeconds = 0
        askForReflection(active.session, commitment: active.commitment, isTest: active.isTest)
        checkForDueCommitment()
    }

    // MARK: - 5. Reflection ("Where did you leave off?")

    /// Opens the end-of-session window for a finished session.
    private func askForReflection(_ session: Session, commitment: Commitment, isTest: Bool) {
        endWindow.show(
            title: session.commitmentTitle,
            endedEarly: session.outcome == .brokeEarly,
            onSave: { [weak self] outcome, note in
                self?.saveReflection(sessionID: session.id, commitment: commitment,
                                     outcome: outcome, note: note, isTest: isTest)
            },
            onSkip: { [weak self] in
                self?.skipReflection(sessionID: session.id, commitment: commitment, isTest: isTest)
            }
        )
    }

    /// Save: record the outcome (unless it ended early) and the note.
    private func saveReflection(sessionID: Session.ID, commitment: Commitment,
                                outcome: Session.Outcome?, note: String, isTest: Bool) {
        let detail = [outcome.map { "\($0.rawValue)" }, note.isEmpty ? nil : "note: \(note)"]
            .compactMap { $0 }.joined(separator: " · ")
        EventLog.record(.reflected, commitment, detail: detail.isEmpty ? nil : detail, isTest: isTest)

        guard !isTest, var session = appState.session(withID: sessionID) else { return }
        if let outcome { session.outcome = outcome }
        session.leftOffNote = note.isEmpty ? nil : note
        appState.saveSession(session)
    }

    /// Skip (or the window was closed): leave it unrecorded. The first time,
    /// remember it so the window can come back once from the popover.
    private func skipReflection(sessionID: Session.ID, commitment: Commitment, isTest: Bool) {
        EventLog.record(.reflectionSkipped, commitment, isTest: isTest)
        guard !isTest, var session = appState.session(withID: sessionID) else { return }
        if session.reflectionSkippedAt == nil {
            session.reflectionSkippedAt = Date()
            appState.saveSession(session)
        }
    }

    /// Called when the popover opens: if a recent session's window was skipped,
    /// bring it back once. After that it stays unrecorded.
    func offerPendingReflection() {
        guard activeSession == nil, firingCommitment == nil, !endWindow.isVisible,
              var session = appState.sessionNeedingReflection() else { return }
        session.reflectionReaskedAt = Date()
        appState.saveSession(session)
        let commitment = appState.commitment(withID: session.commitmentId)
            ?? Commitment(id: session.commitmentId, title: session.commitmentTitle,
                          startTime: session.startedAt, durationMinutes: 0, source: .manual)
        askForReflection(session, commitment: commitment, isTest: false)
    }

    // MARK: - Brown noise (Settings)

    func setNoiseVolume(_ volume: Float) {
        noise.setVolume(volume)
    }

    func toggleNoisePreview() {
        if isPreviewingNoise {
            stopNoisePreview()
        } else if activeSession == nil {
            noise.start(volume: AppSettings.brownNoiseVolume)
            isPreviewingNoise = true
        }
    }

    func stopNoisePreview() {
        guard isPreviewingNoise else { return }
        noise.stop()
        isPreviewingNoise = false
    }

    // MARK: - Formatting

    /// e.g. "14:30" (or "2:30 PM", following the Mac's settings).
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// 1390 → "23:10", 3725 → "1:02:05".
    static func clockText(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }
}
