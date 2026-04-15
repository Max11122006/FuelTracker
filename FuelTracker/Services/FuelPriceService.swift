import Foundation
import CoreLocation
import CoreData
import WidgetKit

/// Orchestrates all data sources: Google Places → Esso feed → CoreData → WorthItCalculator.
/// Returns a sorted `[WorthItResult]` ready for display and writes the headline result
/// to `AppGroupStore` so the widget can show it without making network calls.
final class FuelPriceService {
    static let shared = FuelPriceService()
    private init() {}

    private let places      = GooglePlacesService.shared
    private let essoFeed    = EssoFeedService.shared
    private let persistence = PersistenceController.shared

    // MARK: - Main refresh

    /// - Returns: `(results, nearestEsso)` — `results` is non-Esso stations sorted by
    ///            effective price; `nearestEsso` is the Esso reference station (may be nil
    ///            if no Esso found or price unavailable).
    func refreshPrices(
        for coordinate: CLLocationCoordinate2D,
        settings: UserSettings
    ) async throws -> (results: [WorthItResult], essoStation: FuelStation?) {

        // 1. Fetch station locations from Google Places
        var stations = try await places.fetchNearbyStations(coordinate: coordinate)

        // 2. If Places API isn't configured, fall back to whatever is in CoreData
        if stations.isEmpty {
            stations = loadCachedStations()
        }

        // 3. Enrich stations with prices
        var enriched: [FuelStation] = []
        let storedPrices = loadLatestStoredPrices()

        for var station in stations {
            // Esso stations: try the live feed first
            if station.isEsso {
                if let livePricePence = await essoFeed.price(near: station.coordinate) {
                    station.pricePerLitre = livePricePence
                    station.priceSource   = .essoFeed
                    station.lastUpdated   = Date()
                }
            }
            // Manual / previously-stored price overrides if it's more recent or if we
            // still have no price from the live source.
            if let record = storedPrices[station.id] {
                let recordDate = record.recordedAt ?? .distantPast
                let liveDate   = station.lastUpdated ?? .distantPast
                if record.source == "manual" || recordDate > liveDate || station.pricePerLitre == nil {
                    station.pricePerLitre = record.pricePerLitre
                    station.priceSource   = FuelStation.PriceSource(rawValue: record.source ?? "") ?? .unknown
                    station.lastUpdated   = record.recordedAt
                }
            }
            enriched.append(station)
        }

        // 4. Find the nearest Esso with a known price
        let essoStations = enriched.filter { $0.isEsso && $0.pricePerLitre != nil }
        let nearestEsso: FuelStation? = essoStations.min {
            WorthItCalculator.haversineDistanceMiles(from: coordinate, to: $0.coordinate) <
            WorthItCalculator.haversineDistanceMiles(from: coordinate, to: $1.coordinate)
        }

        guard let esso = nearestEsso, let essoPricePence = esso.pricePerLitre else {
            // No Esso reference price — persist what we have and return empty results
            persistStations(enriched)
            return ([], nil)
        }

        let distToEsso = WorthItCalculator.haversineDistanceMiles(
            from: coordinate, to: esso.coordinate
        )

        // 5. Calculate worth-it for every non-Esso station that has a price
        let nonEsso = enriched.filter { !$0.isEsso && $0.pricePerLitre != nil }
        let results: [WorthItResult] = nonEsso.compactMap { station in
            guard let price = station.pricePerLitre else { return nil }
            let distToAlt = WorthItCalculator.haversineDistanceMiles(
                from: coordinate, to: station.coordinate
            )
            return WorthItCalculator.calculate(
                essoStickerPricePence: essoPricePence,
                essoDiscountPence:     settings.essoDiscountPence,
                altPricePence:         price,
                distanceToEssoMiles:   distToEsso,
                distanceToAltMiles:    distToAlt,
                mpg:                   settings.carMPG,
                fillLitres:            settings.fillUpLitres,
                station:               station
            )
        }

        // 6. Sort by effective price (cheapest first)
        let sorted = results.sorted { $0.effectivePricePerLitre < $1.effectivePricePerLitre }

        // 7. Write headline data to App Group for widget
        AppGroupStore.nearestEssoStickerPrice  = essoPricePence
        AppGroupStore.nearestEssoDiscountPence = settings.essoDiscountPence
        AppGroupStore.nearestEssoName          = esso.name
        AppGroupStore.nearestEssoDistanceMiles = distToEsso
        AppGroupStore.userMPG                  = settings.carMPG
        AppGroupStore.userFillLitres           = settings.fillUpLitres
        AppGroupStore.lastUpdated              = Date()

        if let best = sorted.first {
            AppGroupStore.bestAltPrice          = best.altPricePence
            AppGroupStore.bestAltName           = best.station.name
            AppGroupStore.bestAltIsWorthIt      = best.isWorthIt
            AppGroupStore.bestAltNetSavingPence = best.netSavingsPence
        }

        // 8. Persist enriched stations to CoreData
        persistStations(enriched)

        // 9. Reload widgets
        WidgetCenter.shared.reloadAllTimelines()

        return (sorted, esso)
    }

    // MARK: - Manual price entry

    func saveManualPrice(for station: FuelStation, price: Double, fuelType: String = "unleaded") {
        let ctx = persistence.newBackgroundContext()
        ctx.perform {
            let stationCD = self.findOrCreateStation(station, in: ctx)

            let record         = FuelPriceRecordCD(context: ctx)
            record.id          = UUID()
            record.pricePerLitre = price
            record.fuelType    = fuelType
            record.recordedAt  = Date()
            record.source      = FuelStation.PriceSource.manual.rawValue
            record.station     = stationCD

            try? ctx.save()
        }
    }

    // MARK: - CoreData helpers

    private func loadCachedStations() -> [FuelStation] {
        let ctx = persistence.viewContext
        let req = FuelStationCD.fetchRequest()
        let cds = (try? ctx.fetch(req)) ?? []
        return cds.compactMap { FuelStation(from: $0) }
    }

    private func loadLatestStoredPrices() -> [String: FuelPriceRecordCD] {
        let ctx      = persistence.viewContext
        let stationReq = FuelStationCD.fetchRequest()
        let stations = (try? ctx.fetch(stationReq)) ?? []

        var map: [String: FuelPriceRecordCD] = [:]
        for station in stations {
            guard let pid = station.placeID, let record = station.latestPrice() else { continue }
            map[pid] = record
        }
        return map
    }

    private func persistStations(_ stations: [FuelStation]) {
        let ctx = persistence.newBackgroundContext()
        ctx.perform {
            for station in stations {
                guard station.pricePerLitre != nil else { continue }
                let stationCD = self.findOrCreateStation(station, in: ctx)

                // Only persist if we have a new price (manual entries are already persisted)
                if station.priceSource != .manual, let price = station.pricePerLitre {
                    let record           = FuelPriceRecordCD(context: ctx)
                    record.id            = UUID()
                    record.pricePerLitre = price
                    record.fuelType      = station.fuelType
                    record.recordedAt    = station.lastUpdated ?? Date()
                    record.source        = station.priceSource.rawValue
                    record.station       = stationCD
                }
            }
            try? ctx.save()
        }
    }

    @discardableResult
    private func findOrCreateStation(_ station: FuelStation, in ctx: NSManagedObjectContext) -> FuelStationCD {
        let req        = FuelStationCD.fetchRequest()
        req.predicate  = NSPredicate(format: "placeID == %@", station.id)
        req.fetchLimit = 1

        let cd: FuelStationCD = (try? ctx.fetch(req).first) ?? FuelStationCD(context: ctx)
        cd.placeID   = station.id
        cd.name      = station.name
        cd.brand     = station.brand
        cd.latitude  = station.coordinate.latitude
        cd.longitude = station.coordinate.longitude
        cd.address   = station.address
        return cd
    }
}
