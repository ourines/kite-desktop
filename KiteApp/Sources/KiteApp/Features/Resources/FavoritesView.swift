import SwiftUI

// MARK: – Favorites view

struct FavoritesView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var isLoading = false

    private var grouped: [(type: String, items: [FavoriteResource])] {
        let dict = Dictionary(grouping: favorites.favorites, by: { $0.resourceType })
        return dict.sorted { $0.key < $1.key }.map { (type: $0.key, items: $0.value) }
    }

    var body: some View {
        Group {
            if favorites.favorites.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "star",
                    description: Text("Star resources from their detail page to add them here.")
                )
            } else {
                List {
                    ForEach(grouped, id: \.type) { group in
                        Section(group.type.capitalized) {
                            ForEach(group.items) { fav in
                                NavigationLink(value: ResourceNavTarget(
                                    kind: ResourceKind(rawValue: fav.resourceType) ?? .pods,
                                    name: fav.resourceName,
                                    namespace: fav.namespace
                                )) {
                                    VStack(alignment: .leading) {
                                        Text(fav.resourceName).font(.subheadline)
                                        if let ns = fav.namespace {
                                            Text(ns).font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task {
                                            try? await favorites.remove(
                                                resourceType: fav.resourceType,
                                                namespace: fav.namespace,
                                                resourceName: fav.resourceName
                                            )
                                        }
                                    } label: { Label("Remove", systemImage: "star.slash") }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationDestination(for: ResourceNavTarget.self) { target in
                    ResourceDetailView(target: target)
                }
            }
        }
        .navigationTitle("Favorites")
        .loadingOverlay(isLoading)
        .task {
            isLoading = true
            await favorites.load()
            isLoading = false
        }
        .refreshable { await favorites.load() }
    }
}
