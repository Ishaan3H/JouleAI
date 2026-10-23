import AppKit

/// One thing Reckon opens when you press Start: a website, a file, or an app.
///
/// Obsidian notes are just `.url` targets, because Obsidian understands links
/// like `obsidian://open?vault=MyVault&file=Thesis`.
struct LaunchTarget: Codable, Identifiable, Hashable {

    enum Kind: String, Codable {
        case url    // value is a URL string, e.g. "https://docs.google.com/..."
        case file   // value is a file path, e.g. "/Users/me/Documents/essay.docx"
        case app    // value is an app bundle ID, e.g. "com.apple.dt.Xcode"
    }

    var id: UUID = UUID()
    var kind: Kind
    var value: String
    /// A short human-readable name shown in the UI.
    var label: String

    /// An SF Symbol name to show next to this target in lists.
    var symbolName: String {
        switch kind {
        case .url:  return "link"
        case .file: return "doc"
        case .app:  return "app"
        }
    }
}

// MARK: - Convenience builders
// These create a LaunchTarget from what the user picked, filling in a sensible label.

extension LaunchTarget {

    /// Builds a URL target from typed text. Returns `nil` if the text isn't a usable URL.
    /// If the user types "example.com" without a scheme, we assume https://.
    static func fromTypedURL(_ text: String) -> LaunchTarget? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains("://") {
            trimmed = "https://" + trimmed
        }
        guard let url = URL(string: trimmed), url.scheme != nil else { return nil }

        // Label: the host for web links ("docs.google.com"), otherwise the scheme
        // and a bit of the rest (useful for obsidian:// links).
        let label: String
        if let host = url.host, url.scheme == "http" || url.scheme == "https" {
            label = host
        } else if url.scheme == "obsidian",
                  let file = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "file" })?.value {
            label = "Obsidian: \(file)"
        } else {
            label = trimmed
        }
        return LaunchTarget(kind: .url, value: trimmed, label: label)
    }

    /// Builds a file target from a file URL chosen in a file picker.
    static func fromFile(_ fileURL: URL) -> LaunchTarget {
        LaunchTarget(kind: .file, value: fileURL.path, label: fileURL.lastPathComponent)
    }

    /// Builds an app target from an .app chosen in a file picker.
    /// Returns `nil` if the bundle has no bundle identifier (very rare).
    static func fromApp(_ appURL: URL) -> LaunchTarget? {
        guard let bundleID = Bundle(url: appURL)?.bundleIdentifier else { return nil }
        let name = FileManager.default.displayName(atPath: appURL.path)
            .replacingOccurrences(of: ".app", with: "")
        return LaunchTarget(kind: .app, value: bundleID, label: name)
    }
}
