import AppKit

/// Reads and switches browser tabs using AppleScript.
///
/// Only browsers with an AppleScript "dictionary" for tabs can do this: Safari
/// and Chromium browsers (Chrome, Arc, Brave, Edge). Firefox-based browsers like
/// Firefox and Zen have none, so JouleAI can't see their tabs; during a session
/// with website rules they're allowed as a whole instead (see SessionAllowlist).
///
/// The first time JouleAI does this, macOS asks "JouleAI wants access to control
/// Google Chrome" (per browser). If you say no, tab checking quietly switches off.
@MainActor
enum BrowserTabs {

    /// A browser JouleAI can read tabs in.
    struct Browser: Hashable {
        enum Kind { case safari, chromium, arc }
        let bundleID: String
        let name: String
        let kind: Kind
    }

    static let supported: [Browser] = [
        Browser(bundleID: "com.google.Chrome", name: "Google Chrome", kind: .chromium),
        Browser(bundleID: "com.apple.Safari", name: "Safari", kind: .safari),
        Browser(bundleID: "company.thebrowser.Browser", name: "Arc", kind: .arc),
        Browser(bundleID: "com.brave.Browser", name: "Brave", kind: .chromium),
        Browser(bundleID: "com.microsoft.edgemac", name: "Microsoft Edge", kind: .chromium),
    ]

    /// Browsers whose tabs can't be read. Bundle ID → name.
    static let unreadable: [String: String] = [
        "org.mozilla.firefox": "Firefox",
        "org.mozilla.firefoxdeveloperedition": "Firefox Developer Edition",
        "org.mozilla.nightly": "Firefox Nightly",
        "app.zen-browser.zen": "Zen",
        "io.gitlab.librewolf-community": "LibreWolf",
        "net.waterfox.waterfox": "Waterfox",
    ]

    /// Supported browsers that are actually installed on this Mac.
    static var installed: [Browser] {
        supported.filter { isInstalled($0.bundleID) }
    }

    /// Names of unreadable browsers installed on this Mac, e.g. ["Zen"].
    static var installedUnreadableNames: [String] {
        unreadable.filter { isInstalled($0.key) }.map(\.value).sorted()
    }

    static func browser(withID bundleID: String) -> Browser? {
        supported.first { $0.bundleID == bundleID }
    }

    private static func isInstalled(_ bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    // MARK: - Reading

    /// The address of the selected tab in the browser's front window, or `nil`
    /// if there's no window, permission was denied, or the tab has no address.
    ///
    /// Only call this while the browser is running: telling a browser that
    /// isn't open to do something makes macOS launch it.
    static func currentURL(in browser: Browser) -> String? {
        let tabWord = browser.kind == .safari ? "current tab" : "active tab"
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

    /// Takes you back to a tab that belongs to the session:
    /// 1. a tab showing one of `preferred` pages (e.g. your Google Doc);
    /// 2. otherwise any tab `isAllowed` accepts;
    /// 3. otherwise opens `fallback` fresh.
    /// Arc can't select tabs by script, so it always takes step 3.
    static func showTaskTab(in browser: Browser, preferred: [URL],
                            isAllowed: (URL) -> Bool, fallback: URL?) {
        if browser.kind != .arc, let (windowID, tabIndex) = findTab(in: browser, preferred: preferred, isAllowed: isAllowed) {
            let select = browser.kind == .safari
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
        } else if let fallback {
            open(fallback, in: browser)
        } else {
            Launcher.bringToFront(bundleID: browser.bundleID)
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

    /// Finds a tab to return to. Returns the window's ID and the tab's
    /// position (1 = first tab).
    private static func findTab(in browser: Browser, preferred: [URL],
                                isAllowed: (URL) -> Bool) -> (Int, Int)? {
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

        // Two passes: one of your launch pages first, then any allowed web page.
        for preferredPass in [true, false] {
            for window in windows {
                for (index, tab) in window.tabs.enumerated() {
                    guard let tabURL = URL(string: tab) else { continue }
                    let matches = preferredPass
                        ? preferred.contains { SiteMatch.isSamePage(tabURL, $0) }
                        : SiteMatch.isWeb(tabURL) && isAllowed(tabURL)
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

/// Small helpers for comparing web addresses.
enum SiteMatch {

    /// Sign-in pages your task's site may bounce you through. Always allowed.
    static let signInHosts: Set<String> = [
        "accounts.google.com",
        "login.microsoftonline.com",
        "login.live.com",
        "appleid.apple.com",
        "idmsa.apple.com",
    ]

    /// True for http:// and https:// pages (not new tabs, settings, blank pages).
    static func isWeb(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }

    /// Same host, ignoring "www.", or a subdomain of the target's host
    /// (a target of docs.google.com also allows a.docs.google.com).
    static func isSameSite(_ a: URL, _ target: URL) -> Bool {
        guard let tabHost = normalizedHost(a), let targetHost = normalizedHost(target) else { return false }
        return tabHost == targetHost || tabHost.hasSuffix("." + targetHost)
    }

    /// Same site, and the tab's path starts with the target's path
    /// (so ".../document/d/abc/edit#heading" matches ".../document/d/abc/edit").
    static func isSamePage(_ a: URL, _ target: URL) -> Bool {
        isSameSite(a, target) && a.path.hasPrefix(target.path)
    }

    /// "WWW.YouTube.com" → "youtube.com".
    static func normalizedHost(_ url: URL) -> String? {
        guard var host = url.host?.lowercased() else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }
}
