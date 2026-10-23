import SwiftUI

/// The card in the middle of the overlay when a commitment's time arrives.
///
/// One clear action: Start, available at once. Reschedule and Cancel are
/// deliberately quiet text buttons, locked for 30 seconds with a visible
/// countdown, so backing out is a decision rather than a reflex.
/// Reschedule only appears if the commitment hasn't been pushed back already.
struct StartCardView: View {

    let title: String
    let startTime: Date
    let durationMinutes: Int
    /// The note from last time, if there is one.
    let leftOffNote: String?
    let canReschedule: Bool
    let onStart: () -> Void
    let onReschedule: () -> Void
    let onCancel: () -> Void

    /// How long until Reschedule and Cancel unlock.
    static let skipDelaySeconds = 30
    @State private var skipSecondsLeft = StartCardView.skipDelaySeconds

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxl) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(spacing: Theme.Space.s) {
                    SectionLabel("It’s time")
                    Text("·").foregroundStyle(Theme.textTertiary)
                    Text("\(startTime.formatted(date: .omitted, time: .shortened)) · \(durationMinutes) \(durationMinutes == 1 ? "minute" : "minutes")")
                        .font(Theme.Font.detail)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(title)
                    .font(Theme.Font.display)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let leftOffNote, !leftOffNote.isEmpty {
                LeftOffNote(note: leftOffNote, large: true)
            }

            VStack(spacing: Theme.Space.m) {
                Button(action: onStart) {
                    Text("Start")
                }
                .buttonStyle(PrimaryButtonStyle(large: true))

                HStack(spacing: Theme.Space.xs) {
                    if canReschedule {
                        Button("Reschedule 30 min", action: onReschedule)
                            .buttonStyle(TextButtonStyle())
                        Text("·").foregroundStyle(Theme.textTertiary)
                    }
                    Button("Cancel", action: onCancel)
                        .buttonStyle(TextButtonStyle())
                }
                .disabled(skipSecondsLeft > 0)

                // Always reserve the line so the card doesn't jump when it disappears.
                Text(skipSecondsLeft > 0 ? "Available in \(skipSecondsLeft)s" : " ")
                    .font(Theme.Font.detail.monospacedDigit())
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(48)
        .frame(width: 560)
        // The shadow goes on the card's shape only; put on the whole view it
        // would also blur around every piece of text inside.
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.25), radius: 40, y: 12)
        )
        // `.task` runs when the card appears and is cancelled when it disappears.
        // It counts down once per second until the secondary actions unlock.
        .task {
            while skipSecondsLeft > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                skipSecondsLeft -= 1
            }
        }
    }
}
