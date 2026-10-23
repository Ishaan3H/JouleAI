import Foundation

/// Reads and writes Reckon's data as JSON files in
/// `~/Library/Application Support/Reckon/`.
///
/// This is deliberately tiny: one file per kind of data (e.g. `commitments.json`),
/// loaded fully into memory and written back whole on every change. For the
/// amount of data Reckon keeps, that is fast and very hard to get wrong.
enum Storage {

    /// The folder all Reckon files live in. Created on first use.
    static let directory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask)[0]
        let folder = appSupport.appendingPathComponent("Reckon", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    /// Loads a value from `<directory>/<fileName>`.
    /// Returns `nil` if the file doesn't exist yet or can't be decoded.
    static func load<T: Decodable>(_ type: T.Type, from fileName: String) -> T? {
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // Don't crash on a corrupt file; log it so it's visible in Console.app.
            print("Reckon: could not decode \(fileName): \(error)")
            return nil
        }
    }

    /// Saves a value to `<directory>/<fileName>`, replacing the old file.
    /// `.atomic` writes to a temporary file first, so a crash mid-write can't
    /// leave a half-written file behind.
    static func save<T: Encodable>(_ value: T, to fileName: String) {
        let url = directory.appendingPathComponent(fileName)
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Reckon: could not save \(fileName): \(error)")
        }
    }

    // Dates are stored as readable ISO 8601 strings like "2026-10-17T14:30:00Z",
    // and the JSON is pretty-printed so you can open the files and read them.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
