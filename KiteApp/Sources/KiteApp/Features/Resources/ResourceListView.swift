import SwiftUI

// MARK: – Generic Resource List ViewModel

@MainActor
final class ResourceListViewModel: ObservableObject {
    @Published var items: [GenericResourceItem] = []
    @Published var namespaces: [String] = []
    @Published var selectedNamespace: String?
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var error: Error?

    let kind: ResourceKind
    private let api = APIClient.shared

    init(kind: ResourceKind) {
        self.kind = kind
    }

    var filteredItems: [GenericResourceItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.namespace ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let list: K8sList<GenericResourceItem> = try await api.listResources(
                kind: kind.rawValue,
                namespace: kind.isClusterScoped ? nil : selectedNamespace
            )
            items = list.items.sorted { ($0.metadata?.creationTimestamp ?? "") > ($1.metadata?.creationTimestamp ?? "") }

            // Collect unique namespaces
            let allNS = Set(items.compactMap { $0.namespace }).sorted()
            namespaces = allNS
        } catch {
            self.error = error
        }
    }
}

// Lightweight generic resource for list display
struct GenericResourceItem: Codable, Identifiable {
    struct MinimalMeta: Codable {
        var name: String
        var namespace: String?
        var creationTimestamp: String?
        var uid: String?
        var labels: [String: String]?
    }
    var metadata: MinimalMeta?
    var status: AnyCodable?
    var spec: AnyCodable?
    var id: String { metadata?.uid ?? metadata?.name ?? UUID().uuidString }
    var name: String { metadata?.name ?? "" }
    var namespace: String? { metadata?.namespace }
    var age: String { metadata?.creationTimestamp?.relativeTimeAgo ?? "" }
}

// MARK: – Resource List View

struct ResourceListView: View {
    let resourceKind: ResourceKind
    @StateObject private var vm: ResourceListViewModel
    @State private var showCreateSheet = false

    init(resourceKind: ResourceKind) {
        self.resourceKind = resourceKind
        _vm = StateObject(wrappedValue: ResourceListViewModel(kind: resourceKind))
    }

    var body: some View {
        Group {
            if let error = vm.error {
                ErrorView(error: error) { await vm.load() }
            } else if vm.filteredItems.isEmpty && !vm.isLoading {
                EmptyStateView(title: "No \(resourceKind.displayName)",
                               message: "No resources found in the selected namespace.",
                               systemImage: resourceKind.systemImage)
            } else {
                List {
                    ForEach(vm.filteredItems) { item in
                        NavigationLink(value: ResourceNavTarget(
                            kind: resourceKind,
                            name: item.name,
                            namespace: item.namespace
                        )) {
                            GenericResourceRow(item: item, kind: resourceKind)
                        }
                        .contextMenu {
                            ResourceContextMenu(kind: resourceKind, item: item, onRefresh: {
                                await vm.load()
                            })
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(resourceKind.displayName)
        .searchable(text: $vm.searchText, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            if !resourceKind.isClusterScoped && !vm.namespaces.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    NamespaceFilterPicker(selectedNamespace: $vm.selectedNamespace, namespaces: vm.namespaces)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .loadingOverlay(vm.isLoading && vm.items.isEmpty)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .onChange(of: vm.selectedNamespace) { _, _ in Task { await vm.load() } }
        .navigationDestination(for: ResourceNavTarget.self) { target in
            ResourceDetailView(target: target)
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateResourceSheet(kind: resourceKind)
        }
    }
}

// MARK: – Generic Resource Row

struct GenericResourceRow: View {
    let item: GenericResourceItem
    let kind: ResourceKind

    private var statusString: String {
        // Try to extract a phase/status string from the status blob
        if let status = item.status?.value as? [String: Any] {
            return (status["phase"] as? String) ?? (status["conditions"] != nil ? "Active" : "")
        }
        return ""
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let ns = item.namespace {
                        Text(ns).font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(item.age).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !statusString.isEmpty {
                ResourceStatusBadge(status: statusString, compact: true)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: – Context menu

private struct ResourceContextMenu: View {
    let kind: ResourceKind
    let item: GenericResourceItem
    let onRefresh: () async -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        Group {
            Button {
                // Navigate to YAML editor – handled via sheet in detail view
            } label: {
                Label("Edit YAML", systemImage: "pencil")
            }

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete \(item.name)?", isPresented: $showDeleteAlert, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await APIClient.shared.deleteResource(
                        kind: kind.rawValue, namespace: item.namespace, name: item.name
                    )
                    await onRefresh()
                }
            }
        }
    }
}

// MARK: – Create resource sheet

private struct CreateResourceSheet: View {
    let kind: ResourceKind
    @State private var yaml = ""
    @State private var isSaving = false
    @State private var result: ApplyResourceResponse?
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            YAMLEditorView(text: $yaml)
                .navigationTitle("New \(kind.displayName)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Apply") { Task { await apply() } }
                            .disabled(yaml.isEmpty || isSaving)
                            .bold()
                    }
                    if isSaving {
                        ToolbarItem(placement: .status) {
                            ProgressView()
                        }
                    }
                }
        }
        .alert("Applied", isPresented: .constant(result != nil)) {
            Button("OK") { dismiss() }
        } message: {
            if let r = result {
                Text("\(r.kind)/\(r.name) applied successfully.")
            }
        }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private func apply() async {
        isSaving = true
        defer { isSaving = false }
        do {
            result = try await APIClient.shared.applyResource(yaml: yaml)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
