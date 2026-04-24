import SwiftUI

// MARK: – Overview Dashboard

@MainActor
final class OverviewViewModel: ObservableObject {
    @Published var overview: OverviewData?
    @Published var usageHistory: ResourceUsageHistory?
    @Published var recentEvents: [RecentEvent] = []
    @Published var isLoading = false
    @Published var isLoadingHistory = false
    @Published var error: Error?

    private let api = APIClient.shared

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            overview = try await api.getOverview()
            if overview?.prometheusEnabled == true {
                isLoadingHistory = true
                usageHistory = try? await api.getResourceUsageHistory()
                isLoadingHistory = false
            }
        } catch {
            self.error = error
        }
    }
}

struct OverviewView: View {
    @StateObject private var vm = OverviewViewModel()
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            if let error = vm.error {
                ErrorView(error: error) { await vm.load() }
                    .padding()
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // Stats cards
                    StatsCardsSection(overview: vm.overview, isLoading: vm.isLoading)

                    // Resource capacity donuts
                    if let res = vm.overview?.resource {
                        ResourceCapacitySection(resource: res)
                    }

                    // Prometheus charts
                    if vm.overview?.prometheusEnabled == true {
                        if let history = vm.usageHistory {
                            ResourceUtilizationChart(
                                cpuData: history.cpu,
                                memoryData: history.memory,
                                isLoading: vm.isLoadingHistory
                            )
                            .padding(.horizontal)

                            NetworkUsageChart(
                                networkIn: history.networkIn,
                                networkOut: history.networkOut,
                                isLoading: vm.isLoadingHistory
                            )
                            .padding(.horizontal)
                        } else if vm.isLoadingHistory {
                            ProgressView("Loading metrics…").padding()
                        }
                    }

                    // Recent events
                    RecentEventsSection()
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Overview")
        .loadingOverlay(vm.isLoading && vm.overview == nil)
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

// MARK: – Stats Cards

private struct StatsCardsSection: View {
    let overview: OverviewData?
    let isLoading: Bool

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 200))], spacing: 12) {
            MetricCard(
                title: "Nodes",
                value: overview.map { "\($0.readyNodes)/\($0.totalNodes)" } ?? "—",
                subtitle: "Ready / Total",
                systemImage: "cpu",
                color: .k8sGreen
            )
            MetricCard(
                title: "Pods",
                value: overview.map { "\($0.runningPods)/\($0.totalPods)" } ?? "—",
                subtitle: "Running / Total",
                systemImage: "circle.grid.3x3",
                color: .k8sBlue
            )
            MetricCard(
                title: "Namespaces",
                value: overview.map { "\($0.totalNamespaces)" } ?? "—",
                subtitle: nil,
                systemImage: "folder",
                color: .purple
            )
            MetricCard(
                title: "Services",
                value: overview.map { "\($0.totalServices)" } ?? "—",
                subtitle: nil,
                systemImage: "network",
                color: .orange
            )
        }
        .padding(.horizontal)
        .redacted(reason: isLoading ? .placeholder : [])
    }
}

// MARK: – Resource Capacity (CPU / Memory donuts)

private struct ResourceCapacitySection: View {
    let resource: ResourceCapacity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resource Capacity")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal)

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CPU").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        ResourceDonutChart(label: "Requested",
                                          used: resource.cpu.requested,
                                          total: resource.cpu.allocatable)
                        ResourceDonutChart(label: "Limited",
                                          used: resource.cpu.limited,
                                          total: resource.cpu.allocatable)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Memory").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        ResourceDonutChart(label: "Requested",
                                          used: resource.memory.requested,
                                          total: resource.memory.allocatable)
                        ResourceDonutChart(label: "Limited",
                                          used: resource.memory.limited,
                                          total: resource.memory.allocatable)
                    }
                }
                Spacer()
            }
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

// MARK: – Recent Events

private struct RecentEventsSection: View {
    @State private var events: [K8sEvent] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Events")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal)

            if isLoading {
                ProgressView().padding()
            } else if events.isEmpty {
                Text("No recent events")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(events.prefix(20)) { event in
                        EventRow(event: event)
                        Divider().padding(.leading, 16)
                    }
                }
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
        .task { await loadEvents() }
    }

    private func loadEvents() async {
        isLoading = true
        defer { isLoading = false }
        let list: K8sList<K8sEvent>? = try? await APIClient.shared.listResources(
            kind: "events", namespace: nil, limit: 20, fieldSelector: "type=Warning"
        )
        events = list?.items.sorted { ($0.lastTime ?? "") > ($1.lastTime ?? "") } ?? []
    }
}

private struct EventRow: View {
    let event: K8sEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.forEventType(event.type))
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.involvedObject?.kind ?? "").font(.caption2).foregroundStyle(.secondary)
                    Text(event.involvedObject?.name ?? "").font(.caption2.bold())
                    Spacer()
                    Text(event.lastTime?.relativeTimeAgo ?? "").font(.caption2).foregroundStyle(.secondary)
                }
                Text(event.message ?? "").font(.caption).lineLimit(2)
                if let reason = event.reason {
                    Text(reason).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
