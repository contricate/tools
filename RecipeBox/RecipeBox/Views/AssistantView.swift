import SwiftUI
import SwiftData

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    var role: String   // "user" or "assistant"
    var text: String
    var failed = false
}

/// AI cooking assistant. When a recipe is in context, answers are based on its actual ingredients and steps.
struct AssistantView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @Query(sort: \Recipe.title) private var recipes: [Recipe]

    @State var recipe: Recipe?
    var embedded = false
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var streaming = false
    @State private var task: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    init(recipe: Recipe? = nil, embedded: Bool = false) {
        _recipe = State(initialValue: recipe)
        self.embedded = embedded
    }

    private var suggestions: [String] {
        if recipe != nil {
            return ["Can I substitute butter with oil?", "How do I make this spicier?", "Can I make this without an oven?",
                    "How can I make this cheaper?", "How do I increase the protein?", "What if I'm missing an ingredient?",
                    "Scale this for 8 people", "What can go wrong, and how do I fix it?"]
        }
        return ["What can I use instead of sour cream?", "How do I know when chicken is cooked?", "What does 'fold in' mean?",
                "How do I fix a sauce that's too salty?", "How long do leftovers keep in the fridge?", "How do I sear a steak?"]
    }

    var body: some View {
        if embedded { content } else { NavigationStack { content } }
    }

    private var content: some View {
        VStack(spacing: 0) {
            contextBar
            if !ClaudeClient.isConfigured {
                ContentUnavailableView {
                    Label("Cooking Assistant", systemImage: "sparkles")
                } description: {
                    Text("Ask about substitutions, techniques, troubleshooting and scaling. The assistant uses Claude — add your API key in Settings to start.")
                } actions: {
                    Button("Open Settings") { router.showSettings = true }.buttonStyle(.borderedProminent)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            if messages.isEmpty { welcome }
                            ForEach(messages) { m in bubble(m).id(m.id) }
                            if streaming && (messages.last?.text.isEmpty ?? true) {
                                HStack(spacing: 6) { ProgressView(); Text("Thinking…").font(.caption).foregroundStyle(.secondary) }
                                    .padding(.leading, 4)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: messages) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
                }
                inputBar
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if embedded {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { task?.cancel(); messages = []; streaming = false } label: { Image(systemName: "square.and.pencil") }
                    .disabled(messages.isEmpty)
                    .accessibilityLabel("New conversation")
            }
        }
        .onDisappear { task?.cancel() }
    }

    private var contextBar: some View {
        HStack(spacing: 10) {
            Image(systemName: recipe == nil ? "globe" : "fork.knife").foregroundStyle(Color.accentColor)
            if embedded {
                Text(recipe.map { "About: \($0.title)" } ?? "General cooking questions").font(.subheadline.weight(.medium)).lineLimit(1)
            } else {
                Menu {
                    Button("General cooking questions") { recipe = nil }
                    Divider()
                    ForEach(recipes) { r in Button(r.title) { recipe = r } }
                } label: {
                    HStack(spacing: 4) {
                        Text(recipe.map { "About: \($0.title)" } ?? "General cooking questions").lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption)
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(.purple)
            Text(recipe == nil ? "Ask me anything about cooking" : "Ask about \(recipe!.title)").font(.title3.bold())
            Text(recipe == nil
                 ? "Substitutions, techniques, troubleshooting, food storage and more. Pick a recipe above for advice specific to it."
                 : "I know this recipe's ingredients and steps, so I can suggest substitutions, adjust it, scale it or help you fix problems.")
                .font(.subheadline).foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button { send(s) } label: {
                        Text(s).font(.subheadline)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 12)
    }

    @ViewBuilder private func bubble(_ m: ChatMessage) -> some View {
        let isUser = m.role == "user"
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                Text(markdown(m.text))
                    .textSelection(.enabled)
                if m.failed {
                    Button("Retry") { retry(m) }.font(.caption.bold())
                }
            }
            .padding(12)
            .background(isUser ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(isUser ? .white : (m.failed ? .red : .primary))
            .contextMenu {
                Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = m.text }
                if !isUser, let r = recipe {
                    Button("Save to My Notes", systemImage: "note.text.badge.plus") {
                        let n = CookNote(text: m.text, kind: "note")
                        n.recipe = r
                        context.insert(n)
                        toasts.show("Saved to \(r.title) notes")
                    }
                }
            }
            if !isUser { Spacer(minLength: 24) }
        }
    }

    private func markdown(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask a cooking question…", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onSubmit { send(input) }
            if streaming {
                Button { task?.cancel(); streaming = false } label: {
                    Image(systemName: "stop.circle.fill").font(.system(size: 32))
                }
                .accessibilityLabel("Stop")
            } else {
                Button { send(input) } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Send")
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: Conversation

    private var systemPrompt: String {
        var s = """
        You are a friendly, expert cooking assistant inside a recipe app. Give practical, concise answers (short paragraphs or \
        bullet points). Use **bold** sparingly for key amounts.
        - When a recipe is provided, base every answer on its actual ingredients, amounts and steps. Refer to step numbers.
        - For substitutions, give the replacement amount and how it changes the result.
        - For scaling, show the recalculated amounts and note anything that doesn't scale linearly (pan size, baking time, spices, leavening).
        - Food safety: rely only on established guidance (e.g. USDA/FSIS): poultry 165°F/74°C; ground meats 160°F/71°C; \
        whole cuts of beef, pork, veal, lamb 145°F/63°C with a 3-minute rest; fish 145°F/63°C; reheat leftovers to 165°F/74°C; \
        refrigerate perishables within 2 hours (1 hour above 90°F/32°C); most cooked leftovers keep 3–4 days refrigerated. \
        If you are not sure about a safety question, say so and recommend checking an official source. Never guess about safety, \
        allergies or canning/preserving.
        - If something can't be done well (e.g. a cake without an oven), say so honestly and offer the closest workable alternative.
        - Don't invent facts about the recipe's origin or creator.
        """
        if let r = recipe {
            s += "\n\nTHE RECIPE THE USER IS VIEWING:\n" + r.promptText
            let notes = (r.cookNotes ?? []).map { "- \($0.text)" }.joined(separator: "\n")
            if !notes.isEmpty { s += "\n\nThe user's own notes on this recipe:\n" + notes }
        }
        return s
    }

    private func send(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !streaming else { return }
        input = ""
        messages.append(ChatMessage(role: "user", text: t))
        respond()
    }

    private func retry(_ failed: ChatMessage) {
        messages.removeAll { $0.id == failed.id }
        respond()
    }

    private func respond() {
        let history: [[String: Any]] = messages.filter { !$0.failed }.map {
            ["role": $0.role, "content": [ClaudeClient.text($0.text)]]
        }
        messages.append(ChatMessage(role: "assistant", text: ""))
        let replyID = messages.last!.id
        streaming = true
        let system = systemPrompt
        task = Task {
            do {
                for try await chunk in ClaudeClient.stream(system: system, messages: history) {
                    if let i = messages.firstIndex(where: { $0.id == replyID }) { messages[i].text += chunk }
                }
                if let i = messages.firstIndex(where: { $0.id == replyID }), messages[i].text.isEmpty {
                    messages[i].text = "No answer was returned."
                    messages[i].failed = true
                }
            } catch {
                if let i = messages.firstIndex(where: { $0.id == replyID }) {
                    messages[i].text = error.localizedDescription
                    messages[i].failed = true
                }
            }
            streaming = false
        }
    }
}
