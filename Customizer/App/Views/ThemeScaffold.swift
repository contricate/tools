import SwiftUI

/// Common editor layout: theme picker + pinned live preview + a form of controls.
/// Edits autosave (debounced) to the shared library so widgets and the island update.
struct ThemeScaffold<Preview: View, Content: View>: View {
    @Environment(AppModel.self) private var model
    let title: String
    var initialThemeID: UUID? = nil
    var previewHeight: CGFloat = 250
    @ViewBuilder var preview: (Theme) -> Preview
    @ViewBuilder var content: (Binding<Theme>) -> Content

    @State private var themeID: UUID?
    @State private var draft: Theme?

    var body: some View {
        VStack(spacing: 0) {
            if let d = draft {
                VStack(spacing: 10) {
                    themeMenu(d)
                    preview(d)
                        .frame(height: previewHeight)
                        .animation(.spring(duration: 0.4), value: d)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial.opacity(0.6))
                Form {
                    content(Binding(get: { draft ?? d }, set: { draft = $0 }))
                }
                .auraScreen()
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AuraBackdrop())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if draft == nil {
                themeID = initialThemeID ?? model.library.effectiveThemeID ?? model.activeTheme.id
                draft = model.library.theme(themeID) ?? model.activeTheme
            }
        }
        .onChange(of: themeID) { _, id in
            if let t = model.library.theme(id) { draft = t }
        }
        .task(id: draft) {
            guard let d = draft, d != model.library.theme(d.id) else { return }
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            model.upsert(d)
        }
    }

    private func themeMenu(_ d: Theme) -> some View {
        HStack {
            Menu {
                ForEach(model.library.themes) { t in
                    Button {
                        themeID = t.id
                    } label: {
                        if t.id == d.id { Label(t.name, systemImage: "checkmark") } else { Text(t.name) }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle().fill(d.accent.color).frame(width: 10, height: 10)
                    Text("Editing: \(d.name)").font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: Capsule())
            }
            Spacer()
            if d.id != model.library.activeThemeID {
                Button("Apply") { model.apply(d) }
                    .font(.subheadline.bold())
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else {
                Pill(text: "Active", icon: "checkmark.circle.fill", color: .green)
            }
        }
        .padding(.top, 6)
    }
}
