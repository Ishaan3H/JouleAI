import AppKit
import CryptoKit

/// Writes everything JouleAI knows about your sessions into one JSON file in
/// `~/Downloads`, so a tester can send it back by hand (email, chat, AirDrop).
///
/// Nothing is uploaded: this only reads the files in `Storage.directory` and
/// writes a new file. With `anonymise` on, anything you typed (commitment
/// titles, notes, parked thoughts, break reasons, links and file paths) is
/// replaced by a short stable code like `title-3f2a`. "Stable" means the same
/// text always gets the same code, so you can still tell that two sessions
/// were for the same commitment without knowing what it was.
///
/// The files are read as plain JSON (not decoded into `Session` etc.) so the
/// export keeps every field, including ones added in later versions.
enum DataExport {

    /// The command-line flag that runs an export and quits (see JouleAIApp).
    static let flag = "--export-data"
    static var isRequested: Bool { CommandLine.arguments.contains(flag) }

    /// Builds the export and writes it to `~/Downloads/JouleAI-export-<date>.json`.
    /// Returns the file's location. Throws if the file can't be written.
    @discardableResult
    static func run(anonymise: Bool) throws -> URL {
        let anonymiser = Anonymiser(enabled: anonymise)

        let export: [String: Any] = [
            "exportFormat": 1,
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "appVersion": appVersion,
            "macOSVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "anonymised": anonymise,
            "commitments": loadArray("commitments.json").map { anonymiser.commitment($0) },
            "sessions": loadArray("sessions.json").map { anonymiser.session($0) },
            "events": loadEvents().map { anonymiser.event($0) },
        ]

        let data = try JSONSerialization.data(withJSONObject: export,
                                              options: [.prettyPrinted, .sortedKeys])
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let url = downloads.appendingPathComponent("JouleAI-export-\(dateStamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Runs the export, then shows the file in Finder (or an alert if it failed).
    /// This is what the Settings button calls.
    @MainActor
    static func runAndReveal(anonymise: Bool) {
        do {
            let url = try run(anonymise: anonymise)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t export your data"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    // MARK: - Reading the data files

    /// A JSON file in the data folder that holds an array of objects.
    /// Missing or unreadable files become an empty array.
    private static func loadArray(_ fileName: String) -> [[String: Any]] {
        let url = Storage.directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return array
    }

    /// `events.jsonl` has one JSON object per line; this turns it into an array.
    private static func loadEvents() -> [[String: Any]] {
        let url = Storage.directory.appendingPathComponent(EventLog.fileName)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
        }
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    /// Today as "2026-10-25", for the file name.
    private static var dateStamp: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Anonymising

    /// Replaces typed text with stable codes. When `enabled` is false every
    /// method hands its input back unchanged.
    private struct Anonymiser {
        let enabled: Bool

        /// A random value made once per Mac and mixed into every code. Without
        /// it, someone could guess short titles ("Gym") by hashing common words
        /// themselves. With it, codes are stable on this Mac but unguessable.
        private static let salt: String = {
            let key = AppSettings.Key.exportSalt
            if let existing = UserDefaults.standard.string(forKey: key) { return existing }
            let new = UUID().uuidString
            UserDefaults.standard.set(new, forKey: key)
            return new
        }()

        /// "Write thesis intro" → "title-3f2a" (first 4 hex digits of SHA-256).
        func code(_ text: String, _ prefix: String) -> String {
            guard enabled else { return text }
            let digest = SHA256.hash(data: Data((Self.salt + text).utf8))
            let hex = digest.map { String(format: "%02x", $0) }.joined()
            return "\(prefix)-\(hex.prefix(4))"
        }

        /// Replaces `object[key]` with a code, if it's a string.
        private func replace(_ key: String, in object: inout [String: Any], _ prefix: String) {
            if let text = object[key] as? String { object[key] = code(text, prefix) }
        }

        func commitment(_ input: [String: Any]) -> [String: Any] {
            guard enabled else { return input }
            var output = input
            replace("title", in: &output, "title")
            // Launch targets can hold private links and file paths (with your
            // user name in them). Apps are kept: a bundle ID isn't personal.
            if let targets = output["launchTargets"] as? [[String: Any]] {
                output["launchTargets"] = targets.map { target -> [String: Any] in
                    var target = target
                    if target["kind"] as? String != "app" { replace("value", in: &target, "link") }
                    replace("label", in: &target, "label")
                    return target
                }
            }
            return output
        }

        func session(_ input: [String: Any]) -> [String: Any] {
            guard enabled else { return input }
            var output = input
            replace("commitmentTitle", in: &output, "title")
            replace("leftOffNote", in: &output, "note")
            replace("breakReason", in: &output, "reason")
            // Code each parked line on its own, so the number of items survives.
            // Lines are trimmed the same way as `Session.parkedItems`, so a line
            // gets the same code here as in its parkedDismissed event.
            if let parked = output["parkedNotes"] as? String {
                output["parkedNotes"] = parked.split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .map { code($0, "parked") }
                    .joined(separator: "\n")
            }
            return output
        }

        func event(_ input: [String: Any]) -> [String: Any] {
            guard enabled else { return input }
            var output = input
            replace("commitmentTitle", in: &output, "title")
            guard let detail = output["detail"] as? String else { return output }

            // Only these kinds put typed text in `detail`; the rest (times,
            // "via notification", app IDs, site hosts, Focus results) are kept.
            switch output["kind"] as? String {
            case "brokeOut":
                // "reason: <typed text>"
                let prefix = "reason: "
                let reason = detail.hasPrefix(prefix) ? String(detail.dropFirst(prefix.count)) : detail
                output["detail"] = prefix + code(reason, "reason")
            case "reflected":
                // "done · note: <typed text>", or just "note: <typed text>"
                if let range = detail.range(of: "note: ") {
                    output["detail"] = detail[..<range.lowerBound]
                        + "note: " + code(String(detail[range.upperBound...]), "note")
                }
            case "parkedToCommitment", "parkedDismissed":
                output["detail"] = code(detail, "parked")
            default:
                break
            }
            return output
        }
    }
}
