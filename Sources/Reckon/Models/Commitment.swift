import Foundation

/// Something you intend to do at a specific time today.
///
/// A commitment comes from one of two places:
/// - `.calendar`: an event in the Mac's Calendar app. Its title and start time
///   are always re-read from the calendar; we only store the extra Reckon data
///   (launch targets, the Commit toggle, duration) alongside it.
/// - `.manual`: something you typed in with "Add commitment".
///
/// `Codable` lets Swift turn this into JSON and back automatically.
/// `Identifiable` lets SwiftUI lists tell rows apart by `id`.
/// `Hashable` lets us compare two commitments for equality.
struct Commitment: Codable, Identifiable, Hashable {

    enum Source: String, Codable {
        case calendar
        case manual
    }

    var id: UUID = UUID()
    var title: String
    var startTime: Date
    var durationMinutes: Int
    var source: Source

    /// For calendar commitments: the EventKit `eventIdentifier` of the event.
    /// `nil` for manual commitments.
    var calendarEventIdentifier: String?

    /// What to open when you press Start (websites, files, apps).
    var launchTargets: [LaunchTarget] = []

    /// Only committed items will take over the screen (from Phase 2).
    var isCommitted: Bool = false

    /// Bundle IDs of extra apps allowed during this commitment's session lock.
    var extraAllowedApps: [String] = []

    /// When the session should end, given the start time and duration.
    var endTime: Date {
        startTime.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }
}
