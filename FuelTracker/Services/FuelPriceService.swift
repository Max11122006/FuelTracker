import Foundation
import CoreLocation
import CoreData
import WidgetKit

/// Orchestrates FuelFinderAPIService → CoreData → WorthItCalculator.
/// Public interface unchanged — callers (StationsViewModel, BGTask) are unaffected.
final class FuelPriceService {
    static let shared = FuelPriceService()
    private init() {}

    private let api         = FuelFinderAPIService.shared
    private let persistence = PersistenceController.shared

    // MARK: - Main refresh

    /// Returns `(results, nearestEsso)`.
    /// `results` contains non-Esso stations sorted by effective price.
    /// `nearestEsso` is the nearest Esso with the card discount as the reference.
    func refreshPrices(
        for coordinate: CLLocationCoordinate2D,
        settings: UserSettings
    ) async throws -> (results: [WorthItResult], essoStation: FuelStation?) {

        // 1. Fetch nearby stations with prices from the Fuel Finder API.
        //    Falls back to CoreData cache if credentials not configured yet.
        var stations: [FuelStation]
        do {
            stations = try await api.fetchNearbyStations(
                coordinate:   coordinate,
                radiusMiles:  Config.defaultSearchRadiusMiles
            )
        } catch FuelFinderAPIService.FuelFinderError.credentialsNotConfigured {
            stations = loadCachedStations()
        }

        // 2. Overlay any manual price entries from CoreData.
        //    Manual entries win if they're newer than the API data.
        let storedPrices = loadLatestStoredPrices()
        stations = stations.map { station in
            var s = station
            applyManualOverride(&s, stored: storedPrices)
            return s
        }

        // 3. Persist enriched stations (API prices only; manual entries persisted at entry time).
        persistStations(stations)

        // 4. Find the nearest Esso station that has a price.
        let essoStations = stations.filter { $0.isEsso && $0.pricePerLitre != nil }
        guard let nearestEsso = essoStations.min(by: {
            WorthItCalculator.haversineDistanceMiles(from: coordinate, to: $0.coordinate) <
            WorthItCalculator.haversineDistanceMiles(from: coordinate, to: $1.coordinate)
        }), let essoPricePence = nearestEsso.pricePerLitre else {
            return ([], nil)
        }

        let distToEsso = WorthItCalculator.haversineDistanceMiles(
            from: coordinate, to: nearestEsso.coordinate
        )

        // 5. Calculate worth-it for every non-Esso station that has a price.
        let nonEsso = stations.filter { !$0.isEsso && $0.pricePerLitre != nil }
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

        let sorted = results.sorted { $0.effectivePricePerLitre < $1.effectivePricePerLitre }

        // 6. Write headline data to App Group UserDefaults for the widget.
        AppGroupStore.nearestEssoStickerPrice  = essoPricePence
        AppGroupStore.nearestEssoDiscountPence = settings.essoDiscountPence
        AppGroupStore.nearestEssoName          = nearestEsso.name
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

        WidgetCenter.shared.reloadAllTimelines()

        return (sorted, nearestEsso)
    }

    // MARK: - Manual price entry

    func saveManualPrice(for station: FuelStation, price: Double, fuelType: String = "unleaded") {
        let ctx = persistence.newBackgroundContext()
        ctx.perform {
            let stationCD        = self.findOrCreateStation(station, in: ctx)
            let record           = FuelPriceRecordCD(context: ctx)
            record.id            = UUID()
            record.pricePerLitre = price
            record.fuelType      = fuelType
            record.recordedAt    = Date()
            record.source        = FuelStation.PriceSource.manual.rawValue
            record.station       = stationCD
            try? ctx.save()
        }
    }

    // MARK: - Manual override helper

    private func applyManualOverride(_ station: inout FuelStation,
                                     stored: [String: FuelPriceRecordCD]) {
        guard let record = stored[station.id] else { return }
        let recordDate = record.recordedAt ?? .distantPast
        let apiDate    = station.lastUpdated ?? .distantPast
        if record.source == FuelStation.PriceSource.manual.rawValue || recordDate > apiDate {
            station.pricePerLitre = record.pricePerLitre
            station.priceSource   = FuelStation.PriceSource(rawValue: record.source ?? "") ?? .unknown
            station.lastUpdated   = record.recordedAt
        }
    }

    // MARK: - CoreData helpers

    private func loadCachedStations() -> [FuelStation] {
        ((try? persistence.viewContext.fetch(FuelStationCD.fetchRequest())) ?? [])
            .compactMap { FuelStation(from: $0) }
    }

    private func loadLatestStoredPrices() -> [String: FuelPriceRecordCD] {
        var map: [String: FuelPriceRecordCD] = [:]
        let stations = (try? persistence.viewContext.fetch(FuelStationCD.fetchRequest())) ?? []
        for station in stations {
            guard let pid = station.placeID, let record = station.latestPrice() else { continue }
            map[pid] = record
        }
        return map
    }

    private func persistStations(_ stations: [FuelStation]) {
        let ctx = persistence.newBackgroundContext()
        ctx.perform {
            for station in stations where station.priceSource != .manual {
                guard let price = station.pricePerLitre else { continue }
                let cd               = self.findOrCreateStation(station, in: ctx)
                let record           = FuelPriceRecordCD(context: ctx)
                record.id            = UUID()
                record.pricePerLitre = price
                record.fuelType      = station.fuelType
                record.recordedAt    = station.lastUpdated ?? Date()
                record.source        = station.priceSource.rawValue
                record.station       = cd
            }
            try? ctx.save()
        }
    }

    @discardableResult
    private func findOrCreateStation(_ station: FuelStation,
                                      in ctx: NSManagedObjectContext) -> FuelStationCD {
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
