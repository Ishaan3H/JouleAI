import Foundation

/// One line in the event log: something that happened around a commitment,
/// with the exact time it happened.
///
/// The log is how you (and later, the History screen) can see how the lead-up
/// to a session actually went: when the heads-up appeared, what you answered,
/// whether you pushed it back, cancelled, started, or broke out.
struct JouleAIEvent: Codable {

    enum Kind: String, Codable {
        case headsUpShown        // 20-minute heads-up appeared
        case respondedReady      // "I'll be ready"
        case respondedPush       // "Push 30 min"
        case respondedNotToday   // "Not today"
        case reminderShown       // 5-minute reminder appeared
        case overlayShown        // full-screen Start card appeared
        case rescheduled         // moved 30 minutes later
        case cancelled           // "Not today" or Cancel on the overlay
        case started             // Start pressed
        case brokeOut            // ended early with the typed phrase
        case completed           // the timer ran out
        case reflected           // answered the end-of-session window
        case reflectionSkipped   // closed it without answering
        case parkedToCommitment  // a parking-lot item became a new commitment
        case parkedDismissed     // a parking-lot item was dismissed
        case focusShortcut       // a Focus shortcut was run (or found missing), with the result
        case browserBlocked      // a browser was blocked: its pages couldn't be checked
    }

    var timestamp: Date
    var kind: Kind
    var commitmentId: UUID
    var commitmentTitle: String
    /// Extra context, e.g. "14:00 → 14:30 (from heads-up)" or "via notification".
    var detail: String?
    /// True for events from the Debug menu's test overlay.
    var isTest: Bool?
}
