import SwiftUI

struct StalenessLabel: View {
    let lastUpdated: Date?
    let source: FuelStation.PriceSource

    private var ageHours: Double? {
        guard let d = lastUpdated else { return nil }
        return Date().timeIntervalSince(d) / 3600
    }

    private var label: String {
        guard let hours = ageHours else { return "Price unknown" }
        if source == .manual {
            return hours < 1
                ? "Manual · just now"
                : String(format: "Manual · %.0fh ago", hours)
        }
        if hours < 1   { return "Just updated" }
        if hours < 24  { return String(format: "%.0fh ago", hours) }
        return String(format: "%.0fd ago — may be stale", hours / 24)
    }

    private var color: Color {
        guard let hours = ageHours else { return .secondary }
        if source == .manual { return .orange }
        if hours < Config.freshThresholdHours { return Color("PinGreen") }
        if hours < Config.staleThresholdHours { return .yellow }
        return Color("PinRed")
    }

    var body: some View {
        Text(label)
            .font(.caption2)
            .foregroundColor(color)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        StalenessLabel(lastUpdated: Date(),                                     source: .essoFeed)
        StalenessLabel(lastUpdated: Date(timeIntervalSinceNow: -3600 * 2),     source: .essoFeed)
        StalenessLabel(lastUpdated: Date(timeIntervalSinceNow: -3600 * 6),     source: .essoFeed)
        StalenessLabel(lastUpdated: Date(timeIntervalSinceNow: -3600),         source: .manual)
        StalenessLabel(lastUpdated: nil,                                        source: .unknown)
    }
    .padding()
    .preferredColorScheme(.dark)
}
