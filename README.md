# Reckon (macOS)

A menu bar app that does everything except the work: pick today's commitments,
and at the scheduled time Reckon clears the way for you to start.

## Build and run

Needs macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`).

```bash
scripts/build-app.sh --run
```

This compiles the Swift package, wraps it in `build/Reckon.app`, signs it ad hoc
with Hardened Runtime, and launches it. Look for the ✓ icon in the menu bar.

If you install full Xcode, you can also open `Package.swift` in it to browse and
edit the code, but use the script to produce a runnable `.app`.

## Where data lives

`~/Library/Application Support/Reckon/` — plain JSON files you can open and read.

## Layout

```
Sources/Reckon/
  App/       entry point, shared state, window helpers
  Models/    Commitment, LaunchTarget, Session
  Services/  calendar access, JSON storage, settings
  Views/     SwiftUI screens
Resources/   Info.plist and entitlements (copied in by the build script)
scripts/     build-app.sh
```
