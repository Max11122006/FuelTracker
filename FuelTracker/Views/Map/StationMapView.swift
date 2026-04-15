import SwiftUI
import MapKit

struct StationMapView: View {
    @EnvironmentObject var stationsVM: StationsViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel

    @State private var region = MKCoordinateRegion(
        // Default centred on Edinburgh (EH17 8LW area)
        center: CLLocationCoordinate2D(latitude: 55.9060, longitude: -3.1285),
        latitudinalMeters: 6000,
        longitudinalMeters: 6000
    )
    @State private var selectedID: String?

    // MARK: - Annotation data

    private var annotations: [StationAnnotationData] {
        let cheapest = stationsVM.cheapestEffectivePrice
        var items: [StationAnnotationData] = []

        // Non-Esso stations
        for result in stationsVM.results {
            let colour: StationAnnotationData.PinColour
            let diff = result.effectivePricePerLitre - cheapest
            if diff <= Config.greenThreshold      { colour = .green }
            else if diff <= Config.amberThreshold { colour = .amber }
            else                                   { colour = .red   }

            items.append(StationAnnotationData(
                id:                result.id,
                coordinate:        result.station.coordinate,
                displayPricePence: result.effectivePricePerLitre,
                pinColor:          colour,
                isEsso:            false
            ))
        }

        // Nearest Esso (with discount applied)
        if let esso = stationsVM.essoStation {
            let effectiveEssoPrice = esso.pricePerLitre.map {
                $0 - settingsVM.essoDiscountPence
            }
            items.append(StationAnnotationData(
                id:                esso.id,
                coordinate:        esso.coordinate,
                displayPricePence: effectiveEssoPrice,
                pinColor:          .blue,
                isEsso:            true
            ))
        }

        return items
    }

    // MARK: - Selected detail

    private var selectedResult: WorthItResult? {
        guard let id = selectedID else { return nil }
        return stationsVM.results.first { $0.id == id }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            map
            overlays
        }
        .ignoresSafeArea(edges: .top)
        .onChange(of: stationsVM.results) { _ in fitRegionToResults() }
    }

    // MARK: - Subviews

    private var map: some View {
        Map(coordinateRegion: $region, annotationItems: annotations) { item in
            MapAnnotation(coordinate: item.coordinate) {
                pinView(for: item)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedID = selectedID == item.id ? nil : item.id
                        }
                    }
                    .zIndex(selectedID == item.id ? 1 : 0)
            }
        }
    }

    private func pinView(for item: StationAnnotationData) -> some View {
        PricePin(
            displayPricePence: item.displayPricePence,
            pinColor:          item.pinColor.color,
            isEsso:            item.isEsso,
            isSelected:        selectedID == item.id
        )
    }

    @ViewBuilder
    private var overlays: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack {
                Text(stationsVM.loadingState.statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if stationsVM.loadingState.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)

            Spacer()

            // Detail card for selected station
            if let result = selectedResult {
                StationDetailCard(result: result, cheapestPrice: stationsVM.cheapestEffectivePrice)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Region fitting

    private func fitRegionToResults() {
        let coords = stationsVM.allStationsForMap.map(\.coordinate)
        guard !coords.isEmpty else { return }

        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)

        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!

        let centre = CLLocationCoordinate2D(
            latitude:  (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  max(0.01, (maxLat - minLat) * 1.4),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.4)
        )
        withAnimation { region = MKCoordinateRegion(center: centre, span: span) }
    }
}

// MARK: - Station detail card (shown at map bottom when pin tapped)

private struct StationDetailCard: View {
    let result: WorthItResult
    let cheapestPrice: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.station.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(result.station.address ?? result.formattedDistance)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                VerdictBadge(isWorthIt: result.isWorthIt, savingText: result.formattedNetSaving)
            }

            HStack(spacing: 20) {
                stat(title: "Pump",      value: result.formattedStickerPrice)
                stat(title: "Effective", value: result.formattedEffectivePrice)
                stat(title: "Distance",  value: result.formattedDistance)
                stat(title: "Net",       value: result.formattedNetSaving)
            }

            StalenessLabel(lastUpdated: result.station.lastUpdated, source: result.station.priceSource)
        }
        .padding()
        .background(Color("CardBackground").opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    StationMapView()
        .environmentObject(StationsViewModel())
        .environmentObject(SettingsViewModel())
        .preferredColorScheme(.dark)
}
