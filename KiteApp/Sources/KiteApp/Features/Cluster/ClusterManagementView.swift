import SwiftUI

// MARK: – Cluster Management View (Settings → Clusters tab)

struct ClusterManagementView: View {
    @StateObject private var store = ClusterStore()
    @State private var showAdd = false
    @State private var editingCluster: Cluster?

    var body: some View {
        Group {
            if store.isLoading && store.clusters.isEmpty {
                ProgressView("Loading clusters…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.clusters.isEmpty {
                ContentUnavailableView(
                    "No Clusters",
                    systemImage: "server.rack",
                    description: Text("Add a cluster to get started.")
                )
            } else {
                List {
                    ForEach(store.clusters) { cluster in
                        ClusterRow(cluster: cluster)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { try? await store.delete(id: cluster.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editingCluster = cluster
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Clusters")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            ClusterFormView(store: store)
        }
        .sheet(item: $editingCluster) { cluster in
            ClusterFormView(store: store, editing: cluster)
        }
        .task { await store.load() }
        .refreshable { await store.load() }
    }
}

// MARK: – Cluster row

private struct ClusterRow: View {
    let cluster: Cluster

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(cluster.name).font(.headline)
                Spacer()
                Circle()
                    .fill(cluster.enabled ? Color.k8sGreen : Color.k8sRed)
                    .frame(width: 8, height: 8)
                Text(cluster.enabled ? "Online" : "Offline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let desc = cluster.description, !desc.isEmpty {
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
            if let version = cluster.version {
                Text(version).font(.caption2).foregroundStyle(.secondary)
            }
            if let err = cluster.error, !err.isEmpty {
                Text(err).font(.caption2).foregroundStyle(.red).lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: – Cluster add / edit form

struct ClusterFormView: View {
    @ObservedObject var store: ClusterStore
    var editing: Cluster? = nil

    @State private var name = ""
    @State private var description = ""
    @State private var kubeconfigText = ""
    @State private var prometheusURL = ""
    @State private var isEnabled = true
    @State private var isTesting = false
    @State private var isSaving = false
    @State private var testResult: ClusterTestResponse?
    @State private var errorMessage: String?
    @State private var showFilePicker = false

    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { editing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cluster Info") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description)
                    Toggle("Enabled", isOn: $isEnabled)
                }

                Section("Kubeconfig") {
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Import from file…", systemImage: "doc.badge.plus")
                    }
                    TextEditor(text: $kubeconfigText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 120)
                }

                Section("Prometheus (optional)") {
                    TextField("URL", text: $prometheusURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }

                if let result = testResult {
                    Section("Connection Test") {
                        HStack {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.success ? .green : .red)
                            Text(result.message)
                                .font(.footnote)
                        }
                        if let v = result.version {
                            KVRow(key: "Server Version", value: v)
                        }
                    }
                }

                if let err = errorMessage {
                    Section {
                        Text(err).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Cluster" : "Add Cluster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Test") {
                        Task { await testConnection() }
                    }
                    .disabled(kubeconfigText.isEmpty || isTesting)
                    if isTesting { ProgressView().scaleEffect(0.8) }

                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty || kubeconfigText.isEmpty || isSaving)
                    .bold()
                    if isSaving { ProgressView().scaleEffect(0.8) }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.yaml, .text, .data],
                allowsMultipleSelection: false
            ) { result in
                if let url = try? result.get().first,
                   url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    kubeconfigText = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                }
            }
        }
        .onAppear {
            if let c = editing {
                name          = c.name
                description   = c.description ?? ""
                kubeconfigText = c.config ?? ""
                prometheusURL  = c.prometheusURL ?? ""
                isEnabled      = c.enabled
            }
        }
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil
        errorMessage = nil
        defer { isTesting = false }
        do {
            testResult = try await store.testConnection(config: kubeconfigText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let c = editing {
                let req = ClusterUpdateRequest(
                    name: name, description: description.isEmpty ? nil : description,
                    config: kubeconfigText, enabled: isEnabled,
                    prometheusURL: prometheusURL.isEmpty ? nil : prometheusURL
                )
                _ = try await store.update(id: c.id, req: req)
            } else {
                let req = ClusterCreateRequest(
                    name: name, description: description.isEmpty ? nil : description,
                    config: kubeconfigText, inCluster: false,
                    prometheusURL: prometheusURL.isEmpty ? nil : prometheusURL
                )
                _ = try await store.create(req)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: – UTType for yaml

import UniformTypeIdentifiers
extension UTType {
    static let yaml = UTType(filenameExtension: "yaml") ?? .plainText
}
