import SwiftUI

/// The "Allowlist presets" part of Settings: create, rename, edit and delete
/// presets like "Maths study" or "Coding". Changes save as you make them.
struct PresetsSection: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack {
                SectionLabel("Allowlist presets")
                Spacer()
                Button {
                    appState.savePreset(AllowPreset(name: "New preset"))
                } label: {
                    Label("New preset", systemImage: "plus")
                }
                .buttonStyle(TextButtonStyle(color: Theme.accent))
            }

            if appState.presets.isEmpty {
                Text("No presets yet.")
                    .font(Theme.Font.detail)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: Theme.Space.l)
            }

            ForEach(appState.presets) { preset in
                presetCard(preset)
            }

            Text("A commitment picks a preset in its editor. Its apps and sites are allowed on top of what opens on Start.")
                .font(Theme.Font.detail)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func presetCard(_ preset: AllowPreset) -> some View {
        // A binding that saves the preset every time it changes.
        let binding = Binding<AllowPreset>(
            get: { appState.preset(withID: preset.id) ?? preset },
            set: { appState.savePreset($0) }
        )
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack {
                TextField("", text: binding.name, prompt: Text("Preset name"))
                    .textFieldStyle(.plain)
                    .font(Theme.Font.bodyEmphasis)
                    .foregroundStyle(Theme.text)
                Spacer()
                Button("Delete") { appState.deletePreset(preset.id) }
                    .buttonStyle(TextButtonStyle(color: Theme.danger))
            }
            AllowRulesEditor(rules: binding.rules)
        }
        .card(padding: Theme.Space.l)
    }
}
