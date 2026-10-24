# JouleAI: what every file does

A plain-English tour of the project, folder by folder. Read top to bottom the
first time; after that, use it as a map.

## How the pieces fit

```
Scheduler (every 30 s) ──▶ SessionCoordinator ──▶ AppState (data) ──▶ Storage (JSON files)
                                │
        ┌───────────────────────┼───────────────────────────┐
   Notifier            OverlayController              EndOfSessionWindow
 (heads-up, 5-min)   (Start card, lock card)      (Done / Partly / Didn't + note)
```

- **AppState** knows *what* exists: commitments, sessions, calendar events.
- **SessionCoordinator** decides *when* things happen and drives the moving
  parts: notifications, the overlay, audio, brown noise, the lock.
- **Views** only draw. Buttons call functions on AppState or SessionCoordinator.

---

## Project root

| File | What it does |
|---|---|
| `Package.swift` | The project definition. Tells Swift the app is called JouleAI, needs macOS 14, and where the code lives. Used instead of an Xcode project so it builds from the command line. |
| `scripts/build-app.sh` | Builds the code, wraps it into `build/JouleAI.app` with its Info.plist and entitlements, signs it with Hardened Runtime, and (with `--run`) relaunches it. |
| `Resources/Info.plist` | The app's ID card: name, bundle ID (`com.jouleai.mac`), no Dock icon (`LSUIElement`), and the text macOS shows when asking for calendar and AppleScript permission. |
| `Resources/JouleAI.entitlements` | Permissions baked into the signature: AppleScript (Apple Events) and calendar access under Hardened Runtime. No sandbox, on purpose. |
| `README.md` | How to build and run. |
| `docs/FILES.md` | This file. |

## `App/`: startup and the parts that coordinate everything

| File | What it does |
|---|---|
| `JouleAIApp.swift` | Where the app starts. Runs the one-time migration, sets default settings, creates AppState and SessionCoordinator, and puts the icon (or countdown) in the menu bar. `--snapshots` renders screenshots instead. |
| `AppState.swift` | The app's memory and rules. Holds commitments and sessions, merges in today's calendar events, saves every change, and answers questions like "what's due now?", "what needs a heads-up?", "does this clash with anything?", "what was the last note for this?". |
| `SessionCoordinator.swift` | The conductor. On each tick: sends the 20-minute heads-up and the 5-minute reminder, shows the Start card at start time, handles Start / Reschedule / Cancel, opens launch targets, runs Focus, plays brown noise, runs the lock (app and tab checks), ends the session, turns Focus off, and opens the end-of-session window. Logs every step. |
| `MainWindowController.swift` | Opens the JouleAI window (gear icon) and remembers which tab and commitment are selected. |
| `EndOfSessionWindowController.swift` | Shows the small end-of-session window as a floating panel that can take typing even when another app is in front. Closing it counts as Skip. |
| `ParkingLotController.swift` | Shows, hides and docks the parking-lot pad: a floating panel one level above the lock, which takes typing without making JouleAI the front app. |
| `SnapshotRenderer.swift` | Renders every screen with sample data to PNGs in light and dark mode, for design review. Changes nothing. |

## `Models/`: the shapes of the data

| File | What it does |
|---|---|
| `Commitment.swift` | Something you intend to do at a time: title, start, length, calendar or manual, launch targets, the Commit flag, plus lead-up state (heads-up shown and answered, reminder shown, rescheduled, cancelled). |
| `LaunchTarget.swift` | One thing to open on Start: a URL, a file or an app. Also builds a readable label from what you picked. |
| `Session.swift` | One time a commitment fired: when it started and ended, the outcome (done, partly, didn't, skipped, broke early), the "where I left off" note, the parking-lot notes, and whether the end window was skipped. |
| `AllowRule.swift` | One allowed app or website rule (a domain, a path like a YouTube channel, or an exact playlist/video link), how a rule matches a web address, the soft warning for common distractions, and `AllowPreset` (a named, reusable set of rules, plus the two starter presets). |
| `JouleAIEvent.swift` | One line in the event log: what happened, to which commitment, when, and any detail. |

## `Services/`: one job each

| File | What it does |
|---|---|
| `Storage.swift` | Reads and writes JSON files in `~/Library/Application Support/JouleAI/`. |
| `AppSettings.swift` | Small saved preferences (session length, Focus shortcut names, brown noise, browser) and their defaults. |
| `LegacyMigration.swift` | One-time move of data and settings from when the app was called Reckon. |
| `CalendarService.swift` | The only file that talks to the Calendar (EventKit): asks permission and reads today's timed events. |
| `GlobalHotKey.swift` | A system-wide shortcut (⌘⇧J for the parking lot) using macOS's hotkey API, which needs no Accessibility permission. |
| `Scheduler.swift` | A 30-second timer plus a wake-from-sleep listener. Just says "check now". |
| `Notifier.swift` | macOS notifications: the heads-up with *I'll be ready / Push 30 min / Not today*, and the plain 5-minute reminder. Passes button clicks back to the coordinator. |
| `EventLog.swift` | Appends timestamped events to `events.jsonl`, one JSON line each. |
| `AudioMuter.swift` | Mutes sound when the Start card appears and restores it, but never unmutes sound you muted yourself. |
| `Launcher.swift` | Opens launch targets (web links in the session browser), and works out which apps a session allows. |
| `BrowserTabs.swift` | Reads the current tab and switches tabs in Safari, Chrome, Arc, Brave and Edge via AppleScript; knows which browsers (Firefox, Zen…) can't be read. |
| `SessionAllowlist.swift` | Built when a session starts: combines launch targets, the commitment's preset and its own rules, then answers "may this app be in front?" and "may this tab be open?". |
| `FocusShortcut.swift` | Runs a Shortcut by name with the `shortcuts` command (how Focus gets turned on and off). |
| `BrownNoisePlayer.swift` | Generates brown noise in real time with AVAudioEngine. No audio file. |

## `Overlay/`: the full-screen takeover

| File | What it does |
|---|---|
| `OverlayPanel.swift` | One borderless, blurred, full-screen window per display, above everything, on every Space. Takes the keyboard and ignores Escape and Cmd-shortcuts. |
| `OverlayController.swift` | Covers every display, puts the card on the main one, takes the keyboard back if anything grabs it, and rebuilds if a monitor is plugged in. |
| `StartCardView.swift` | The "It's time" card: big title, last note, Start, and quiet Reschedule / Cancel that unlock after 30 s. |
| `LockCardView.swift` | The "You're in a committed session" card: time left, Back to task, and the slow End-early flow (60 s wait, typed phrase, optional reason). |

## `Views/`: everything else you see

| File | What it does |
|---|---|
| `Theme/Theme.swift` | The palette (warm off-white, olive, near-black, with dark mode), type sizes, spacing and corner radii. Change the look here. |
| `Theme/Components.swift` | Shared pieces: primary / outline / text buttons, section labels, cards, text-field style, the left-off note box, pill pickers, settings rows. |
| `Popover/NextUpView.swift` | Draws the menu bar popover from plain data: the "what's next" card, today's list, Add. |
| `Popover/PopoverView.swift` | Connects the popover to live data and wires its buttons. Also brings back a skipped end-of-session window once. |
| `Window/MainWindowView.swift` | The JouleAI window's tab bar and pages. |
| `Window/CommitmentsPage.swift` | Commitments tab: today's list and the editor for the selected one. |
| `Window/CommitmentEditorView.swift` | The editor: title, time, length (25 / 50 / custom minutes), launch targets, and what's allowed during the session (preset + extra rules). Warns about clashes on Save. |
| `Window/AllowRulesEditor.swift` | The editable list of allowed apps and website rules (with distraction warnings), shared by the editor and Settings; also the note about Firefox-style browsers. |
| `Window/PresetsSection.swift` | The "Allowlist presets" part of Settings: add, rename, edit, delete presets. |
| `Window/HistoryPage.swift` | History tab: kept / skipped / broke-early counts for 14 days, and each session with its outcome and note. |
| `Window/SettingsPage.swift` | Settings tab: browser, Focus shortcuts, brown noise, testing buttons, Quit. |
| `ConflictWarning.swift` | The "clashes with another session" alert. |
| `EndOfSessionView.swift` | The end-of-session window: Done / Partly / Didn't (unless ended early) and "Where did you leave off?", with any parked thoughts alongside (Make commitment / Dismiss). |
| `ParkingLotView.swift` | The parking-lot pad itself: plain text, one thought per line, a corner menu and a close button. |

## Data on disk (not in the repo)

`~/Library/Application Support/JouleAI/`
- `commitments.json`: your commitments
- `sessions.json`: every session and its outcome and note
- `presets.json`: your allowlist presets
- `events.jsonl`: the timestamped event log
