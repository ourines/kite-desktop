import SwiftUI

// MARK: – Resource Detail View (generic, works for any K8s resource)

@MainActor
final class ResourceDetailViewModel: ObservableObject {
    @Published var yamlContent = ""
    @Published var describeContent = ""
    @Published var relatedResources: [RelatedResource] = []
    @Published var historyItems: [ResourceHistory] = []
    @Published var isLoadingYAML = false
    @Published var isLoadingDescribe = false
    @Published var error: Error?

    let target: ResourceNavTarget
    private let api = APIClient.shared

    init(target: ResourceNavTarget) {
        self.target = target
    }

    func loadYAML() async {
        isLoadingYAML = true
        defer { isLoadingYAML = false }
        do {
            let data = try await api.getRawData("/\(target.kind.rawValue)/\(target.namespace ?? "_all")/\(target.name)")
            yamlContent = String(data: data, encoding: .utf8) ?? ""
        } catch {
            self.error = error
        }
    }

    func loadDescribe() async {
        isLoadingDescribe = true
        defer { isLoadingDescribe = false }
        describeContent = (try? await api.describeResource(
            kind: target.kind.rawValue, namespace: target.namespace, name: target.name
        )) ?? ""
    }

    func loadRelated() async {
        relatedResources = (try? await api.getRelatedResources(
            kind: target.kind.rawValue,
            namespace: target.namespace ?? "_all",
            name: target.name
        )) ?? []
    }

    func loadHistory() async {
        let response = try? await api.getResourceHistory(
            kind: target.kind.rawValue,
            namespace: target.namespace ?? "_all",
            name: target.name
        )
        historyItems = response?.data ?? []
    }

    func delete() async throws {
        try await api.deleteResource(
            kind: target.kind.rawValue,
            namespace: target.namespace,
            name: target.name
        )
    }
}

struct ResourceDetailView: View {
    let target: ResourceNavTarget
    @StateObject private var vm: ResourceDetailViewModel
    @State private var selectedTab = "overview"
    @State private var showYAMLEditor = false
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var favorites: FavoritesStore

    init(target: ResourceNavTarget) {
        self.target = target
        _vm = StateObject(wrappedValue: ResourceDetailViewModel(target: target))
    }

    private var isFavorite: Bool {
        favorites.isFavorite(resourceType: target.kind.rawValue, namespace: target.namespace, resourceName: target.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Summary header
            ResourceSummaryHeader(target: target)
                .padding()
                .background(.background.secondary)

            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                Text("Overview").tag("overview")
                Text("YAML").tag("yaml")
                Text("Events").tag("events")
                Text("Related").tag("related")
                Text("History").tag("history")
                Text("Describe").tag("describe")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Tab content
            TabContent(vm: vm, target: target, selectedTab: selectedTab)
        }
        .navigationTitle(target.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Favorite toggle
                Button {
                    Task {
                        if isFavorite {
                            try? await favorites.remove(resourceType: target.kind.rawValue, namespace: target.namespace, resourceName: target.name)
                        } else {
                            try? await favorites.add(resourceType: target.kind.rawValue, namespace: target.namespace, resourceName: target.name)
                        }
                    }
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? .yellow : .secondary)
                }

                Menu {
                    Button { showYAMLEditor = true } label: {
                        Label("Edit YAML", systemImage: "pencil")
                    }
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showYAMLEditor) {
            YAMLEditSheet(target: target, initialYAML: vm.yamlContent)
        }
        .confirmationDialog("Delete \(target.name)?", isPresented: $showDeleteAlert, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await vm.delete()
                    dismiss()
                }
            }
        }
        .task { await vm.loadYAML() }
    }
}

// MARK: – Summary Header

private struct ResourceSummaryHeader: View {
    let target: ResourceNavTarget

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: target.kind.systemImage)
                .font(.title2)
                .foregroundStyle(.accent)
                .frame(width: 44, height: 44)
                .background(.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(target.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let ns = target.namespace {
                        Label(ns, systemImage: "folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(target.kind.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: – Tab content

private struct TabContent: View {
    @ObservedObject var vm: ResourceDetailViewModel
    let target: ResourceNavTarget
    let selectedTab: String

    var body: some View {
        switch selectedTab {
        case "yaml":
            YAMLTab(vm: vm)
        case "events":
            ResourceEventsTab(kind: target.kind.rawValue, name: target.name, namespace: target.namespace)
        case "related":
            RelatedResourcesTab(vm: vm, target: target)
        case "history":
            ResourceHistoryTab(vm: vm)
        case "describe":
            DescribeTab(vm: vm)
        default:
            OverviewTab(target: target)
        }
    }
}

// MARK: – Overview tab (raw JSON/YAML key-value)

private struct OverviewTab: View {
    let target: ResourceNavTarget
    @State private var rawItem: GenericResourceItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                KVRow(key: "Name",      value: target.name)
                KVRow(key: "Kind",      value: target.kind.displayName)
                if let ns = target.namespace {
                    KVRow(key: "Namespace", value: ns)
                }
                // Specific overviews for major kinds
                switch target.kind {
                case .pods:
                    PodOverviewView(namespace: target.namespace ?? "", name: target.name)
                case .deployments:
                    DeploymentOverviewView(namespace: target.namespace ?? "", name: target.name)
                case .nodes:
                    NodeOverviewView(name: target.name)
                default:
                    EmptyView()
                }
            }
            .padding()
        }
    }
}

// MARK: – YAML tab

private struct YAMLTab: View {
    @ObservedObject var vm: ResourceDetailViewModel

    var body: some View {
        if vm.isLoadingYAML {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            YAMLEditorView(text: .constant(vm.yamlContent), isReadOnly: true)
        }
    }
}

// MARK: – Events tab

private struct ResourceEventsTab: View {
    let kind: String
    let name: String
    let namespace: String?
    @State private var events: [K8sEvent] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if events.isEmpty {
                EmptyStateView(title: "No Events", message: "No events for this resource.", systemImage: "bell.slash")
            } else {
                List(events) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.reason ?? "").font(.caption.bold())
                                .foregroundStyle(Color.forEventType(event.type))
                            Spacer()
                            Text(event.lastTime?.relativeTimeAgo ?? "").font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(event.message ?? "").font(.caption)
                    }
                }
                .listStyle(.plain)
            }
        }
        .task { await loadEvents() }
    }

    private func loadEvents() async {
        isLoading = true
        defer { isLoading = false }
        let endpoint = "/events/resources?" + [
            "resource=\(kind)", "name=\(name)", namespace.map { "namespace=\($0)" } ?? ""
        ].filter { !$0.isEmpty }.joined(separator: "&")
        let list: K8sList<K8sEvent>? = try? await APIClient.shared.get(endpoint)
        events = list?.items ?? []
    }
}

// MARK: – Related resources tab

private struct RelatedResourcesTab: View {
    @ObservedObject var vm: ResourceDetailViewModel
    let target: ResourceNavTarget

    var body: some View {
        Group {
            if vm.relatedResources.isEmpty {
                EmptyStateView(title: "No Related Resources", message: "", systemImage: "link")
            } else {
                List(vm.relatedResources) { related in
                    HStack {
                        Image(systemName: ResourceKind(rawValue: related.type)?.systemImage ?? "cube")
                            .foregroundStyle(.accent)
                        VStack(alignment: .leading) {
                            Text(related.name)
                            if let ns = related.namespace {
                                Text(ns).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(related.type).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .listStyle(.plain)
            }
        }
        .task { await vm.loadRelated() }
    }
}

// MARK: – History tab

private struct ResourceHistoryTab: View {
    @ObservedObject var vm: ResourceDetailViewModel

    var body: some View {
        Group {
            if vm.historyItems.isEmpty {
                EmptyStateView(title: "No History", message: "No change history recorded.", systemImage: "clock")
            } else {
                List(vm.historyItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.operationType)
                                .font(.caption.bold())
                                .foregroundStyle(item.success ? .green : .red)
                            Spacer()
                            Text(item.createdAt.relativeTimeAgo)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        if !item.operationSource.isEmpty {
                            Text(item.operationSource).font(.caption2).foregroundStyle(.secondary)
                        }
                        if !item.success && !item.errorMessage.isEmpty {
                            Text(item.errorMessage).font(.caption).foregroundStyle(.red)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .task { await vm.loadHistory() }
    }
}

// MARK: – Describe tab

private struct DescribeTab: View {
    @ObservedObject var vm: ResourceDetailViewModel

    var body: some View {
        Group {
            if vm.isLoadingDescribe {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.describeContent.isEmpty {
                EmptyStateView(title: "No Output", message: "kubectl describe returned no output.", systemImage: "doc.text")
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(vm.describeContent)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task { await vm.loadDescribe() }
    }
}

// MARK: – YAML edit sheet

private struct YAMLEditSheet: View {
    let target: ResourceNavTarget
    @State var yaml: String
    @State private var isSaving = false
    @State private var error: String?
    @State private var success = false
    @Environment(\.dismiss) private var dismiss

    init(target: ResourceNavTarget, initialYAML: String) {
        self.target = target
        _yaml = State(initialValue: initialYAML)
    }

    var body: some View {
        NavigationStack {
            YAMLEditorView(text: $yaml)
                .navigationTitle("Edit \(target.name)")
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
                }
        }
        .alert("Applied", isPresented: $success) {
            Button("OK") { dismiss() }
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
            _ = try await APIClient.shared.applyResource(yaml: yaml)
            success = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: – Specialised overview sub-views

struct PodOverviewView: View {
    let namespace: String
    let name: String
    @State private var pod: Pod?

    var body: some View {
        Group {
            if let pod {
                VStack(alignment: .leading, spacing: 8) {
                    if let phase = pod.status?.phase {
                        HStack {
                            KVRow(key: "Phase", value: phase)
                            ResourceStatusBadge(status: phase)
                        }
                    }
                    KVRow(key: "Node",    value: pod.spec?.nodeName ?? "—")
                    KVRow(key: "Pod IP",  value: pod.status?.podIP ?? "—")
                    KVRow(key: "Host IP", value: pod.status?.hostIP ?? "—")

                    if let containers = pod.spec?.containers {
                        Text("Containers").font(.footnote.weight(.semibold)).padding(.top, 4)
                        ForEach(containers) { c in
                            KVRow(key: c.name, value: c.image ?? "—")
                        }
                    }

                    if let labels = pod.metadata.labels, !labels.isEmpty {
                        Text("Labels").font(.footnote.weight(.semibold)).padding(.top, 4)
                        LabelsView(labels: labels)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .task {
            pod = try? await APIClient.shared.getResource(kind: "pods", namespace: namespace, name: name)
        }
    }
}

struct DeploymentOverviewView: View {
    let namespace: String
    let name: String
    @State private var deployment: Deployment?

    var body: some View {
        Group {
            if let d = deployment {
                VStack(alignment: .leading, spacing: 8) {
                    KVRow(key: "Replicas",  value: "\(d.status?.readyReplicas ?? 0)/\(d.spec?.replicas ?? 0)")
                    KVRow(key: "Strategy",  value: d.spec?.strategy?.type ?? "—")
                    KVRow(key: "Paused",    value: d.spec?.paused == true ? "Yes" : "No")
                    if let labels = d.metadata.labels, !labels.isEmpty {
                        Text("Labels").font(.footnote.weight(.semibold)).padding(.top, 4)
                        LabelsView(labels: labels)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .task {
            deployment = try? await APIClient.shared.getResource(kind: "deployments", namespace: namespace, name: name)
        }
    }
}

struct NodeOverviewView: View {
    let name: String
    @State private var node: Node?

    var body: some View {
        Group {
            if let node {
                VStack(alignment: .leading, spacing: 8) {
                    let ready = node.status?.conditions?.first(where: { $0.type == "Ready" })
                    KVRow(key: "Status",    value: ready?.status ?? "—")
                    KVRow(key: "OS",        value: node.status?.nodeInfo?.osImage ?? "—")
                    KVRow(key: "Kernel",    value: node.status?.nodeInfo?.kernelVersion ?? "—")
                    KVRow(key: "kubelet",   value: node.status?.nodeInfo?.kubeletVersion ?? "—")
                    KVRow(key: "Runtime",   value: node.status?.nodeInfo?.containerRuntimeVersion ?? "—")
                    KVRow(key: "Arch",      value: node.status?.nodeInfo?.architecture ?? "—")
                    if let taints = node.spec?.taints, !taints.isEmpty {
                        Text("Taints").font(.footnote.weight(.semibold)).padding(.top, 4)
                        ForEach(taints) { t in
                            KVRow(key: "\(t.key)=\(t.value ?? "")", value: t.effect)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .task {
            node = try? await APIClient.shared.getResource(kind: "nodes", namespace: nil, name: name)
        }
    }
}
