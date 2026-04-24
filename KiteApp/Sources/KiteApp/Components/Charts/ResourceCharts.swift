import SwiftUI
import Charts

// MARK: – Resource utilization line chart (CPU + Memory)

struct ResourceUtilizationChart: View {
    let cpuData: [UsageDataPoint]
    let memoryData: [UsageDataPoint]
    var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resource Utilization")
                .font(.subheadline.weight(.semibold))

            if isLoading {
                ProgressView().frame(height: 160)
            } else if cpuData.isEmpty && memoryData.isEmpty {
                Text("No data")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(height: 160)
            } else {
                Chart {
                    ForEach(cpuData) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("CPU (%)", point.value * 100)
                        )
                        .foregroundStyle(by: .value("Series", "CPU"))
                        .interpolationMethod(.catmullRom)
                    }
                    ForEach(memoryData) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Memory (%)", point.value * 100)
                        )
                        .foregroundStyle(by: .value("Series", "Memory"))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartForegroundStyleScale(["CPU": Color.k8sBlue, "Memory": Color.k8sGreen])
                .chartYScale(domain: 0...100)
                .chartYAxis { AxisMarks(values: [0, 25, 50, 75, 100]) { v in
                    AxisGridLine(); AxisValueLabel { Text("\(v.as(Int.self) ?? 0)%") }
                }}
                .chartXAxis(.hidden)
                .frame(height: 160)
            }
        }
        .cardStyle()
    }
}

// MARK: – Network usage area chart

struct NetworkUsageChart: View {
    let networkIn: [UsageDataPoint]
    let networkOut: [UsageDataPoint]
    var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Network Usage")
                .font(.subheadline.weight(.semibold))

            if isLoading {
                ProgressView().frame(height: 160)
            } else if networkIn.isEmpty && networkOut.isEmpty {
                Text("No data")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(height: 160)
            } else {
                Chart {
                    ForEach(networkIn) { point in
                        AreaMark(
                            x: .value("Time", point.timestamp),
                            y: .value("In (KB/s)", point.value / 1024)
                        )
                        .foregroundStyle(Color.k8sBlue.opacity(0.3))
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("In (KB/s)", point.value / 1024)
                        )
                        .foregroundStyle(by: .value("Series", "In"))
                    }
                    ForEach(networkOut) { point in
                        AreaMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Out (KB/s)", point.value / 1024)
                        )
                        .foregroundStyle(Color.k8sGreen.opacity(0.3))
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Out (KB/s)", point.value / 1024)
                        )
                        .foregroundStyle(by: .value("Series", "Out"))
                    }
                }
                .chartForegroundStyleScale(["In": Color.k8sBlue, "Out": Color.k8sGreen])
                .chartXAxis(.hidden)
                .frame(height: 160)
            }
        }
        .cardStyle()
    }
}

// MARK: – Resource donut chart (requested vs capacity)

struct ResourceDonutChart: View {
    let label: String
    let used: Double
    let total: Double
    var unit: String = "%"

    private var percentage: Double { total > 0 ? min(used / total, 1.0) : 0 }
    private var color: Color { percentage > 0.85 ? .k8sRed : percentage > 0.65 ? .k8sYellow : .k8sGreen }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Chart {
                    SectorMark(angle: .value("Used", percentage), innerRadius: .ratio(0.65))
                        .foregroundStyle(color)
                    SectorMark(angle: .value("Free", 1 - percentage), innerRadius: .ratio(0.65))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                }
                .frame(width: 60, height: 60)

                Text(String(format: "%.0f%%", percentage * 100))
                    .font(.caption2.bold())
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: – Pod metrics chart

struct PodMetricsChart: View {
    let cpuData: [UsageDataPoint]
    let memoryData: [UsageDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pod Metrics")
                .font(.subheadline.weight(.semibold))
            Chart {
                ForEach(cpuData) { point in
                    LineMark(x: .value("Time", point.timestamp), y: .value("CPU", point.value))
                        .foregroundStyle(by: .value("Series", "CPU"))
                }
                ForEach(memoryData) { point in
                    LineMark(x: .value("Time", point.timestamp), y: .value("Memory MB", point.value / 1_000_000))
                        .foregroundStyle(by: .value("Series", "Memory"))
                }
            }
            .chartForegroundStyleScale(["CPU": Color.k8sBlue, "Memory": Color.k8sGreen])
            .chartXAxis(.hidden)
            .frame(height: 140)
        }
        .cardStyle()
    }
}
