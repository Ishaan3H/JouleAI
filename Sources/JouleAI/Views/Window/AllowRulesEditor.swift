import SwiftUI
import UniformTypeIdentifiers

/// An editable list of allowed apps and website rules. Used for a commitment's
/// own rules and for each preset in Settings.
struct AllowRulesEditor: View {

    @Binding var rules: [AllowRule]

    /// Text typed into the "Add website" field.
    @State private var siteText = ""
    @State private var siteError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            if !rules.isEmpty {
                VStack(spacing: 0) {
                    ForEach(rules) { rule in
                        row(rule)
                        if rule.id != rules.last?.id {
                            Rectangle().fill(Theme.border).frame(height: 1)
                        }
                    }
                }
                .card(padding: 0)
            }

            HStack(spacing: Theme.Space.s) {
                TextField("", text: $siteText, prompt: Text("Website: khanacademy.org, or a channel / playlist link"))
                    .fieldStyle()
                    .onSubmit(addSite)
                Button("Add", action: addSite)
                    .buttonStyle(OutlineButtonStyle())
                    .disabled(siteText.trimmingCharacters(in: .whitespaces).isEmpty)
                Button { pickApp() } label: { Label("App…", systemImage: "app") }
                    .buttonStyle(OutlineButtonStyle())
            }
            if let siteError {
                Text(siteError).font(Theme.Font.detail).foregroundStyle(Theme.danger)
            }
        }
    }

    private func row(_ rule: AllowRule) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: rule.symbolName)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(rule.label)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(ruleKindText(rule))
                        .font(Theme.Font.detail)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                Button {
                    rules.removeAll { $0.id == rule.id }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(TextButtonStyle())
                .help("Remove")
            }
            // Soft warning: allowed, but probably not what you want.
            if let warning = rule.distractionWarning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(Theme.Font.detail)
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 30)
            }
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.s)
    }

    /// e.g. "Whole site", "This page and below", "This playlist or video".
    private func ruleKindText(_ rule: AllowRule) -> String {
        guard rule.kind == .site else { return "App" }
        if rule.value.contains("?") { return "Only this exact link (playlist or video)" }
        return rule.value.contains("/") ? "This page and everything under it" : "Whole site"
    }

    private func addSite() {
        guard let rule = AllowRule.site(from: siteText) else {
            siteError = "That doesn’t look like a website."
            return
        }
        if !rules.contains(where: { $0.kind == .site && $0.value == rule.value }) {
            rules.append(rule)
        }
        siteText = ""
        siteError = nil
    }

    /// Shows the "Open" panel in /Applications, limited to apps.
    private func pickApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.prompt = "Allow"
        if panel.runModal() == .OK {
            for rule in panel.urls.compactMap(AllowRule.app(from:))
            where !rules.contains(where: { $0.kind == .app && $0.value == rule.value }) {
                rules.append(rule)
            }
        }
    }
}

/// The note shown when Firefox-style browsers are installed: their tabs can't
/// be checked, so a session with website rules allows them whole.
struct UnreadableBrowsersNote: View {
    var body: some View {
        let names = BrowserTabs.installedUnreadableNames
        if !names.isEmpty {
            Label("\(names.joined(separator: " and ")) can’t be checked tab by tab, so during a session with website rules \(names.count == 1 ? "it’s" : "they’re") fully allowed.",
                  systemImage: "info.circle")
                .font(Theme.Font.detail)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
