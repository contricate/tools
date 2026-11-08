import SwiftUI
import ActivityKit

struct IslandStudioView: View {
    @Environment(AppModel.self) private var model
    @State private var running = IslandController.isRunning
    @State private var mode: PreviewMode = .compact
    @State private var error: String?

    enum PreviewMode: String, CaseIterable, Identifiable {
        case compact, minimal, expanded, lock
        var id: String { rawValue }
        var label: String { rawValue == "lock" ? "Lock Screen" : rawValue.capitalized }
    }

    var body: some View {
        ThemeScaffold(title: "Dynamic Island", previewHeight: 190) { theme in
            VStack(spacing: 14) {
                Picker("Preview", selection: $mode) {
                    ForEach(PreviewMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                islandPreview(theme)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } content: { $t in
            Section {
                HStack {
                    Circle().fill(running ? Color.green : Color.gray).frame(width: 10, height: 10)
                    Text(running ? "Showing in your Dynamic Island" : "Not running")
                    Spacer()
                }
                Button {
                    Task { await toggle(t) }
                } label: {
                    Label(running ? "Stop Island" : "Start Island", systemImage: running ? "stop.circle.fill" : "play.circle.fill")
                }
                if running {
                    Button { Task { await IslandController.update(theme: t); model.show("Island updated") } } label: {
                        Label("Push Changes Now", systemImage: "arrow.clockwise")
                    }
                }
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
                if !IslandController.authorizationEnabled {
                    LimitNote(text: "Live Activities are turned off for Aura. Enable them in Settings → Aura → Live Activities.", icon: "exclamationmark.triangle")
                }
            } header: { Text("Live") }
            Section("Compact (around the island)") {
                Picker("Left", selection: $t.island.leading) { ForEach(IslandSlot.allCases) { Text($0.label).tag($0) } }
                Picker("Right", selection: $t.island.trailing) { ForEach(IslandSlot.allCases) { Text($0.label).tag($0) } }
                Picker("Minimal (when sharing)", selection: $t.island.minimal) { ForEach(IslandSlot.allCases) { Text($0.label).tag($0) } }
            }
            Section("Content") {
                TextField("Text", text: $t.island.text)
                TextField("Emoji", text: $t.island.emoji)
                SymbolRow(title: "Symbol", symbol: $t.island.symbol)
                PhotoField(title: "Photo (shown as a circle)", imageID: $t.island.imageID, maxSide: 240)
                ColorRow(title: "Tint", value: $t.island.tint)
            }
            Section("Expanded (long-press the island)") {
                TextField("Title", text: $t.island.expandedTitle)
                TextField("Subtitle", text: $t.island.expandedSubtitle)
            }
            Section {
                LimitNote(text: "The Dynamic Island can only show Live Activities — apps can't redesign the island itself or the status bar. A Live Activity stays up to 8 hours, then iOS ends it. To keep it on, create a Shortcuts automation (e.g. every morning, or when you unlock) that runs “Start Aura Island”. Battery % updates whenever Aura is opened or a Shortcut restarts the island.")
                NavigationLink(value: StudioRoute.guides) { Label("Automation Guide", systemImage: "book") }
            } header: { Text("How it works") }
        }
        .onAppear { running = IslandController.isRunning }
    }

    private func toggle(_ t: Theme) async {
        error = nil
        do {
            if running {
                await IslandController.endAll()
            } else {
                if model.library.activeThemeID != t.id { model.apply(t) }
                try await IslandController.start(theme: t)
            }
            running = IslandController.isRunning
        } catch {
            self.error = error.localizedDescription
        }
    }

    @ViewBuilder
    private func islandPreview(_ theme: Theme) -> some View {
        let spec = theme.island
        let b = model.battery
        switch mode {
        case .compact:
            HStack {
                IslandSlotView(slot: spec.leading, spec: spec, battery: b)
                Spacer()
                IslandSlotView(slot: spec.trailing, spec: spec, battery: b)
            }
            .padding(.horizontal, 14)
            .frame(width: 250, height: 37)
            .background(Capsule().fill(.black))
            .overlay(Capsule().stroke(.white.opacity(0.08)))
        case .minimal:
            HStack(spacing: 10) {
                Capsule().fill(.black).frame(width: 125, height: 37)
                IslandSlotView(slot: spec.minimal, spec: spec, battery: b)
                    .frame(width: 37, height: 37)
                    .background(Circle().fill(.black))
            }
        case .expanded:
            VStack(spacing: 10) {
                HStack {
                    IslandSlotView(slot: spec.leading == .none ? .symbol : spec.leading, spec: spec, battery: b, compact: false)
                    Spacer()
                    IslandSlotView(slot: spec.trailing == .none ? .clock : spec.trailing, spec: spec, battery: b, compact: false)
                }
                Text(spec.expandedTitle).font(.headline).foregroundStyle(spec.tint.color)
                if !spec.expandedSubtitle.isEmpty { Text(spec.expandedSubtitle).font(.caption).foregroundStyle(.secondary) }
            }
            .padding(18)
            .frame(width: 350)
            .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(.black))
        case .lock:
            LockScreenIslandView(state: IslandController.state(theme: theme))
                .frame(width: 350)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(theme.background.colors.last?.color.opacity(0.85) ?? .black))
        }
    }
}
