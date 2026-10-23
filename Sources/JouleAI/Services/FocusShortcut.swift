import Foundation

/// Runs one of the user's Shortcuts by name, using the `shortcuts` command-line
/// tool that ships with macOS (`/usr/bin/shortcuts`).
///
/// JouleAI can't switch Focus modes directly (Apple offers no API for that), so
/// the user makes a tiny shortcut that does it, and JouleAI runs the shortcut.
enum FocusShortcut {

    enum Result {
        case ran
        case missing      // no shortcut with that name exists
        case failed       // it exists but didn't run successfully
    }

    /// Runs the shortcut called `name`. `async` because the command can take a
    /// second or two; the caller waits without freezing the app.
    static func run(named name: String) async -> Result {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return .missing }

        // First check it exists: `shortcuts list` prints one name per line.
        let list = await runCommand(["list"])
        let names = list.output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard names.contains(name) else { return .missing }

        let result = await runCommand(["run", name])
        return result.status == 0 ? .ran : .failed
    }

    /// Runs `/usr/bin/shortcuts <arguments>` on a background thread and returns
    /// its exit status (0 = success) and printed output.
    private static func runCommand(_ arguments: [String]) async -> (status: Int32, output: String) {
        // withCheckedContinuation turns callback-style code into something we can `await`.
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: (process.terminationStatus,
                                                    String(decoding: data, as: UTF8.self)))
                } catch {
                    continuation.resume(returning: (-1, ""))
                }
            }
        }
    }
}
