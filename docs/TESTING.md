# Testing JouleAI

Thanks for trying JouleAI! This page covers installing it, the permissions it
asks for, sending your data back, and quitting.

JouleAI runs entirely on your Mac. It never sends anything over the internet:
your commitments, sessions and notes stay in
`~/Library/Application Support/JouleAI/`. The only way data leaves your Mac is
if you export it yourself and send the file back.

You need **macOS 14 (Sonoma) or newer**.

## 1. Install

1. Download `JouleAI-<version>.zip` from the GitHub Release you were sent.
2. Double-click the zip. You get **JouleAI.app**.
3. Drag **JouleAI.app** into your **Applications** folder.
4. Double-click it to open it.

### "Apple could not verify JouleAI…"

The first time, macOS will stop it with a message like:

> "JouleAI" Not Opened. Apple could not verify "JouleAI" is free of malware…

That's expected. JouleAI isn't signed with a paid Apple developer certificate
yet, so macOS doesn't know who made it. To open it anyway:

1. Click **Done** (not "Move to Trash").
2. Open **System Settings → Privacy & Security**.
3. Scroll down to the **Security** section. You'll see
   *"JouleAI" was blocked to protect your Mac.*
4. Click **Open Anyway**, then enter your Mac password (or use Touch ID).
5. In the next message, click **Open Anyway** again.

You only have to do this once. After that it opens normally.

JouleAI has **no Dock icon**. Look for the ✓ icon in the menu bar at the top
right of your screen. Click it to see what's next; the gear icon opens the main
window (Commitments, History, Settings).

## 2. Permissions JouleAI asks for

macOS asks before JouleAI can use any of these. Each one is optional, but
some features won't work without it. You can change your answer later in
**System Settings → Privacy & Security**.

| Permission | When it's asked | What it's for | If you say no |
|---|---|---|---|
| **Calendars** | When you click **Connect calendar** in the menu bar popover | Reads today's timed events so you can turn them into commitments. Never changes your calendar. | You can still add commitments by hand. |
| **Notifications** | First launch | The 20-minute heads-up ("I'll be ready / Push 30 min / Not today") and the 5-minute reminder. | The full-screen Start card still appears on time, without warning. |
| **Automation: Google Chrome** (or Safari, Arc, Brave, Edge) | The first session with website rules | Reads which tab is open, to check it's allowed, and switches back to your task tab. | Tabs in that browser can't be checked. |
| **Accessibility** | Only if you use **Zen or Firefox**, during the first session with website rules | Reads the title of the front Zen/Firefox window to see which site you're on. Nothing else: not what you type, not page contents. | Zen and Firefox are blocked during sessions with website rules; Chrome and Safari still work. |
| **Downloads folder** | The first time you export your data | Saves the export file there. | The export can't be saved. |

Focus (Do Not Disturb) is turned on and off through two Shortcuts. If JouleAI
can't find them, it shows you how to make them (Settings → Focus).

## 3. Sending your data back

When you're asked for your results:

1. Click the menu bar icon → gear → **Settings**.
2. Under **Your data**, leave **Anonymise titles and notes** on (recommended).
   Your commitment titles, notes, parked thoughts and break reasons are
   replaced with codes like `title-3f2a`. Times, outcomes and which apps or
   sites triggered the lock are kept.
3. Click **Export my data**. A file called `JouleAI-export-<date>.json` appears
   in your Downloads folder, and Finder shows it.
4. Send that file back (message, email, AirDrop). You can open it in any text
   editor first to see exactly what's in it.

## 4. Quitting

Click the menu bar icon → gear → **Settings**, scroll to the bottom, and click
**Quit JouleAI**. (Since there's no Dock icon, Cmd-Q won't work.)

If it's stuck, open **Activity Monitor**, find **JouleAI**, and click the ✕
button.

To uninstall, quit it, drag JouleAI.app from Applications to the Trash, and
delete `~/Library/Application Support/JouleAI/` if you want your data gone too.

## If you're ever stuck

Press **Control-Option-Command-Escape** (⌃⌥⌘⎋) at any time. It ends the session
straight away (it's recorded as "broke early"), removes the blur and gives back
Cmd-Tab and the Dock. You never need to restart your Mac to get out of JouleAI.

## Something went wrong?

Tell us what you were doing and what happened. A screenshot helps. If you're
happy to, include your export file too.
