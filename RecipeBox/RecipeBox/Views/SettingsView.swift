import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Query private var recipes: [Recipe]
    @Query private var importRecords: [ImportRecord]

    @AppStorage(SettingsKey.theme) private var theme = AppTheme.system.rawValue
    @AppStorage(SettingsKey.accent) private var accent = AccentChoice.tangerine.rawValue
    @AppStorage(SettingsKey.gridLayout) private var gridLayout = true
    @AppStorage(SettingsKey.compactLayout) private var compactLayout = false
    @AppStorage(SettingsKey.defaultServings) private var defaultServings = 4
    @AppStorage(SettingsKey.measurementSystem) private var measurement = MeasurementSystem.original.rawValue
    @AppStorage(SettingsKey.defaultSort) private var defaultSort = RecipeSort.newest.rawValue
    @AppStorage(SettingsKey.cookKeepAwake) private var keepAwake = true
    @AppStorage(SettingsKey.cookTextSize) private var cookTextSize = CookTextSize.large.rawValue
    @AppStorage(SettingsKey.cookShowStepIngredients) private var showStepIngredients = true
    @AppStorage(SettingsKey.timerAlerts) private var timerAlerts = true
    @AppStorage(SettingsKey.importUseAI) private var importUseAI = true
    @AppStorage(SettingsKey.importOCR) private var importOCR = true
    @AppStorage(SettingsKey.importFollowLinks) private var importFollowLinks = true
    @AppStorage(SettingsKey.importFetchCaptions) private var importFetchCaptions = true
    @AppStorage(SettingsKey.aiModel) private var aiModel = ClaudeModel.opus.rawValue

    @State private var apiKeyInput = ""
    @State private var hasKey = ClaudeClient.isConfigured
    @State private var testing = false
    @State private var testResult: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var exportDoc: BackupDocument?
    @State private var exportingBackup = false
    @State private var exportingPDF = false
    @State private var pdfDoc = PDFDocumentFile(data: Data())
    @State private var restoring = false
    @State private var confirmClearHistory = false

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                recipesSection
                cookingSection
                notificationsSection
                importSection
                aiSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.bold() }
            }
            .task { await refreshNotificationStatus() }
            .fileExporter(isPresented: $exportingBackup, document: exportDoc ?? BackupDocument(data: Data()),
                          contentType: .json,
                          defaultFilename: "RecipeBox-Backup-\(Date().formatted(.iso8601.year().month().day()))") { result in
                if case .success = result { toasts.show("Backup saved") }
            }
            .fileExporter(isPresented: $exportingPDF, document: pdfDoc, contentType: .pdf,
                          defaultFilename: "My Cookbook") { result in
                if case .success = result { toasts.show("Cookbook PDF saved") }
            }
            .fileImporter(isPresented: $restoring, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result {
                    do {
                        let n = try Backup.restore(from: url, into: context, existing: recipes)
                        toasts.show(n == 0 ? "No new recipes found in that file" : "Imported \(n) recipe\(n == 1 ? "" : "s")",
                                    style: n == 0 ? .info : .success)
                    } catch {
                        toasts.show("That file isn't a supported recipe file", style: .error)
                    }
                }
            }
            .confirmationDialog("Clear all import history?", isPresented: $confirmClearHistory, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) {
                    for r in importRecords { context.delete(r) }
                    toasts.show("Import history cleared")
                }
            } message: {
                Text("Your saved recipes are not affected.")
            }
        }
    }

    // MARK: Sections

    private var appearanceSection: some View {
        Section {
            Picker("Theme", selection: $theme) {
                ForEach(AppTheme.allCases) { Label($0.label, systemImage: $0.icon).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)

            VStack(alignment: .leading, spacing: 10) {
                Text("Accent Colour").font(.subheadline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                    ForEach(AccentChoice.allCases) { c in
                        Button {
                            withAnimation(.snappy) { accent = c.rawValue }
                        } label: {
                            Circle()
                                .fill(c.color.gradient)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if accent == c.rawValue {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                    }
                                }
                                .overlay(Circle().stroke(Color.primary.opacity(accent == c.rawValue ? 0.3 : 0), lineWidth: 2).padding(-3))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(c.label)
                    }
                }
            }
            .padding(.vertical, 4)

            Picker("Cookbook Layout", selection: $gridLayout) {
                Label("Photo Grid", systemImage: "square.grid.2x2").tag(true)
                Label("List", systemImage: "list.bullet").tag(false)
            }
            Toggle("Compact Cards", isOn: $compactLayout)
        } header: {
            Text("Appearance")
        } footer: {
            Text("Compact shows more recipes on screen at once.")
        }
    }

    private var recipesSection: some View {
        Section("Recipes") {
            Stepper("Default Servings: \(defaultServings)", value: $defaultServings, in: 1...24)
            Picker("Measurements", selection: $measurement) {
                ForEach(MeasurementSystem.allCases) { Text($0.label).tag($0.rawValue) }
            }
            Picker("Default Sort", selection: $defaultSort) {
                ForEach(RecipeSort.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            NavigationLink {
                CategoriesSettingsView()
            } label: {
                Label("Categories", systemImage: "square.grid.2x2")
            }
        }
    }

    private var cookingSection: some View {
        Section {
            Toggle("Keep Screen On", isOn: $keepAwake)
            Picker("Step Text Size", selection: $cookTextSize) {
                ForEach(CookTextSize.allCases) { Text($0.label).tag($0.rawValue) }
            }
            Toggle("Show Ingredients With Each Step", isOn: $showStepIngredients)
        } header: {
            Text("Cooking Mode")
        } footer: {
            Text("Cooking Mode shows one step at a time, with timers and your ingredient checklist.")
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle("Timer Alerts", isOn: $timerAlerts)
                .onChange(of: timerAlerts) { _, on in
                    if on { NotificationHelper.shared.requestPermission() }
                    Task { try? await Task.sleep(for: .seconds(1)); await refreshNotificationStatus() }
                }
            if timerAlerts && notificationStatus == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    Label("Notifications are off for Recipe Box — open iOS Settings", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Alerts when a cooking timer finishes, even if the app is closed.")
        }
    }

    private var importSection: some View {
        Section {
            Toggle("Analyze With AI", isOn: $importUseAI)
            Toggle("Read Text in Images (OCR)", isOn: $importOCR)
            Toggle("Follow Recipe Links in Descriptions", isOn: $importFollowLinks)
            Toggle("Use Video Captions When Available", isOn: $importFetchCaptions)
            NavigationLink {
                ImportHistoryView()
            } label: {
                Label("Import History", systemImage: "clock.arrow.circlepath")
            }
        } header: {
            Text("Recipe Import")
        } footer: {
            Text("Without AI, the importer still reads captions, linked recipe pages and on-screen text, and organizes them with built-in rules — results are less complete and are marked unverified.")
        }
    }

    private var aiSection: some View {
        Section {
            HStack {
                Image(systemName: hasKey ? "checkmark.seal.fill" : "key.fill")
                    .foregroundStyle(hasKey ? .green : .secondary)
                Text(hasKey ? "API key saved in Keychain" : "No API key")
                Spacer()
                if hasKey {
                    Button("Remove", role: .destructive) {
                        KeychainHelper.delete(ClaudeClient.keychainKey)
                        hasKey = false
                        testResult = nil
                    }
                    .font(.subheadline)
                }
            }
            if !hasKey {
                SecureField("Paste Claude API key (sk-ant-…)", text: $apiKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Save Key") {
                    KeychainHelper.save(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines), for: ClaudeClient.keychainKey)
                    apiKeyInput = ""
                    hasKey = ClaudeClient.isConfigured
                    if hasKey { toasts.show("API key saved securely") }
                }
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).count < 20)
            }
            Picker("Model", selection: $aiModel) {
                ForEach(ClaudeModel.allCases) { m in
                    VStack(alignment: .leading) {
                        Text(m.label)
                        Text(m.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(m.rawValue)
                }
            }
            .pickerStyle(.navigationLink)
            Button {
                testing = true
                testResult = nil
                Task {
                    do {
                        let reply = try await ClaudeClient.testConnection()
                        testResult = "Connected ✓ (\(reply.prefix(20)))"
                    } catch {
                        testResult = error.localizedDescription
                    }
                    testing = false
                }
            } label: {
                HStack {
                    Text("Test Connection")
                    Spacer()
                    if testing { ProgressView() }
                }
            }
            .disabled(!hasKey || testing)
            if let testResult {
                Text(testResult).font(.footnote).foregroundStyle(testResult.hasPrefix("Connected") ? .green : .red)
            }
        } header: {
            Text("AI Assistant")
        } footer: {
            Text("AI features (video recipe analysis, the cooking assistant and recipe creation) use Claude. Create a key at console.anthropic.com → API Keys. Usage is billed to your Anthropic account. The key is stored only in this device's Keychain and is sent only to api.anthropic.com.")
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                if let data = Backup.export(recipes) {
                    exportDoc = BackupDocument(data: data)
                    exportingBackup = true
                }
            } label: {
                Label("Back Up All Recipes (JSON)", systemImage: "arrow.up.doc")
            }
            .disabled(recipes.isEmpty)
            Button {
                pdfDoc = PDFDocumentFile(data: CookbookPDF.render(recipes.sorted { $0.title < $1.title }, title: "My Cookbook"))
                exportingPDF = true
            } label: {
                Label("Export Cookbook as PDF", systemImage: "book.pages")
            }
            .disabled(recipes.isEmpty)
            Button {
                restoring = true
            } label: {
                Label("Import Recipe File / Restore Backup", systemImage: "arrow.down.doc")
            }
            Button(role: .destructive) {
                confirmClearHistory = true
            } label: {
                Label("Clear Import History", systemImage: "trash")
            }
            .disabled(importRecords.isEmpty)
        } header: {
            Text("Data")
        } footer: {
            Text("Recipes are stored on this device. Backups can be saved to Files or iCloud Drive and restored later. Restoring skips recipes you already have.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
            LabeledContent("Recipes", value: "\(recipes.count)")
            Link(destination: URL(string: "https://www.themealdb.com")!) {
                Label("Discover recipes provided by TheMealDB", systemImage: "safari")
            }
        }
    }

    private func refreshNotificationStatus() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = s.authorizationStatus
    }
}

struct CategoriesSettingsView: View {
    @State private var custom: [String] = UserDefaults.standard.stringArray(forKey: SettingsKey.customCategories) ?? []
    @State private var newName = ""

    var body: some View {
        Form {
            Section("Built-in") {
                ForEach(Recipe.defaultCategories, id: \.self) { c in
                    Label(c, systemImage: Recipe.icon(for: c))
                }
            }
            Section {
                ForEach(custom, id: \.self) { c in
                    Label(c, systemImage: "tag")
                }
                .onDelete { idx in
                    custom.remove(atOffsets: idx)
                    save()
                }
                HStack {
                    TextField("New category", text: $newName)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Your Categories")
            } footer: {
                Text("Recipes in a deleted category keep their category name until you edit them.")
            }
        }
        .navigationTitle("Categories")
    }

    private func add() {
        let n = newName.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, !Recipe.categories.contains(where: { $0.caseInsensitiveCompare(n) == .orderedSame }) else { return }
        custom.append(n)
        newName = ""
        save()
    }

    private func save() {
        UserDefaults.standard.set(custom, forKey: SettingsKey.customCategories)
    }
}
