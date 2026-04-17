import SwiftUI

struct StationsListView: View {
    @EnvironmentObject var stationsVM: StationsViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel

    @State private var showManualEntry   = false
    @State private var selectedStation: FuelStation?
    @State private var expandedID: String?

    var body: some View {
        NavigationView {
            Group {
                if stationsVM.loadingState.isLoading && stationsVM.results.isEmpty {
                    loadingView
                } else if stationsVM.results.isEmpty && stationsVM.essoStation == nil {
                    emptyView
                } else {
                    list
                }
            }
            .navigationTitle("Fuel Stations")
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
            .sheet(item: $selectedStation) { station in
                ManualPriceEntryView(station: station)
            }
        }
    }

    // MARK: - List content

    private var list: some View {
        List {
            // ── Esso reference card ────────────────────────────────────────────
            if let esso = stationsVM.essoStation {
                Section {
                    EssoReferenceCard(
                        station:        esso,
                        discountPence:  settingsVM.essoDiscountPence,
                        fillLitres:     settingsVM.fillUpLitres
                    )
                    .listRowBackground(Color("CardBackground"))
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } header: {
                    Text("Your Esso (Card Discount Applied)")
                }
            }

            // ── Alternatives ───────────────────────────────────────────────────
            if !stationsVM.results.isEmpty {
                Section {
                    ForEach(Array(stationsVM.results.enumerated()), id: \.element.id) { idx, result in
                        StationRowView(
                            result:         result,
                            rank:           idx + 1,
                            cheapestPrice:  stationsVM.cheapestEffectivePrice,
                            isExpanded:     expandedID == result.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                expandedID = expandedID == result.id ? nil : result.id
                            }
                        }
                        .listRowBackground(Color("CardBackground"))
                        .swipeActions(edge: .trailing) {
                            Button {
                                selectedStation = result.station
                            } label: {
                                Label("Update Price", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                } header: {
                    HStack {
                        Text("Alternatives")
                        Spacer()
                        Text("Tap a row for breakdown")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // ── Status footer ──────────────────────────────────────────────────
            Section {
                HStack {
                    Text(stationsVM.loadingState.statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if stationsVM.loadingState.isLoading {
                        Spacer()
                        ProgressView().scaleEffect(0.7)
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Empty / loading states

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(stationsVM.loadingState.statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "fuelpump.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No stations found")
                .font(.title3).fontWeight(.semibold)

            Text("Pull down to refresh, or check that Location Services are enabled and your Fuel Finder API credentials are configured in Settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Refresh") {
                Task { await stationsVM.refresh(settings: settingsVM.currentSettings) }
            }
            .buttonStyle(.borderedProminent)

            if case .error(let msg) = stationsVM.loadingState {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Esso reference card

private struct EssoReferenceCard: View {
    let station: FuelStation
    let discountPence: Double
    let fillLitres: Double

    private var stickerPrice: Double   { station.pricePerLitre ?? 0 }
    private var effectivePrice: Double { stickerPrice - discountPence }
    private var fillUpCost: Double     { effectivePrice * fillLitres / 100.0 }

    var body: some View {
        HStack(spacing: 12) {
            // Blue indicator bar (Esso = blue)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.blue)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(station.name, systemImage: "creditcard.fill")
                        .font(.subheadline).fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    Text("YOUR CARD")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "%.1fp", stickerPrice))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .strikethrough(color: .secondary)
                        Text("Pump")
                            .font(.caption2).foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "%.1fp", effectivePrice))
                            .font(.system(size: 16, weight: .bold))
                        Text("With card")
                            .font(.caption2).foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "£%.2f", fillUpCost))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.blue)
                        Text("to fill (\(String(format: "%.0f", fillLitres)) L)")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }

                StalenessLabel(lastUpdated: station.lastUpdated, source: station.priceSource)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StationsListView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
        .environmentObject(StationsViewModel())
        .environmentObject(SettingsViewModel())
        .preferredColorScheme(.dark)
}
