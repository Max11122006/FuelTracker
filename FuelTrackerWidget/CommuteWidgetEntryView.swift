import SwiftUI
import WidgetKit

struct CommuteWidgetEntryView: View {
    let entry: CommuteEntry
    @Environment(\.widgetFamily) private var family

    // MARK: - Traffic-light colour

    private var trafficColor: Color {
        if !entry.hasData || entry.isStale { return .gray }
        return entry.altIsWorthIt ? Color("PinGreen") : Color("PinRed")
    }

    private var trafficSymbol: String {
        if !entry.hasData || entry.isStale { return "questionmark.circle.fill" }
        return entry.altIsWorthIt ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    // MARK: - Body

    var body: some View {
        switch family {
        case .systemSmall: smallView
        default:           mediumView
        }
    }

    // MARK: - Small widget (verdict + saving)

    private var smallView: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(UIColor.systemBackground).opacity(0.15))

            VStack(alignment: .leading, spacing: 6) {
                // App label
                Label("FuelTracker", systemImage: "fuelpump.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                // Traffic-light verdict
                Image(systemName: trafficSymbol)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(trafficColor)

                if entry.hasData && !entry.isStale {
                    Text(entry.altIsWorthIt ? "WORTH IT" : "STAY ESSO")
                        .font(.system(size: 12, weight: .black))
                        .kerning(0.3)
                        .foregroundColor(trafficColor)

                    Text(entry.formattedSaving)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    Text(entry.isStale ? "Stale data" : "Open app")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                staleness
            }
            .padding(12)
        }
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Medium widget (full comparison)

    private var mediumView: some View {
        HStack(spacing: 0) {
            // Left: traffic light
            VStack(spacing: 4) {
                Image(systemName: trafficSymbol)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(trafficColor)

                Text(entry.altIsWorthIt ? "WORTH IT" : "STAY ESSO")
                    .font(.system(size: 11, weight: .black))
                    .kerning(0.3)
                    .foregroundColor(trafficColor)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 90)
            .padding(.leading, 14)

            Divider()
                .background(Color.secondary.opacity(0.3))
                .padding(.vertical, 10)
                .padding(.horizontal, 8)

            // Right: station details
            if entry.hasData && !entry.isStale {
                VStack(alignment: .leading, spacing: 6) {
                    Label("FuelTracker", systemImage: "fuelpump.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)

                    // Esso row
                    stationRow(
                        symbol: "creditcard.fill",
                        color:  .blue,
                        name:   entry.essoName,
                        price:  entry.formattedEssoPrice,
                        note:   "w/ card"
                    )

                    // Best alternative row
                    stationRow(
                        symbol: entry.altIsWorthIt ? "star.fill" : "minus.circle",
                        color:  trafficColor,
                        name:   entry.altName,
                        price:  entry.formattedAltPrice,
                        note:   entry.formattedSaving
                    )

                    staleness
                }
                .padding(.trailing, 12)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.isStale ? "Data may be stale" : "Open FuelTracker to load prices")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 12)
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func stationRow(symbol: String, color: Color, name: String, price: String, note: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 14)

            Text(name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text(price)
                    .font(.system(size: 13, weight: .bold))
                Text(note)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var staleness: some View {
        Group {
            if let ts = entry.lastUpdated {
                let fmt = RelativeDateTimeFormatter()
                Text(fmt.localizedString(for: ts, relativeTo: Date()))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Previews (iOS 16 compatible — uses PreviewProvider + WidgetPreviewContext)

struct CommuteWidgetSmall_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CommuteWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small — Worth It")

            CommuteWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium — Worth It")

            CommuteWidgetEntryView(entry: CommuteEntry(
                date:                  Date(),
                essoName:              "Esso Straiton",
                essoStickerPricePence: 148.9,
                essoDiscountPence:     10.0,
                essoDistanceMiles:     0.4,
                altName:               "Shell Gilmerton",
                altPricePence:         149.9,
                altIsWorthIt:          false,
                altNetSavingPence:     -85,
                lastUpdated:           Date(),
                hasData:               true
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small — Not Worth It")
        }
    }
}
