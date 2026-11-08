import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

/// A video file picked from Photos, copied to a temporary location.
struct PickedVideo: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { v in SentTransferredFile(v.url) } importing: { received in
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedVideo(url: dest)
        }
    }
}

struct UniversalImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @Query private var recipes: [Recipe]
    @Query(sort: \ImportRecord.date, order: .reverse) private var history: [ImportRecord]

    var initialLink = ""
    @State private var link = ""
    @State private var session = ImportSession()
    @State private var screenshotItems: [PhotosPickerItem] = []
    @State private var videoItem: PhotosPickerItem?
    @State private var analyzingVideo = false
    @State private var videoStatus = ""
    @State private var showTextEntry = false
    @State private var showManual = false
    @FocusState private var linkFocused: Bool

    private var detected: VideoPlatform? {
        VideoPlatform.cleanURL(from: link).map(VideoPlatform.detect)
    }

    private var canImport: Bool {
        detected != nil || !session.userScreenshots.isEmpty || session.userVideo != nil
            || !session.userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                switch session.phase {
                case .input: inputView
                case .running: progressView
                case .result:
                    RecipePreviewView(draft: $session.draft, onAccept: accept, onReject: {
                        session.reject()
                        toasts.show("Import discarded", style: .info)
                    })
                case .noRecipe:
                    NoRecipeView(session: session, link: link, onRetry: runImport,
                                 onManual: { showManual = true }, onBack: { session.reset() })
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(session.phase == .running ? "Stop" : "Close") {
                        if session.phase == .running { session.cancel() } else { dismiss() }
                    }
                }
            }
            .sheet(isPresented: $showTextEntry) { textEntrySheet.sheetStyle() }
            .sheet(isPresented: $showManual) {
                RecipeEditView(recipe: nil, prefillTitle: session.draft.title.isEmpty ? (session.evidence?.title ?? "") : session.draft.title,
                               prefillSource: session.evidence?.url.absoluteString ?? "")
                    .sheetStyle()
            }
            .animation(.snappy, value: session.phase)
        }
        .onAppear {
            if link.isEmpty && !initialLink.isEmpty { link = initialLink }
            session.checkDuplicate(link: link, recipes: recipes)
        }
        .interactiveDismissDisabled(session.phase == .running || session.phase == .result)
    }

    private var title: String {
        switch session.phase {
        case .input: return "Import Recipe"
        case .running: return "Analyzing…"
        case .result: return "Review Recipe"
        case .noRecipe: return "No Recipe Found"
        }
    }

    // MARK: Input

    private var inputView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Paste a video or recipe link").font(.title2.bold())
                    Text("TikTok, Instagram, YouTube, Facebook, Pinterest, Reddit, Vimeo or any recipe website.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: detected?.icon ?? "link")
                            .foregroundStyle(detected?.color ?? .secondary)
                            .frame(width: 24)
                            .contentTransition(.symbolEffect(.replace))
                        TextField("https://…", text: $link, axis: .vertical)
                            .lineLimit(1...3)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($linkFocused)
                            .submitLabel(.go)
                            .onSubmit { if canImport { runImport() } }
                        if !link.isEmpty {
                            Button { link = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DS.smallCorner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DS.smallCorner).stroke(linkFocused ? Color.accentColor : .clear, lineWidth: 1.5))

                    HStack {
                        PasteButton(payloadType: String.self) { strings in
                            if let s = strings.first { link = s.trimmingCharacters(in: .whitespacesAndNewlines) }
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonBorderShape(.capsule)
                        Spacer()
                        if let p = detected {
                            Label(p.rawValue, systemImage: p.icon)
                                .font(.caption.bold())
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(p.color.opacity(0.15), in: Capsule())
                                .foregroundStyle(p.color == .black ? Color.primary : p.color)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    if let p = detected {
                        Text(p.accessNote)
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .onChange(of: link) { _, new in session.checkDuplicate(link: new, recipes: recipes) }

                if let dup = session.duplicate {
                    HStack(spacing: 12) {
                        RecipeThumbnail(recipe: dup, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Already in your cookbook").font(.subheadline.bold())
                            Text(dup.title).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open") {
                            dismiss()
                            router.open(dup)
                        }
                        .buttonStyle(.bordered)
                    }
                    .card(padding: 12)
                }

                Button(action: runImport) {
                    Label(session.duplicate == nil ? "Import" : "Import Again", systemImage: "wand.and.stars")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canImport)

                extrasSection

                if !ClaudeClient.isConfigured {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles").foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Better results with AI").font(.subheadline.bold())
                            Text("Without an API key, recipes are pulled out with simple text rules. Add a Claude API key in Settings to analyze captions, transcripts and images together.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Open Settings") { router.showSettings = true }
                                .font(.caption.bold())
                        }
                    }
                    .card(padding: 12)
                }

                if !history.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Recent Imports")
                        ForEach(history.prefix(4)) { rec in
                            ImportRecordRow(record: rec)
                                .onTapGesture { link = rec.url }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var extrasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Add more to analyze", subtitle: "Optional — helps when a platform hides the recipe")
            VStack(spacing: 0) {
                PhotosPicker(selection: $screenshotItems, maxSelectionCount: 8, matching: .images) {
                    extraRow("Screenshots from the video", icon: "photo.on.rectangle.angled",
                             detail: session.userScreenshots.isEmpty ? "Ingredients or steps shown on screen" : "\(session.userScreenshots.count) added")
                }
                Divider().padding(.leading, 48)
                PhotosPicker(selection: $videoItem, matching: .videos) {
                    extraRow("The video file", icon: "film",
                             detail: analyzingVideo ? videoStatus : (session.userVideo != nil ? "Transcribed and scanned ✓" : "Saved or screen-recorded video: audio is transcribed on device"))
                }
                .disabled(analyzingVideo)
                Divider().padding(.leading, 48)
                Button { showTextEntry = true } label: {
                    extraRow("Paste caption or transcript", icon: "text.alignleft",
                             detail: session.userText.isEmpty ? "Copy the description or comments" : "\(session.userText.count) characters added")
                }
            }
            .buttonStyle(.plain)
            .card(padding: 4)
        }
        .onChange(of: screenshotItems) { _, items in
            Task {
                var datas: [Data] = []
                for item in items {
                    if let d = try? await item.loadTransferable(type: Data.self), let j = ImageUtil.downscaledJPEG(d, maxSide: 1600) {
                        datas.append(j)
                    }
                }
                session.userScreenshots = datas
            }
        }
        .onChange(of: videoItem) { _, item in
            guard let item else { return }
            analyzingVideo = true
            videoStatus = "Loading video…"
            Task {
                defer { analyzingVideo = false }
                guard let picked = try? await item.loadTransferable(type: PickedVideo.self) else {
                    toasts.show("Couldn't load that video", style: .error)
                    return
                }
                let result = await MediaAnalyzer.analyze(videoURL: picked.url) { msg in
                    Task { @MainActor in videoStatus = msg }
                }
                try? FileManager.default.removeItem(at: picked.url)
                session.userVideo = result
                if let note = result.notes.first { toasts.show(note, style: .info) }
            }
        }
    }

    private func extraRow(_ title: String, icon: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(Color.accentColor).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            if title.contains("video") && analyzingVideo { ProgressView() }
            else { Image(systemName: "plus.circle").foregroundStyle(.tertiary) }
        }
        .padding(10)
        .contentShape(Rectangle())
    }

    private var textEntrySheet: some View {
        NavigationStack {
            TextEditor(text: $session.userText)
                .padding()
                .overlay(alignment: .topLeading) {
                    if session.userText.isEmpty {
                        Text("Paste the caption, description, pinned comment, or a transcript…")
                            .foregroundStyle(.tertiary).padding(22).allowsHitTesting(false)
                    }
                }
                .navigationTitle("Caption or Transcript")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { showTextEntry = false }.bold() }
                    ToolbarItem(placement: .topBarLeading) {
                        PasteButton(payloadType: String.self) { s in session.userText += s.joined(separator: "\n") }
                            .labelStyle(.iconOnly)
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Running

    private var progressView: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack {
                    if let thumb = session.images.first, let ui = UIImage(data: thumb.data) {
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(width: 140, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20).fill(.black.opacity(0.25)))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 140, height: 180)
                    }
                    ProgressView().controlSize(.large).tint(.white)
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(session.steps) { step in
                        HStack(alignment: .top, spacing: 12) {
                            Group {
                                switch step.state {
                                case .running: ProgressView().controlSize(.small)
                                case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                case .skipped: Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                                case .failed: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                                }
                            }
                            .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.label).font(.subheadline.weight(.medium))
                                switch step.state {
                                case .done(let d), .skipped(let d), .failed(let d):
                                    Text(d).font(.caption).foregroundStyle(.secondary)
                                case .running: EmptyView()
                                }
                            }
                            Spacer()
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .card()
                Text("Only publicly available information is used.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Actions

    private func runImport() {
        linkFocused = false
        session.start(link: link, context: context)
    }

    private func accept(_ draft: RecipeDraft) {
        let r = session.accept(draft, context: context)
        dismiss()
        toasts.show("Saved “\(r.title)” to your cookbook", actionTitle: "Open") { router.open(r) }
    }
}

struct ImportRecordRow: View {
    let record: ImportRecord

    var body: some View {
        let platform = VideoPlatform(rawValue: record.platform) ?? .website
        HStack(spacing: 12) {
            Image(systemName: platform.icon)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(platform.color.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(record.recipeTitle.isEmpty ? record.url : record.recipeTitle)
                    .font(.subheadline.weight(.medium)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(record.date.formatted(.relative(presentation: .named)))
                    statusBadge
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .card(padding: 10)
    }

    @ViewBuilder private var statusBadge: some View {
        switch (record.outcome, record.status) {
        case ("accepted", _): Badge(text: "Saved", icon: "checkmark", color: .green)
        case ("rejected", _): Badge(text: "Rejected", color: .gray)
        case (_, "complete"): Badge(text: "Found", color: .green)
        case (_, "partial"): Badge(text: "Partial", color: .orange)
        case (_, "none"): Badge(text: "No recipe", color: .orange)
        default: Badge(text: "Failed", color: .red)
        }
    }
}
