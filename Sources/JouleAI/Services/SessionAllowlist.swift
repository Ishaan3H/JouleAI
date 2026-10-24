import AppKit

/// Everything a running session allows, worked out once when you press Start.
///
/// It combines three sources:
/// 1. **Launch targets**: the apps they open in, and their web links.
/// 2. **The commitment's preset** (e.g. "Coding"), if it picked one.
/// 3. **The commitment's own rules**, plus its older "extra allowed apps".
///
/// The lock asks it two questions: "may this app be in front?" and "may this
/// browser tab be open?".
@MainActor
struct SessionAllowlist {

    /// Allowed apps, most important first (launch-target apps lead, so
    /// "Back to task" returns to the app you started in).
    private(set) var apps: [String] = []
    /// Website rules from the preset, the commitment, and narrowed launch links.
    private(set) var siteRules: [AllowRule] = []
    /// Launch-target links that allow their whole site (e.g. your Google Doc
    /// allows docs.google.com, so you can open its sibling docs and sign in).
    private(set) var targetSites: [URL] = []
    /// Launch-target links, used to find "your" tab again.
    private(set) var targetLinks: [URL] = []

    /// True when this session has any website rules, so browsers are checked.
    var watchesWeb: Bool { !siteRules.isEmpty || !targetSites.isEmpty }

    /// Launch links on these sites only allow that exact page, not the whole
    /// site, so a YouTube playlist target doesn't open up all of YouTube.
    private static let narrowSites: Set<String> = [
        "youtube.com", "instagram.com", "x.com", "twitter.com", "reddit.com", "tiktok.com", "facebook.com",
    ]

    init(commitment: Commitment, preset: AllowPreset?) {
        func addApp(_ id: String?) {
            if let id, !apps.contains(id) { apps.append(id) }
        }

        // 1. Launch targets.
        for app in Launcher.allowedApps(for: commitment) { addApp(app) }
        for link in Launcher.webTargets(of: commitment) {
            targetLinks.append(link)
            if let host = SiteMatch.normalizedHost(link), Self.narrowSites.contains(host),
               let exact = AllowRule.site(from: link.absoluteString) {
                siteRules.append(exact)
            } else {
                targetSites.append(link)
            }
        }

        // 2 + 3. Preset and the commitment's own rules.
        for rule in (preset?.rules ?? []) + (commitment.allowRules ?? []) {
            switch rule.kind {
            case .app: addApp(rule.value)
            case .site: siteRules.append(rule)
            }
        }
    }

    // MARK: - The two questions

    /// May this app be in front during the session?
    func allowsApp(_ bundleID: String) -> Bool {
        if bundleID == Bundle.main.bundleIdentifier || Launcher.systemApps.contains(bundleID) { return true }
        if apps.contains(bundleID) { return true }
        // With website rules, browsers are allowed: readable ones have their tabs
        // checked; unreadable ones (Firefox, Zen) are allowed whole, since their
        // tabs can't be seen.
        if watchesWeb {
            return BrowserTabs.browser(withID: bundleID) != nil || BrowserTabs.unreadable[bundleID] != nil
        }
        return false
    }

    /// May a tab with this address be open?
    func allowsAddress(_ address: String) -> Bool {
        guard let url = URL(string: address), SiteMatch.isWeb(url) else { return true }   // new tab, settings…
        if let host = url.host?.lowercased(), SiteMatch.signInHosts.contains(host) { return true }
        return allowsWebPage(url)
    }

    /// Does a web page match a launch site or a rule?
    func allowsWebPage(_ url: URL) -> Bool {
        targetSites.contains { SiteMatch.isSameSite(url, $0) } || siteRules.contains { $0.matches(url) }
    }

    /// Where "Back to task" sends a browser when no allowed tab is open:
    /// your first launch link, else the first website rule.
    var fallbackPage: URL? {
        targetLinks.first ?? siteRules.first.flatMap { URL(string: "https://" + $0.value) }
    }
}
