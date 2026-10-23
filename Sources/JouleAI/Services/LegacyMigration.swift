import Foundation

/// Carries data over from when the app was called "Reckon".
///
/// Renaming changed two things macOS uses to find an app's data:
/// - the data folder: `~/Library/Application Support/Reckon/` → `.../JouleAI/`
/// - the bundle ID that settings are stored under: `com.reckon.mac` → `com.jouleai.mac`
///
/// This runs once at launch, before anything reads data or settings, and moves
/// both across so nothing is lost. It does nothing on later launches.
/// (macOS permissions, like calendar access, can't be moved: they're asked again.)
enum LegacyMigration {

    private static let oldFolderName = "Reckon"
    private static let oldBundleID = "com.reckon.mac"
    private static let doneKey = "migratedFromReckon"

    static func run() {
        moveDataFolder()
        copySettings()
    }

    /// Renames the old data folder, unless the new one already exists.
    private static func moveDataFolder() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let oldFolder = appSupport.appendingPathComponent(oldFolderName, isDirectory: true)
        let newFolder = appSupport.appendingPathComponent("JouleAI", isDirectory: true)

        guard fileManager.fileExists(atPath: oldFolder.path),
              !fileManager.fileExists(atPath: newFolder.path) else { return }
        do {
            try fileManager.moveItem(at: oldFolder, to: newFolder)
        } catch {
            print("JouleAI: couldn't move old data folder: \(error)")
        }
    }

    /// Copies settings saved under the old bundle ID, without overwriting
    /// anything already set under the new one.
    private static func copySettings() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }

        if let old = defaults.persistentDomain(forName: oldBundleID) {
            for (key, value) in old where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: doneKey)
    }
}
