import SwiftUI

// MARK: – Global search view model

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [SearchResult] = []
    @Published var isSearching = false
    @Published var history: [String] = []
    @Published var error: Error?

    private var searchTask: Task<Void, Never>?
    private let api = APIClient.shared
    private let historyKey = "searchHistory"

    init() {
        loadHistory()
    }

    func search() async {
        guard query.count >= 2 else {
            results = []
            return
        }
        searchTask?.cancel()
        isSearching = true
        error = nil
        let q = query
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // debounce 300ms
                if Task.isCancelled { return }
                let response = try await api.globalSearch(query: q)
                results = response.results
                saveToHistory(q)
            } catch is CancellationError {
                // ignore
            } catch {
                self.error = error
            }
            isSearching = false
        }
    }

    private var groupedResults: [(type: String, items: [SearchResult])] {
        let dict = Dictionary(grouping: results, by: { $0.resourceType })
        return dict.sorted { $0.key < $1.key }.map { (type: $0.key, items: $0.value) }
    }

    var grouped: [(type: String, items: [SearchResult])] { groupedResults }

    // MARK: History

    private func loadHistory() {
        history = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }

    private func saveToHistory(_ q: String) {
        var h = history.filter { $0 != q }
        h.insert(q, at: 0)
        history = Array(h.prefix(20))
        UserDefaults.standard.set(history, forKey: historyKey)
    }

    func clearHistory() {
        history = []
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
}

// MARK: – Global Search View

struct GlobalSearchView: View {
    @StateObject private var vm = SearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            List {
                if vm.query.isEmpty {
                    // Show history
                    if !vm.history.isEmpty {
                        Section("Recent") {
                            ForEach(vm.history, id: \.self) { item in
                                HStack {
                                    Image(systemName: "clock").foregroundStyle(.secondary)
                                    Text(item)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    vm.query = item
                                    Task { await vm.search() }
                                }
                            }
                            Button("Clear History", role: .destructive) {
                                vm.clearHistory()
                            }
                        }
                    }
                } else if vm.isSearching {
                    HStack {
                        ProgressView()
                        Text("Searching…").foregroundStyle(.secondary)
                    }
                } else if vm.results.isEmpty {
                    ContentUnavailableView.search(text: vm.query)
                } else {
                    ForEach(vm.grouped, id: \.type) { group in
                        Section(group.type.capitalized) {
                            ForEach(group.items) { result in
                                SearchResultRow(result: result, dismiss: dismiss)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $vm.query, isPresented: .constant(true), placement: .navigationBarDrawer(displayMode: .always))
            .onChange(of: vm.query) { _, _ in Task { await vm.search() } }
        }
        .onAppear { focused = true }
    }
}

private struct SearchResultRow: View {
    let result: SearchResult
    let dismiss: DismissAction

    var body: some View {
        NavigationLink(value: ResourceNavTarget(
            kind: ResourceKind(rawValue: result.resourceType) ?? .pods,
            name: result.name,
            namespace: result.namespace
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name).font(.subheadline)
                HStack(spacing: 8) {
                    if let ns = result.namespace {
                        Text(ns).font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(result.createdAt.relativeTimeAgo).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .navigationDestination(for: ResourceNavTarget.self) { target in
            ResourceDetailView(target: target)
        }
    }
}
