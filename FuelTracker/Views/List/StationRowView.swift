import SwiftUI

struct StationRowView: View {
    let result: WorthItResult
    let rank: Int
    let cheapestPrice: Double
    let isExpanded: Bool

    private var pinColour: WorthItResult.PinColour {
        result.pinColour(cheapestEffectivePrice: cheapestPrice)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Colour indicator bar
            RoundedRectangle(cornerRadius: 3)
                .fill(pinColour.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 0) {
                // ── Compact header (always visible) ─────────────────────────
                compactHeader
                    .padding(.bottom, isExpanded ? 10 : 0)

                // ── Expanded breakdown ───────────────────────────────────────
                if isExpanded {
                    Divider()
                        .padding(.bottom, 10)
                    expandedDetail
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }

    // MARK: - Compact header

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Row 1: name + verdict
            HStack(alignment: .center, spacing: 6) {
                Text(result.station.name)
                    .font(.subheadline).fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                VerdictBadge(isWorthIt: result.isWorthIt, savingText: result.formattedNetSaving)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Row 2: pump price | effective price | distance
            HStack(spacing: 0) {
                priceChip(label: "Pump", value: result.formattedStickerPrice)
                Spacer()
                priceChip(label: "Effective", value: result.formattedEffectivePrice, bold: true)
                Spacer()
                // Fill-up cost — the headline number
                VStack(alignment: .trailing, spacing: 1) {
                    Text(result.formattedFillUpCost)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(result.isWorthIt ? Color("PinGreen") : .primary)
                    Text("to fill (\(result.formattedFillVolume))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Row 3: distance + staleness
            HStack(spacing: 8) {
                Label(result.formattedDistance, systemImage: "location.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if result.extraDistanceMiles > 0.1 {
                    Text("·")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Label(result.formattedExtraDistance, systemImage: "arrow.triangle.branch")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
                StalenessLabel(
                    lastUpdated: result.station.lastUpdated,
                    source: result.station.priceSource
                )
            }
        }
    }

    // MARK: - Expanded detail

    private var expandedDetail: some View {
        VStack(spacing: 0) {
            detailRow(
                icon: "fuelpump.fill",
                label: "Pump price",
                value: result.formattedStickerPrice + "/L",
                color: .secondary
            )
            detailRow(
                icon: "creditcard.slash",
                label: "Fill-up at pump",
                value: result.formattedFillUpCost,
                subvalue: result.formattedFillVolume,
                color: .primary
            )

            if result.extraDistanceMiles > 0.1 {
                Divider().padding(.vertical, 6)

                detailRow(
                    icon: "arrow.triangle.branch",
                    label: "Extra drive vs Esso",
                    value: result.formattedExtraDistance,
                    color: .orange
                )
                detailRow(
                    icon: "drop.fill",
                    label: "Extra fuel for detour",
                    value: result.formattedExtraFuelCost,
                    color: .orange
                )
            }

            Divider().padding(.vertical, 6)

            detailRow(
                icon: "minus.circle",
                label: "Gross saving vs Esso",
                value: result.formattedGrossSaving,
                color: .secondary
            )
            detailRow(
                icon: result.isWorthIt ? "checkmark.circle.fill" : "xmark.circle.fill",
                label: "Net saving after detour",
                value: result.formattedNetSaving,
                color: result.isWorthIt ? Color("PinGreen") : Color("PinRed"),
                bold: true
            )
        }
        .padding(.bottom, 2)
    }

    // MARK: - Helpers

    private func priceChip(label: String, value: String, bold: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: bold ? .bold : .medium))
                .foregroundColor(bold ? .primary : .secondary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func detailRow(
        icon: String,
        label: String,
        value: String,
        subvalue: String? = nil,
        color: Color,
        bold: Bool = false
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Spacer()

            if let sub = subvalue {
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
            }

            Text(value)
                .font(.system(size: 13, weight: bold ? .semibold : .regular))
                .foregroundColor(color)
        }
        .padding(.vertical, 2)
    }
}
