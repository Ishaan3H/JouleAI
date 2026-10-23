import AppKit

/// Reads and switches browser tabs using AppleScript.
///
/// Only browsers with an AppleScript "dictionary" for tabs can do this: Safari
/// and Chrome-based browsers (Chrome, Brave, Edge). Firefox-based browsers like
/// Zen have none, which is why sessions use a supported browser.
///
/// The first time JouleAI does this, macOS asks "JouleAI wants access to control
/// Google Chrome". If you say no, tab tracking quietly switches off.
@MainActor
enum BrowserTabs {

    /// A browser JouleAI can track tabs in.
    struct Browser: Hashable {
        let bundleID: String
        let name: String
        /// Safari calls the selected tab "current tab"; Chrome-likes call it "active tab".
        let isSafari: Bool
    }

    static let supported: [Browser] = [
        Browser(bundleID: "com.google.Chrome", name: "Google Chrome", isSafari: false),
        Browser(bundleID: "com.apple.Safari", name: "Safari", isSafari: true),
        Browser(bundleID: "com.brave.Browser", name: "Brave", isSafari: false),
        Browser(bundleID: "com.microsoft.edgemac", name: "Microsoft Edge", isSafari: false),
    ]

    /// Supported browsers that are actually installed on this Mac.
    static var installed: [Browser] {
        supported.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleID) != nil }
    }

    static func browser(withID bundleID: String) -> Browser? {
        supported.first { $0.bundleID == bundleID }
    }

    // MARK: - Reading

    /// The address of the selected tab in the browser's front window, or `nil`
    /// if there's no window, permission was denied, or the tab has no address.
    ///
    /// Only call this while the browser is running: telling a browser that
    /// isn't open to do something makes macOS launch it.
    static func currentURL(in browser: Browser) -> String? {
        let tabWord = browser.isSafari ? "current tab" : "active tab"
        let script = """
        tell application id "\(browser.bundleID)"
            if (count of windows) is 0 then return ""
            return URL of \(tabWord) of front window
        end tell
        """
        let value = run(script)?.stringValue
        return (value?.isEmpty ?? true) ? nil : value
    }

    // MARK: - Switching

    /// Switches to the first open tab that matches one of `targets`, bringing
    /// its window to the front. If none is open, opens the first target fresh.
    static func showTaskTab(for targets: [URL], in browser: Browser) {
        guard !targets.isEmpty else { return }

        if let (windowID, tabIndex) = findTab(matching: targets, in: browser) {
            let select = browser.isSafari
                ? "set current tab of w to tab \(tabIndex) of w"
                : "set active tab index of w to \(tabIndex)"
            run("""
            tell application id "\(browser.bundleID)"
                set w to window id \(windowID)
                \(select)
                set index of w to 1
                activate
            end tell
            """)
        } else {
            open(targets[0], in: browser)
        }
    }

    /// Opens `url` in this specific browser (not necessarily the default one).
    static func open(_ url: URL, in browser: Browser) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID) else {
            NSWorkspace.shared.open(url)   // browser not installed: fall back to the default
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
    }

    /// Finds an open tab for one of `targets`. Prefers a tab showing the exact
    /// page (e.g. that specific Google Doc); otherwise any tab on the same site.
    /// Returns the window's ID and the tab's position (1 = first tab).
    private static func findTab(matching targets: [URL], in browser: Browser) -> (Int, Int)? {
        // Ask for every window's ID and the addresses of all its tabs.
        let script = """
        tell application id "\(browser.bundleID)"
            set out to {}
            repeat with w in windows
                set end of out to {id of w, URL of every tab of w}
            end repeat
            return out
        end tell
        """
        guard let result = run(script) else { return nil }

        // Turn AppleScript's nested lists into Swift: [(windowID, [tab URLs])].
        var windows: [(id: Int, tabs: [String])] = []
        for i in stride(from: 1, through: result.numberOfItems, by: 1) {
            guard let pair = result.atIndex(i), pair.numberOfItems == 2,
                  let idDescriptor = pair.atIndex(1), let tabsDescriptor = pair.atIndex(2) else { continue }
            var tabs: [String] = []
            for t in stride(from: 1, through: tabsDescriptor.numberOfItems, by: 1) {
                tabs.append(tabsDescriptor.atIndex(t)?.stringValue ?? "")
            }
            windows.append((Int(idDescriptor.int32Value), tabs))
        }

        // Two passes: exact page first, then same site.
        for exactPage in [true, false] {
            for window in windows {
                for (index, tab) in window.tabs.enumerated() {
                    guard let tabURL = URL(string: tab) else { continue }
                    let matches = targets.contains { target in
                        exactPage ? SiteMatch.isSamePage(tabURL, target) : SiteMatch.isSameSite(tabURL, target)
                    }
                    if matches { return (window.id, index + 1) }
                }
            }
        }
        return nil
    }

    // MARK: - AppleScript

    @discardableResult
    private static func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            // -1743 means the user said no to "control Google Chrome".
            print("JouleAI: browser AppleScript failed: \(error)")
            return nil
        }
        return result
    }
}

/// Rules for deciding whether a browser tab belongs to the session.
enum SiteMatch {

    /// Sign-in pages your task's site may bounce you through. Always allowed.
    static let signInHosts: Set<String> = [
        "accounts.google.com",
        "login.microsoftonline.com",
        "login.live.com",
        "appleid.apple.com",
        "idmsa.apple.com",
    ]

    /// Is this tab fine to be on during a session with these web targets?
    ///
    /// - Non-web pages (new tab, blank page, browser settings) are fine.
    /// - Sign-in pages are fine.
    /// - Otherwise the tab must be on the same site as one of the targets
    ///   (e.g. any page on docs.google.com if a target is a Google Doc).
    static func isOnTask(_ tabAddress: String, targets: [URL]) -> Bool {
        guard let tabURL = URL(string: tabAddress),
              let scheme = tabURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return true }
        if let host = tabURL.host?.lowercased(), signInHosts.contains(host) { return true }
        return targets.contains { isSameSite(tabURL, $0) }
    }

    /// Same host, ignoring "www.", or a subdomain of the target's host
    /// (a target of youtube.com also allows m.youtube.com).
    static func isSameSite(_ a: URL, _ target: URL) -> Bool {
        guard let tabHost = normalizedHost(a), let targetHost = normalizedHost(target) else { return false }
        return tabHost == targetHost || tabHost.hasSuffix("." + targetHost)
    }

    /// Same site, and the tab's path starts with the target's path
    /// (so ".../document/d/abc/edit#heading" matches ".../document/d/abc/edit").
    static func isSamePage(_ a: URL, _ target: URL) -> Bool {
        isSameSite(a, target) && a.path.hasPrefix(target.path)
    }

    private static func normalizedHost(_ url: URL) -> String? {
        guard var host = url.host?.lowercased() else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }
}
