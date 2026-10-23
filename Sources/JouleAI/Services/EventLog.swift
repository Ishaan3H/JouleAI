import Foundation

/// Appends timestamped events to `events.jsonl` in JouleAI's data folder.
///
/// "JSONL" (JSON Lines) means one JSON object per line. Adding an event is just
/// writing one more line at the end, so the log never needs to be loaded or
/// rewritten, and you can read it in any text editor.
enum EventLog {

    static let fileName = "events.jsonl"

    static func record(_ kind: JouleAIEvent.Kind,
                       _ commitment: Commitment,
                       detail: String? = nil,
                       isTest: Bool = false) {
        let event = JouleAIEvent(
            timestamp: Date(),
            kind: kind,
            commitmentId: commitment.id,
            commitmentTitle: commitment.title,
            detail: detail,
            isTest: isTest ? true : nil
        )
        guard var data = try? encoder.encode(event) else { return }
        data.append(contentsOf: Array("\n".utf8))

        let url = Storage.directory.appendingPathComponent(fileName)
        if let handle = try? FileHandle(forWritingTo: url) {
            // File exists: jump to the end and add the line.
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            // First event ever: create the file.
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Every event in the log, oldest first.
    static func all() -> [JouleAIEvent] {
        let url = Storage.directory.appendingPathComponent(fileName)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            try? decoder.decode(JouleAIEvent.self, from: Data(line.utf8))
        }
    }

    // Compact (single-line) JSON with readable ISO 8601 dates (in UTC, marked "Z").
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
