import Foundation

/// A record of one time a commitment fired: whether you did it, skipped it, or
/// broke it early, plus the "where I left off" note.
///
/// Defined now so the data model is complete; sessions are created and saved
/// from Phase 2 onward.
struct Session: Codable, Identifiable, Hashable {

    enum Outcome: String, Codable {
        case done
        case partly
        case didnt
        case skipped
        case brokeEarly
    }

    var id: UUID = UUID()
    var commitmentId: UUID
    /// Copied from the commitment so history still reads well if the commitment is gone.
    var commitmentTitle: String
    var startedAt: Date
    var endedAt: Date?
    var outcome: Outcome?
    var leftOffNote: String?
    var breakReason: String?
}
