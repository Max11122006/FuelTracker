import SwiftUI

/// The "Best Pick" tab — a clear, opinionated answer to "where should I fill up?"
struct BestPickView: View {
    @EnvironmentObject var stationsVM: StationsViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel

    var body: some View {
        NavigationView {
            Group {
                if stationsVM.loadingState.isLoading && stationsVM.results.isEmpty {
                    loadingView
                } else if stationsVM.essoStation == nil && stationsVM.results.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            verdictCard
                            if let best = bestAlt, best.isWorthIt {
                                comparisonCard(best: best)
                            } else if let esso = stationsVM.essoStation {
                                essoWinsCard(esso: esso)
                            }
                            if stationsVM.results.count > 1 {
                                otherOptionsCard
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                }
            }
            .navigationTitle("Best Pick")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await stationsVM.refresh(settings: settingsVM.currentSettings) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(stationsVM.loadingState.isLoading)
                }
            }
            .refreshable {
                await stationsVM.refresh(settings: settingsVM.currentSettings)
            }
        }
    }

    // MARK: - Computed helpers

    private var bestAlt: WorthItResult? { stationsVM.results.first }

    private var essoEffectivePrice: Double {
        (stationsVM.essoStation?.pricePerLitre ?? 0) - settingsVM.essoDiscountPence
    }

    private var essoFillUpCost: Double {
        essoEffectivePrice * settingsVM.fillUpLitres / 100.0
    }

    // MARK: - Verdict card

    private var verdictCard: some View {
        let worthIt = bestAlt?.isWorthIt == true
        let station = worthIt ? bestAlt?.station.name ?? "" : (stationsVM.essoStation?.name ?? "Esso")
        let saving  = bestAlt?.formattedNetSaving ?? ""

        return VStack(spacing: 14) {
            // Icon
            Image(systemName: worthIt ? "checkmark.circle.fill" : "creditcard.fill")
                .font(.system(size: 52))
                .foregroundColor(worthIt ? Color("PinGreen") : .blue)

            // Recommendation
            VStack(spacing: 4) {
                Text(worthIt ? "Go here instead" : "Stick with your Esso")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(station)
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if worthIt {
                    Text(saving)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color("PinGreen"))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }

    // MARK: - Esso wins

    private func essoWinsCard(esso: FuelStation) -> some View {
        card(title: "Why Esso wins") {
            let altPrice = bestAlt?.altPricePence ?? 0
            let altName  = bestAlt?.station.name ?? "alternatives"

            infoRow(icon: "creditcard.fill",  label: "Your Esso (with card)",     value: String(format: "%.1fp/L · £%.2f", essoEffectivePrice, essoFillUpCost), iconColor: .blue)

            if let best = bestAlt {
                infoRow(icon: "fuelpump",     label: altName,                     value: String(format: "%.1fp/L · £%.2f", altPrice, best.fillUpCostPounds), iconColor: .secondary)

                if best.extraDistanceMiles > 0.1 {
                    Divider().padding(.vertical, 4)
                    infoRow(icon: "arrow.triangle.branch", label: "Detour to \(altName)", value: best.formattedExtraDistance, iconColor: .orange)
                    infoRow(icon: "drop.fill",             label: "Extra fuel cost",       value: best.formattedExtraFuelCost, iconColor: .orange)
                }

                Divider().padding(.vertical, 4)
                infoRow(icon: "xmark.circle.fill", label: "Not worth the detour", value: best.formattedNetSaving, iconColor: Color("PinRed"))
            }
        }
    }

    // MARK: - Comparison (alt wins)

    private func comparisonCard(best: WorthItResult) -> some View {
        let fill = settingsVM.fillUpLitres

        return card(title: "The numbers") {
            // Esso row
            GroupBox {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(stationsVM.essoStation?.name ?? "Esso", systemImage: "creditcard.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                        Text("With your fuel card")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1fp/L", essoEffectivePrice))
                            .font(.system(size: 14, weight: .semibold))
                        Text(String(format: "£%.2f to fill", essoFillUpCost))
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            .groupBoxStyle(TintedGroupBoxStyle(tint: Color.blue.opacity(0.15)))

            // Alt row
            GroupBox {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(best.station.name, systemImage: "fuelpump.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color("PinGreen"))
                            .lineLimit(1)
                        Text(String(format: "%.1f mi away", best.distanceToAltMiles))
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1fp/L", best.altPricePence))
                            .font(.system(size: 14, weight: .semibold))
                        Text(String(format: "£%.2f to fill", best.fillUpCostPounds))
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            .groupBoxStyle(TintedGroupBoxStyle(tint: Color("PinGreen").opacity(0.15)))

            // Breakdown
            Divider().padding(.vertical, 2)

            if best.extraDistanceMiles > 0.1 {
                infoRow(icon: "arrow.triangle.branch", label: "Extra drive",     value: best.formattedExtraDistance,   iconColor: .orange)
                infoRow(icon: "drop.fill",             label: "Detour fuel cost", value: best.formattedExtraFuelCost,  iconColor: .orange)
                Divider().padding(.vertical, 2)
            }

            infoRow(icon: "minus.circle",         label: "Gross saving",            value: best.formattedGrossSaving, iconColor: .secondary)
            infoRow(icon: "checkmark.circle.fill", label: "Net saving (inc. detour)", value: best.formattedNetSaving, iconColor: Color("PinGreen"))
        }
    }

    // MARK: - Other options

    private var otherOptionsCard: some View {
        card(title: "Other nearby stations") {
            ForEach(Array(stationsVM.results.dropFirst().prefix(5).enumerated()), id: \.element.id) { idx, result in
                if idx > 0 { Divider() }
                HStack(spacing: 10) {
                    Circle()
                        .fill(result.pinColour(cheapestEffectivePrice: stationsVM.cheapestEffectivePrice).color)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(result.station.name)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Text(result.formattedDistance)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(result.formattedFillUpCost)
                            .font(.system(size: 13, weight: .semibold))
                        Text(result.formattedNetSaving)
                            .font(.caption2)
                            .foregroundColor(result.isWorthIt ? Color("PinGreen") : Color("PinRed"))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Shared helpers

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }

    private func infoRow(icon: String, label: String, value: String, iconColor: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(iconColor)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.vertical, 1)
    }

    // MARK: - Empty / loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(stationsVM.loadingState.statusText)
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48)).foregroundColor(.secondary)
            Text("No data yet")
                .font(.title3).fontWeight(.semibold)
            Text("Go to the Stations tab and refresh to load prices.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - GroupBox style helper

private struct TintedGroupBoxStyle: GroupBoxStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.content
        }
        .padding(12)
        .background(tint)
        .cornerRadius(10)
    }
}

#Preview {
    BestPickView()
        .environmentObject(StationsViewModel())
        .environmentObject(SettingsViewModel())
        .preferredColorScheme(.dark)
}
