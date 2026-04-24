import SwiftUI

// MARK: – Navigation items

enum SidebarItem: Hashable {
    case overview
    case favorites
    case resource(ResourceKind)
    case settings
}

enum ResourceKind: String, CaseIterable, Hashable, Identifiable {
    // Workloads
    case deployments, statefulsets, daemonsets, jobs, cronjobs, pods, replicasets
    // Networking
    case services, ingresses, endpoints, endpointslices, networkpolicies, gateways, httproutes
    // Config
    case configmaps, secrets
    // Storage
    case persistentvolumes, persistentvolumeclaims, storageclasses
    // RBAC
    case roles, rolebindings, clusterroles, clusterrolebindings, serviceaccounts
    // Other
    case horizontalpodautoscalers, nodes, namespaces, events, crds

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deployments:            return "Deployments"
        case .statefulsets:           return "StatefulSets"
        case .daemonsets:             return "DaemonSets"
        case .jobs:                   return "Jobs"
        case .cronjobs:               return "CronJobs"
        case .pods:                   return "Pods"
        case .replicasets:            return "ReplicaSets"
        case .services:               return "Services"
        case .ingresses:              return "Ingresses"
        case .endpoints:              return "Endpoints"
        case .endpointslices:         return "EndpointSlices"
        case .networkpolicies:        return "NetworkPolicies"
        case .gateways:               return "Gateways"
        case .httproutes:             return "HTTPRoutes"
        case .configmaps:             return "ConfigMaps"
        case .secrets:                return "Secrets"
        case .persistentvolumes:      return "PersistentVolumes"
        case .persistentvolumeclaims: return "PVCs"
        case .storageclasses:         return "StorageClasses"
        case .roles:                  return "Roles"
        case .rolebindings:           return "RoleBindings"
        case .clusterroles:           return "ClusterRoles"
        case .clusterrolebindings:    return "ClusterRoleBindings"
        case .serviceaccounts:        return "ServiceAccounts"
        case .horizontalpodautoscalers: return "HPA"
        case .nodes:                  return "Nodes"
        case .namespaces:             return "Namespaces"
        case .events:                 return "Events"
        case .crds:                   return "CRDs"
        }
    }

    var systemImage: String {
        switch self {
        case .deployments, .statefulsets, .daemonsets: return "server.rack"
        case .pods:                   return "circle.grid.3x3"
        case .jobs, .cronjobs:        return "clock.arrow.circlepath"
        case .replicasets:            return "square.stack.3d.up"
        case .services:               return "network"
        case .ingresses, .gateways, .httproutes: return "arrow.triangle.branch"
        case .endpoints, .endpointslices: return "point.3.connected.trianglepath.dotted"
        case .networkpolicies:        return "lock.shield"
        case .configmaps:             return "doc.text"
        case .secrets:                return "key"
        case .persistentvolumes, .persistentvolumeclaims: return "externaldrive"
        case .storageclasses:         return "archivebox"
        case .roles, .clusterroles:   return "person.badge.key"
        case .rolebindings, .clusterrolebindings: return "link"
        case .serviceaccounts:        return "person.crop.circle"
        case .horizontalpodautoscalers: return "scalemass"
        case .nodes:                  return "cpu"
        case .namespaces:             return "folder"
        case .events:                 return "bell"
        case .crds:                   return "puzzlepiece.extension"
        }
    }

    var isClusterScoped: Bool {
        switch self {
        case .namespaces, .nodes, .persistentvolumes, .storageclasses, .clusterroles, .clusterrolebindings, .crds:
            return true
        default:
            return false
        }
    }
}

/// Target for resource-level navigation
struct ResourceNavTarget: Hashable {
    let kind: ResourceKind
    let name: String
    let namespace: String?
}

// MARK: – SidebarView

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @EnvironmentObject private var appState: AppState

    private let groups: [(name: String, kinds: [ResourceKind])] = [
        ("Workloads",  [.deployments, .statefulsets, .daemonsets, .jobs, .cronjobs, .pods, .replicasets]),
        ("Networking", [.services, .ingresses, .gateways, .httproutes, .endpoints, .endpointslices, .networkpolicies]),
        ("Config",     [.configmaps, .secrets]),
        ("Storage",    [.persistentvolumes, .persistentvolumeclaims, .storageclasses]),
        ("RBAC",       [.roles, .rolebindings, .clusterroles, .clusterrolebindings, .serviceaccounts]),
        ("More",       [.horizontalpodautoscalers, .nodes, .namespaces, .events, .crds]),
    ]

    var body: some View {
        List(selection: $selection) {
            // Overview
            Label("Overview", systemImage: "square.grid.2x2")
                .tag(SidebarItem.overview)

            // Favorites
            Label("Favorites", systemImage: "star")
                .tag(SidebarItem.favorites)

            // Resource groups
            ForEach(groups, id: \.name) { group in
                Section(group.name) {
                    ForEach(group.kinds) { kind in
                        Label(kind.displayName, systemImage: kind.systemImage)
                            .tag(SidebarItem.resource(kind))
                    }
                }
            }

            // Settings
            Divider()
            Label("Settings", systemImage: "gear")
                .tag(SidebarItem.settings)
        }
        .listStyle(.sidebar)
        .navigationTitle("Kite")
        .safeAreaInset(edge: .bottom) {
            ClusterSelectorWidget()
                .padding(8)
        }
    }
}

// MARK: – iPhone flat menu

struct SidebarMenuView: View {
    private let groups: [(name: String, kinds: [ResourceKind])] = [
        ("Workloads",  [.deployments, .statefulsets, .daemonsets, .jobs, .cronjobs, .pods, .replicasets]),
        ("Networking", [.services, .ingresses, .gateways, .httproutes, .endpoints, .endpointslices, .networkpolicies]),
        ("Config",     [.configmaps, .secrets]),
        ("Storage",    [.persistentvolumes, .persistentvolumeclaims, .storageclasses]),
        ("RBAC",       [.roles, .rolebindings, .clusterroles, .clusterrolebindings, .serviceaccounts]),
        ("More",       [.horizontalpodautoscalers, .nodes, .namespaces, .events, .crds]),
    ]

    var body: some View {
        List {
            ForEach(groups, id: \.name) { group in
                Section(group.name) {
                    ForEach(group.kinds) { kind in
                        NavigationLink {
                            ResourceListView(resourceKind: kind)
                        } label: {
                            Label(kind.displayName, systemImage: kind.systemImage)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: – Cluster selector widget

struct ClusterSelectorWidget: View {
    @EnvironmentObject private var appState: AppState
    @State private var clusters: [Cluster] = []
    @State private var showPicker = false

    private var currentCluster: Cluster? {
        clusters.first { $0.id == appState.currentClusterID }
    }

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundStyle(.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(currentCluster?.name ?? "No cluster")
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                    if let v = currentCluster?.version {
                        Text(v).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            ClusterPickerSheet(clusters: clusters, selection: $appState.currentClusterID)
        }
        .task {
            guard let conn = await APIClient.shared.connection else { return }
            _ = conn  // already configured
            clusters = (try? await APIClient.shared.getAccessibleClusters()) ?? []
        }
    }
}

private struct ClusterPickerSheet: View {
    let clusters: [Cluster]
    @Binding var selection: Int?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(clusters) { cluster in
                HStack {
                    VStack(alignment: .leading) {
                        Text(cluster.name).font(.headline)
                        if let desc = cluster.description {
                            Text(desc).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if cluster.id == selection {
                        Image(systemName: "checkmark").foregroundStyle(.accent)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selection = cluster.id
                    dismiss()
                }
            }
            .navigationTitle("Select Cluster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
