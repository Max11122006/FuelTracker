import SwiftUI

struct StationRowView: View {
    let result: WorthItResult
    let rank: Int
    let cheapestPrice: Double

    private var pinColour: WorthItResult.PinColour {
        result.pinColour(cheapestEffectivePrice: cheapestPrice)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Colour indicator bar
            RoundedRectangle(cornerRadius: 3)
                .fill(pinColour.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                // Station name + verdict
                HStack {
                    Text(result.station.name)
                        .font(.subheadline).fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    VerdictBadge(isWorthIt: result.isWorthIt, savingText: result.formattedNetSaving)
                }

                // Price row
                HStack(spacing: 16) {
                    priceTag(label: "Pump",      value: result.formattedStickerPrice)
                    priceTag(label: "Effective", value: result.formattedEffectivePrice, highlight: true)
                    Spacer()
                    distanceTag
                }

                // Extra cost + staleness
                HStack(spacing: 8) {
                    if result.extraDistanceMiles > 0.05 {
                        Label(result.formattedExtraFuelCost, systemImage: "arrow.triangle.branch")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    StalenessLabel(
                        lastUpdated: result.station.lastUpdated,
                        source: result.station.priceSource
                    )
                    Spacer()
                    Text(result.formattedNetSaving)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(result.isWorthIt ? Color("PinGreen") : Color("PinRed"))
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    private func priceTag(label: String, value: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: highlight ? .bold : .medium))
                .foregroundColor(highlight ? .primary : .secondary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var distanceTag: some View {
        HStack(spacing: 3) {
            Image(systemName: "location.fill")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(result.formattedDistance)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
