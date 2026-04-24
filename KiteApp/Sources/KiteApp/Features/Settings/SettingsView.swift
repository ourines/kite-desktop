import SwiftUI

// MARK: – Settings root view

struct SettingsView: View {
    @State private var selectedTab = "general"

    var body: some View {
        NavigationStack {
            List {
                NavigationLink { GeneralSettingsView()     } label: { Label("General", systemImage: "gearshape") }
                NavigationLink { ClusterManagementView()   } label: { Label("Clusters", systemImage: "server.rack") }
                NavigationLink { TemplateListView()        } label: { Label("Templates", systemImage: "doc.text.below.ecg") }
                NavigationLink { AISettingsView()          } label: { Label("AI Assistant", systemImage: "sparkles") }
                NavigationLink { AboutView()               } label: { Label("About", systemImage: "info.circle") }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
    }
}

// MARK: – General settings

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var setting: GeneralSetting?
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Color Scheme", selection: $appState.colorScheme) {
                    ForEach(ColorSchemePreference.allCases) { pref in
                        Text(pref.label).tag(pref)
                    }
                }
            }

            Section("Server Connection") {
                NavigationLink("Manage Clusters") {
                    ClusterManagementView()
                }
            }
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: – AI settings

struct AISettingsView: View {
    @State private var setting = GeneralSetting(
        aiEnabled: false, aiProvider: "openai",
        aiBaseURL: "https://api.openai.com",
        aiModel: "gpt-4o", aiAPIKey: ""
    )
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?
    @State private var showAPIKey = false

    private let providers = ["openai", "anthropic", "custom"]

    var body: some View {
        Form {
            Section {
                Toggle("Enable AI Assistant", isOn: $setting.aiEnabled)
            }

            if setting.aiEnabled {
                Section("Provider") {
                    Picker("Provider", selection: $setting.aiProvider) {
                        ForEach(providers, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    TextField("Base URL", text: $setting.aiBaseURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    TextField("Model", text: $setting.aiModel)
                        .autocapitalization(.none)
                }

                Section("API Key") {
                    HStack {
                        if showAPIKey {
                            TextField("sk-…", text: $setting.aiAPIKey)
                                .autocapitalization(.none)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("sk-…", text: $setting.aiAPIKey)
                                .font(.system(.body, design: .monospaced))
                        }
                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let err = error {
                Section { Text(err).foregroundStyle(.red).font(.footnote) }
            }
        }
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") { Task { await save() } }
                    .disabled(isSaving)
                    .bold()
            }
        }
        .loadingOverlay(isLoading)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        setting = (try? await APIClient.shared.getGeneralSetting()) ?? setting
    }

    private func save() async {
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            setting = try await APIClient.shared.updateGeneralSetting(setting)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: – About view

struct AboutView: View {
    @State private var versionInfo: VersionInfo?
    @State private var updateInfo: CheckUpdateResponse?
    @State private var isChecking = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "app.badge")
                        .font(.largeTitle)
                        .foregroundStyle(.accent)
                    VStack(alignment: .leading) {
                        Text("Kite").font(.headline)
                        Text("Kubernetes Manager").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("App") {
                KVRow(key: "App Version",    value: appVersion)
                if let v = versionInfo {
                    KVRow(key: "Server Version", value: v.version)
                    if let bt = v.buildTime { KVRow(key: "Build Time", value: bt) }
                    if let gc = v.gitCommit { KVRow(key: "Git Commit",  value: String(gc.prefix(8))) }
                }
            }

            if let update = updateInfo {
                Section("Updates") {
                    switch update.comparison {
                    case "update_available":
                        HStack {
                            Image(systemName: "arrow.down.circle.fill").foregroundStyle(.green)
                            Text("Update available: \(update.latestVersion ?? "")").font(.subheadline)
                        }
                    case "latest":
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Up to date").font(.subheadline)
                        }
                    default:
                        Text("Update status unknown").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button {
                    Task { await checkUpdate() }
                } label: {
                    HStack {
                        Text("Check for Updates")
                        Spacer()
                        if isChecking { ProgressView().scaleEffect(0.8) }
                    }
                }

                if let githubURL = URL(string: "https://github.com/ourines/kite-desktop") {
                    Link("GitHub Repository", destination: githubURL)
                }
                if let issuesURL = URL(string: "https://github.com/ourines/kite-desktop/issues") {
                    Link("Report an Issue", destination: issuesURL)
                }
            }

            Section("License") {
                Text("AGPL-3.0-only")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadVersion() }
    }

    private func loadVersion() async {
        versionInfo = try? await APIClient.shared.getVersion()
    }

    private func checkUpdate() async {
        isChecking = true
        defer { isChecking = false }
        updateInfo = try? await APIClient.shared.checkUpdate()
    }
}

// MARK: – Server connection setup view (shown on first launch)

struct ServerSetupView: View {
    @EnvironmentObject private var appState: AppState
    @State private var baseURLText = "http://localhost:9090"
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var testSuccess = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Server URL", text: $baseURLText)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                } header: {
                    Text("Kite Desktop Server")
                } footer: {
                    Text("Enter the base URL of your kite-desktop instance, e.g. http://192.168.1.100:9090")
                }

                if let result = testResult {
                    Section("Test Result") {
                        HStack {
                            Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(testSuccess ? .green : .red)
                            Text(result).font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle("Connect to Server")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Connect") { Task { await connect() } }
                        .disabled(baseURLText.isEmpty || isTesting)
                        .bold()
                }
            }
            .loadingOverlay(isTesting)
        }
    }

    private func connect() async {
        guard let url = URL(string: baseURLText) else {
            testResult = "Invalid URL"
            testSuccess = false
            return
        }
        isTesting = true
        defer { isTesting = false }

        await APIClient.shared.configure(baseURL: url)
        if let info = try? await APIClient.shared.getVersion() {
            testSuccess = true
            testResult = "Connected to server \(info.version)"
            UserDefaults.standard.set(baseURLText, forKey: "serverBaseURL")
            dismiss()
        } else {
            testSuccess = false
            testResult = "Could not connect. Is the server running?"
        }
    }
}
