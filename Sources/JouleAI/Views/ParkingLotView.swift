import Observation
import SwiftUI

/// The parking lot's text and where it's docked. Shared by the pad and the
/// coordinator, which saves the text with the session.
@MainActor
@Observable
final class ParkingLotModel {
    var text = ""
    var corner: ScreenCorner = AppSettings.parkingLotCorner
    /// Bumped each time the pad opens, so the text field grabs the cursor.
    var focusRequest = 0
}

/// The small floating pad for parking stray thoughts during a session.
/// Plain text, one thought per line. No formatting.
struct ParkingLotView: View {

    @Bindable var model: ParkingLotModel
    let onClose: () -> Void
    let onMove: (ScreenCorner) -> Void
    var onTextChange: (String) -> Void = { _ in }

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(spacing: Theme.Space.xs) {
                SectionLabel("Parking lot")
                Spacer()
                Menu {
                    ForEach(ScreenCorner.allCases, id: \.self) { corner in
                        Button(corner.label) { onMove(corner) }
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Dock to a corner")
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Hide (⌘⇧J or Esc)")
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.text)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.text)
                    .scrollContentBackground(.hidden)   // no white editor box
                    .focused($focused)
                if model.text.isEmpty {
                    Text("Park a thought, one per line.\nThen back to work.")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(Theme.Space.s)
            .background(Theme.sunken, in: RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous))

            Text("⌘⇧J hides · saved with this session")
                .font(Theme.Font.detail)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(Theme.Space.m)
        .frame(width: 300, height: 230)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
            .stroke(Theme.border, lineWidth: 1))
        .onAppear { focused = true }
        .onChange(of: model.focusRequest) { _, _ in focused = true }
        .onChange(of: model.text) { _, newText in onTextChange(newText) }
    }
}
