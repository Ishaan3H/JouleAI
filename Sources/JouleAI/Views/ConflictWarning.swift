import AppKit

/// The "this clashes with another session" warning, shown when you commit to
/// something that overlaps another committed item or is less than 15 minutes
/// from one.
@MainActor
enum ConflictWarning {

    /// Shows the warning if there are conflicts. Returns true if you chose to
    /// commit anyway (or there was nothing to warn about).
    static func confirm(_ commitment: Commitment, conflicts: [AppState.Conflict]) -> Bool {
        guard !conflicts.isEmpty else { return true }

        let lines = conflicts.map { conflict -> String in
            let other = conflict.other
            let span = "\(SessionCoordinator.time(other.startTime))–\(SessionCoordinator.time(other.endTime))"
            return conflict.overlaps
                ? "• Overlaps “\(other.title)” (\(span))"
                : "• Less than 15 minutes from “\(other.title)” (\(span))"
        }

        NSApp.activate()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "“\(commitment.title)” clashes with another session"
        alert.informativeText = lines.joined(separator: "\n")
            + "\n\nBack-to-back sessions leave no time to switch. Commit anyway?"
        alert.addButton(withTitle: "Commit anyway")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
