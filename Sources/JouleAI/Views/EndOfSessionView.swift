import SwiftUI

/// The small window that appears when a session ends.
///
/// - Time ran out: "How did it go?" (Done / Partly / Didn't), then
///   "Where did you leave off?".
/// - Ended early: only "Where did you leave off?" (the outcome is already
///   "broke early").
///
/// The note is what greets you the next time this commitment comes round.
struct EndOfSessionView: View {

    let title: String
    let endedEarly: Bool
    /// Called with the chosen outcome (nil when ended early) and the note.
    let onSave: (Session.Outcome?, String) -> Void
    let onSkip: () -> Void

    @State private var outcome: Session.Outcome?
    @State private var note = ""
    /// Puts the cursor in the note field as soon as the window opens.
    @FocusState private var noteFocused: Bool

    private var canSave: Bool { endedEarly || outcome != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                SectionLabel(endedEarly ? "Session ended early" : "Time’s up")
                Text(title)
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !endedEarly {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text("How did it go?")
                        .font(Theme.Font.bodyEmphasis)
                        .foregroundStyle(Theme.text)
                    ChipPicker(options: [("Done", Session.Outcome.done),
                                         ("Partly", .partly),
                                         ("Didn’t", .didnt)].map { ($0.0, Optional($0.1)) },
                               selection: $outcome)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("Where did you leave off?")
                    .font(Theme.Font.bodyEmphasis)
                    .foregroundStyle(Theme.text)
                TextField("", text: $note, prompt: Text("Write it for future you."))
                    .fieldStyle()
                    .focused($noteFocused)
                    .onSubmit { if canSave { save() } }   // Return saves
            }

            HStack {
                Button("Skip", action: onSkip)
                    .buttonStyle(TextButtonStyle())
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
            }
        }
        .padding(Theme.Space.xxl)
        .padding(.top, Theme.Space.s)   // room under the window's close button
        .frame(width: 420)
        .background(Theme.background)
        .onAppear { noteFocused = true }
    }

    private func save() {
        onSave(endedEarly ? nil : outcome, note.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
