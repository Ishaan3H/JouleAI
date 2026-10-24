import SwiftUI

/// The small window that appears when a session ends.
///
/// - Time ran out: "How did it go?" (Done / Partly / Didn't), then
///   "Where did you leave off?".
/// - Ended early: only "Where did you leave off?" (the outcome is already
///   "broke early").
///
/// The note is what greets you the next time this commitment comes round.
/// If you parked thoughts during the session, they're listed alongside, each
/// with "Make commitment" or "Dismiss".
struct EndOfSessionView: View {

    let title: String
    let endedEarly: Bool
    var parkedItems: [String] = []
    var onMakeCommitment: (String) -> Void = { _ in }
    var onDismissParked: (String) -> Void = { _ in }
    /// Called with the chosen outcome (nil when ended early) and the note.
    let onSave: (Session.Outcome?, String) -> Void
    let onSkip: () -> Void

    /// What happened to each parked item (by its position in the list).
    private enum ParkedState { case added, dismissed }
    @State private var parkedStates: [Int: ParkedState] = [:]

    @State private var outcome: Session.Outcome?
    @State private var note = ""
    /// Puts the cursor in the note field as soon as the window opens.
    @FocusState private var noteFocused: Bool

    private var canSave: Bool { endedEarly || outcome != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            reflection
                .frame(width: 420)
            if !parkedItems.isEmpty {
                Rectangle().fill(Theme.border).frame(width: 1)
                parked
                    .frame(width: 340)
            }
        }
        .background(Theme.background)
        .onAppear { noteFocused = true }
    }

    // MARK: - Left: how did it go, where did you leave off

    private var reflection: some View {
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
    }

    // MARK: - Right: the parking lot

    private var parked: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                SectionLabel("Parked during this session")
                Text("Turn a thought into a commitment for later, or let it go.")
                    .font(Theme.Font.detail)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ScrollView {
                VStack(spacing: Theme.Space.s) {
                    ForEach(parkedItems.indices, id: \.self) { index in
                        parkedRow(index)
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .padding(Theme.Space.xxl)
        .padding(.top, Theme.Space.s)
    }

    @ViewBuilder
    private func parkedRow(_ index: Int) -> some View {
        let item = parkedItems[index]
        switch parkedStates[index] {
        case .dismissed:
            EmptyView()
        case .added:
            Label("“\(item)” added to today, not committed yet", systemImage: "checkmark.circle.fill")
                .font(Theme.Font.detail)
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        case nil:
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text(item)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Space.s) {
                    Button("Make commitment") {
                        onMakeCommitment(item)
                        parkedStates[index] = .added
                    }
                    .buttonStyle(OutlineButtonStyle())
                    Button("Dismiss") {
                        onDismissParked(item)
                        parkedStates[index] = .dismissed
                    }
                    .buttonStyle(TextButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: Theme.Space.m)
        }
    }

    private func save() {
        onSave(endedEarly ? nil : outcome, note.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
