import Foundation

/// A video-call link found in a calendar event: Google Meet, Zoom or Teams.
///
/// When a session comes from an event with one of these, JouleAI opens the
/// link at Start, allows that meeting site (and the browser / call app it
/// opens in), skips brown noise and makes sure sound is on.
struct MeetingLink: Hashable {

    enum Service: String {
        case googleMeet = "Google Meet"
        case zoom = "Zoom"
        case teams = "Microsoft Teams"
    }

    let url: URL
    let service: Service

    /// The meeting site to allow, e.g. "meet.google.com" or "us02web.zoom.us".
    var host: String { url.host?.lowercased() ?? "" }

    /// Desktop apps a link may hand the call over to. Allowed too, so the call
    /// isn't blocked the moment Zoom or Teams opens.
    var appBundleIDs: [String] {
        switch service {
        case .googleMeet: return []
        case .zoom: return ["us.zoom.xos"]
        case .teams: return ["com.microsoft.teams2", "com.microsoft.teams"]
        }
    }

    // MARK: - Finding links

    /// What each service's links look like (without "https://").
    private static let patternSources: [(Service, String)] = [
        (.googleMeet, #"meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}"#),
        (.zoom, #"(?:[a-z0-9-]+\.)?zoom\.us/j/[0-9]+(?:\?pwd=[A-Za-z0-9._-]+)?"#),
        (.teams, #"teams\.microsoft\.com/l/meetup-join/[^\s"'<>)]+"#),
    ]
    private static let patterns: [(Service, NSRegularExpression)] = patternSources.map { service, source in
        (service, try! NSRegularExpression(pattern: source, options: [.caseInsensitive]))
    }

    /// The first meeting link in `texts`, checked in order (e.g. the event's
    /// URL, then its location, then its notes). Within one text, the link
    /// that appears earliest wins.
    static func find(in texts: [String?]) -> MeetingLink? {
        for case let text? in texts where !text.isEmpty {
            let range = NSRange(text.startIndex..., in: text)
            var best: (location: Int, service: Service, match: String)?
            for (service, regex) in patterns {
                guard let found = regex.firstMatch(in: text, range: range),
                      let swiftRange = Range(found.range, in: text) else { continue }
                if best == nil || found.range.location < best!.location {
                    best = (found.range.location, service, String(text[swiftRange]))
                }
            }
            if let best, let url = URL(string: "https://" + best.match) {
                return MeetingLink(url: url, service: best.service)
            }
        }
        return nil
    }

    /// Re-reads a saved link (as stored on a commitment).
    init?(string: String) {
        guard let found = Self.find(in: [string]) else { return nil }
        self = found
    }

    private init(url: URL, service: Service) {
        self.url = url
        self.service = service
    }
}
