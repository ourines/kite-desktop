import SwiftUI

// MARK: – ResourceStatusBadge

struct ResourceStatusBadge: View {
    let status: String
    var compact = false

    private var color: Color {
        switch status.lowercased() {
        case "running", "active", "available", "ready", "bound", "succeeded":
            return .k8sGreen
        case "pending", "containercreating", "podinitialized", "init":
            return .k8sYellow
        case "failed", "crashloopbackoff", "error", "oomkilled", "evicted",
             "terminating", "unknown", "lost":
            return .k8sRed
        case "completed":
            return .k8sBlue
        default:
            return .k8sGray
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: compact ? 6 : 8, height: compact ? 6 : 8)
            if !compact {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(color)
            }
        }
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, compact ? 2 : 3)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: – MetricCard

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    var systemImage: String?
    var color: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let img = systemImage {
                    Image(systemName: img)
                        .foregroundStyle(color)
                        .font(.subheadline)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            if let sub = subtitle {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: – KVRow (key-value display)

struct KVRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.footnote)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}

// MARK: – LabelBadge (for K8s labels/annotations)

struct LabelBadge: View {
    let key: String
    let value: String

    var body: some View {
        HStack(spacing: 0) {
            Text(key)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor, in: UnevenRoundedRectangle(
                    topLeadingRadius: 4, bottomLeadingRadius: 4))
            Text(value)
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15), in: UnevenRoundedRectangle(
                    bottomTrailingRadius: 4, topTrailingRadius: 4))
        }
        .font(.caption2.monospaced())
    }
}

// MARK: – LabelsView

struct LabelsView: View {
    let labels: [String: String]

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(Array(labels.sorted(by: { $0.key < $1.key })), id: \.key) { kv in
                LabelBadge(key: kv.key, value: kv.value)
            }
        }
    }
}

// MARK: – FlowLayout (wrapping HStack)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, width: proposal.width ?? 0).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (view, origin) in zip(subviews, result.origins) {
            view.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func layout(subviews: Subviews, width: CGFloat) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0; var y: CGFloat = 0; var rowHeight: CGFloat = 0; var maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}

// MARK: – EmptyStateView

struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "magnifyingglass"

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
    }
}

// MARK: – ErrorView

struct ErrorView: View {
    let error: Error
    var retry: (() async -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("Error")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button("Retry") {
                    Task { await retry() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

// MARK: – NamespaceFilter

struct NamespaceFilterPicker: View {
    @Binding var selectedNamespace: String?
    let namespaces: [String]

    var body: some View {
        Picker("Namespace", selection: $selectedNamespace) {
            Text("All Namespaces").tag(String?.none)
            Divider()
            ForEach(namespaces, id: \.self) { ns in
                Text(ns).tag(Optional(ns))
            }
        }
        .pickerStyle(.menu)
    }
}
