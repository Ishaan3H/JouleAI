import SwiftUI

/// The card shown when you switch to an app (or tab) that isn't part of your session.
///
/// Normally it offers "Back to task". Ending early is possible but slow on
/// purpose: a 60-second wait, then typing an exact phrase, then (optionally)
/// saying why.
struct LockCardView: View {

    let title: String
    let endsAt: Date
    /// Why the lock appeared, e.g. "That tab isn't part of this session."
    let detail: String?
    let onBackToTask: () -> Void
    /// Called with the optional reason once the user has confirmed breaking.
    let onBreak: (String?) -> Void

    static let breakPhrase = "I'm breaking this commitment"
    static let breakDelaySeconds = 60

    /// The steps of the End-early flow.
    private enum Stage {
        case normal         // Back to task / End early
        case waiting        // 60-second countdown
        case typingPhrase   // type the exact phrase
        case reason         // optional reason, then confirm
    }

    @State private var stage = Stage.normal
    @State private var waitSecondsLeft = LockCardView.breakDelaySeconds
    @State private var typedPhrase = ""
    @State private var reason = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxl) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SectionLabel("You’re in a committed session")
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)

                // TimelineView redraws its contents every second, so the
                // remaining time ticks down live.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let secondsLeft = max(0, Int(endsAt.timeIntervalSince(context.date).rounded(.up)))
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
                        Text(SessionCoordinator.clockText(seconds: secondsLeft))
                            .font(Theme.Font.countdown)
                            .foregroundStyle(Theme.accent)
                        Text("left").font(Theme.Font.body).foregroundStyle(Theme.textSecondary)
                    }
                }

                if let detail {
                    Text(detail)
                        .font(Theme.Font.detail)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            stageContent
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
    }

    // MARK: - Stages

    @ViewBuilder
    private var stageContent: some View {
        switch stage {
        case .normal:
            VStack(spacing: Theme.Space.m) {
                backToTaskButton
                Button("End early") { stage = .waiting }
                    .buttonStyle(TextButtonStyle())
            }

        case .waiting:
            VStack(spacing: Theme.Space.m) {
                backToTaskButton
                Text("Take a breath. You can end the session in \(waitSecondsLeft)s.")
                    .font(Theme.Font.detail.monospacedDigit())
                    .foregroundStyle(Theme.textTertiary)
            }
            // Counts down once a second; when it hits 0, move to the next step.
            .task {
                while waitSecondsLeft > 0 {
                    try? await Task.sleep(for: .seconds(1))
                    if Task.isCancelled { return }
                    waitSecondsLeft -= 1
                }
                stage = .typingPhrase
            }

        case .typingPhrase:
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Text("To end early, type exactly:")
                    .font(Theme.Font.detail)
                    .foregroundStyle(Theme.textSecondary)
                Text(Self.breakPhrase)
                    .font(Theme.Font.bodyEmphasis)
                    .foregroundStyle(Theme.text)
                TextField("", text: $typedPhrase)
                    .fieldStyle()
                    .autocorrectionDisabled()
                    .onChange(of: typedPhrase) { _, newValue in
                        if Self.matchesPhrase(newValue) { stage = .reason }
                    }
                backToTaskButton
                    .padding(.top, Theme.Space.s)
            }

        case .reason:
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Text("Why are you stopping? (optional)")
                    .font(Theme.Font.detail)
                    .foregroundStyle(Theme.textSecondary)
                TextField("", text: $reason).fieldStyle()
                backToTaskButton
                    .padding(.top, Theme.Space.s)
                Button("End session") {
                    let trimmed = reason.trimmingCharacters(in: .whitespaces)
                    onBreak(trimmed.isEmpty ? nil : trimmed)
                }
                .buttonStyle(TextButtonStyle(color: Theme.danger))
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var backToTaskButton: some View {
        Button(action: onBackToTask) {
            Text("Back to task")
        }
        .buttonStyle(PrimaryButtonStyle(large: true))
    }

    /// Exact match, except that a curly apostrophe (’) counts as a straight one ('),
    /// because macOS may swap them automatically as you type.
    private static func matchesPhrase(_ text: String) -> Bool {
        text.replacingOccurrences(of: "\u{2019}", with: "'") == breakPhrase
    }
}
