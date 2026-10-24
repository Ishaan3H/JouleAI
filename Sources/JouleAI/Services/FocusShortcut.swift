import Foundation

/// Runs one of the user's Shortcuts by name, using the `shortcuts` command-line
/// tool that ships with macOS (`/usr/bin/shortcuts`).
///
/// JouleAI can't switch Focus modes directly (Apple offers no API for that), so
/// the user makes a tiny shortcut that does it, and JouleAI runs the shortcut.
/// Every attempt reports exactly what happened, so failures are never silent.
enum FocusShortcut {

    enum Result: Equatable {
        case ran
        /// No shortcut with that name exists (checked with `shortcuts list` first).
        case missing
        /// It exists but `shortcuts run` failed: its exit code and error output.
        case failed(exitCode: Int32, error: String)

        /// One line for the event log, e.g. `exit 1: Error: Couldn't find shortcut`.
        var logText: String {
            switch self {
            case .ran: return "ran (exit 0)"
            case .missing: return "not found in `shortcuts list`, so not run"
            case .failed(let code, let error): return "failed, exit \(code): \(error.isEmpty ? "(no error output)" : error)"
            }
        }
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
        if list.status != 0 {
            return .failed(exitCode: list.status, error: "shortcuts list: " + list.error)
        }
        guard names.contains(name) else { return .missing }

        let result = await runCommand(["run", name])
        return result.status == 0 ? .ran : .failed(exitCode: result.status, error: result.error)
    }

    /// Runs `/usr/bin/shortcuts <arguments>` on a background thread and returns
    /// its exit status (0 = success), printed output and error output.
    private static func runCommand(_ arguments: [String]) async -> (status: Int32, output: String, error: String) {
        // withCheckedContinuation turns callback-style code into something we can `await`.
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                process.arguments = arguments
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                do {
                    try process.run()
                    let out = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let err = errPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: (
                        process.terminationStatus,
                        String(decoding: out, as: UTF8.self),
                        String(decoding: err, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                } catch {
                    continuation.resume(returning: (-1, "", "couldn't start /usr/bin/shortcuts: \(error.localizedDescription)"))
                }
            }
        }
    }
}
