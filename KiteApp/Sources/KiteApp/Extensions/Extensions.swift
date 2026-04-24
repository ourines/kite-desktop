import SwiftUI

// MARK: – View

extension View {
    /// Apply modifier only when condition is true
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, @ViewBuilder transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }

    /// Convenience for loading overlay
    func loadingOverlay(_ isLoading: Bool) -> some View {
        overlay {
            if isLoading {
                ProgressView()
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    /// Card-style background
    func cardStyle() -> some View {
        self
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: – Color

extension Color {
    static let k8sGreen  = Color(red: 0.18, green: 0.72, blue: 0.40)
    static let k8sRed    = Color(red: 0.85, green: 0.25, blue: 0.25)
    static let k8sYellow = Color(red: 0.93, green: 0.72, blue: 0.13)
    static let k8sBlue   = Color(red: 0.20, green: 0.55, blue: 0.92)
    static let k8sGray   = Color(red: 0.55, green: 0.55, blue: 0.60)

    static func forPodPhase(_ phase: String?) -> Color {
        switch phase {
        case "Running":             return .k8sGreen
        case "Pending":             return .k8sYellow
        case "Succeeded":           return .k8sBlue
        case "Failed", "CrashLoopBackOff": return .k8sRed
        default:                    return .k8sGray
        }
    }

    static func forEventType(_ type: String?) -> Color {
        switch type {
        case "Warning": return .k8sRed
        default:        return .secondary
        }
    }
}

// MARK: – Date

extension String {
    /// Parse ISO-8601 and return a relative time string ("2m ago", "3d ago")
    var relativeTimeAgo: String {
        let formatters: [ISO8601DateFormatter] = {
            let full = ISO8601DateFormatter()
            full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let basic = ISO8601DateFormatter()
            basic.formatOptions = [.withInternetDateTime]
            return [full, basic]
        }()
        for f in formatters {
            if let date = f.date(from: self) {
                let seconds = -date.timeIntervalSinceNow
                if seconds < 60        { return "\(Int(seconds))s" }
                if seconds < 3600      { return "\(Int(seconds/60))m" }
                if seconds < 86400     { return "\(Int(seconds/3600))h" }
                return "\(Int(seconds/86400))d"
            }
        }
        return self
    }

    var isoDate: Date? {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: self) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: self)
    }
}

// MARK: – Numeric resource parsing (K8s notation)

extension String {
    /// Convert a K8s quantity string to a Double
    /// e.g. "500m" → 0.5 (CPU cores), "1Gi" → 1073741824 (bytes)
    var k8sQuantityToDouble: Double? {
        if self.hasSuffix("m") {
            return Double(dropLast()) .map { $0 / 1000 }
        }
        if self.hasSuffix("Ki") { return Double(dropLast(2)).map { $0 * 1024 } }
        if self.hasSuffix("Mi") { return Double(dropLast(2)).map { $0 * 1048576 } }
        if self.hasSuffix("Gi") { return Double(dropLast(2)).map { $0 * 1073741824 } }
        if self.hasSuffix("Ti") { return Double(dropLast(2)).map { $0 * 1099511627776 } }
        if self.hasSuffix("n")  { return Double(dropLast()).map { $0 / 1_000_000_000 } } // nanocores
        return Double(self)
    }

    /// Format bytes as human-readable
    var formattedBytes: String {
        guard let v = k8sQuantityToDouble else { return self }
        let units = ["B","KB","MB","GB","TB"]
        var val = v; var idx = 0
        while val >= 1024 && idx < units.count - 1 { val /= 1024; idx += 1 }
        return String(format: "%.1f %@", val, units[idx])
    }
}
