import EventKit
import Foundation

/// Diagnostic: writes what JouleAI can see in the Mac's calendars, to check
/// why an event or its meeting link is missing.
///
///     open build/JouleAI.app --args --calendar-report ~/Desktop/calendar-report.txt
///
/// Lists every calendar account, and each event from yesterday to tomorrow
/// with where a meeting link was (or wasn't) found. Changes nothing.
@MainActor
enum CalendarReport {

    static var requestedPath: String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--calendar-report"), i + 1 < args.count else { return nil }
        return (args[i + 1] as NSString).expandingTildeInPath
    }

    static func write(to path: String) {
        let store = EKEventStore()
        // Not asked yet (e.g. after a rebuild): ask now and wait for the answer.
        if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            var answered = false
            store.requestFullAccessToEvents { _, _ in answered = true }
            let deadline = Date().addingTimeInterval(120)
            while !answered && Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            }
        }
        store.refreshSourcesIfNecessary()
        var lines: [String] = []
        let status = EKEventStore.authorizationStatus(for: .event)
        lines.append("Calendar permission: \(status.rawValue) (3 = full access)")
        lines.append("Time zone: \(TimeZone.current.identifier); now: \(Date().formatted(date: .abbreviated, time: .standard))")
        lines.append("")
        lines.append("ACCOUNTS AND CALENDARS")
        for source in store.sources {
            let calendars = source.calendars(for: .event).map(\.title).sorted()
            lines.append("- \(source.title) [\(source.sourceType.rawValue)]: \(calendars.joined(separator: ", "))")
        }

        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        let end = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: Date()))!
        let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
            .sorted { $0.startDate < $1.startDate }
        lines.append("")
        lines.append("EVENTS (yesterday → tomorrow): \(events.count)")
        for e in events {
            let meeting = MeetingLink.find(in: [e.url?.absoluteString, e.location, e.notes])
            lines.append("")
            lines.append("• \(e.title ?? "(no title)")  \(e.startDate.formatted(date: .abbreviated, time: .shortened)) → \(e.endDate.formatted(date: .omitted, time: .shortened))\(e.isAllDay ? " (all-day)" : "")")
            lines.append("  calendar: \(e.calendar.title) / \(e.calendar.source.title); in JouleAI today: \(cal.isDateInToday(e.startDate) && !e.isAllDay)")
            lines.append("  url: \(e.url?.absoluteString ?? "—")")
            lines.append("  location: \(e.location ?? "—")")
            let notes = (e.notes ?? "—").replacingOccurrences(of: "\n", with: " ⏎ ")
            lines.append("  notes: \(notes.prefix(400))\(notes.count > 400 ? "…" : "")")
            lines.append("  meeting link found: \(meeting.map { "\($0.service.rawValue) \($0.url.absoluteString)" } ?? "none")")
        }
        try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }
}
