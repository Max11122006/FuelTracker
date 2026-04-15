import Foundation
import CoreLocation

struct FuelStation: Identifiable, Equatable {
    let id: String                  // Google Place ID (stable)
    let name: String
    let brand: String?
    let coordinate: CLLocationCoordinate2D
    let address: String?

    var pricePerLitre: Double?      // pence per litre, nil if unknown
    var fuelType: String            = "unleaded"
    var lastUpdated: Date?
    var priceSource: PriceSource    = .unknown

    // MARK: - Computed

    var isEsso: Bool {
        name.localizedCaseInsensitiveContains("esso") ||
        brand?.localizedCaseInsensitiveContains("esso") == true
    }

    var ageHours: Double? {
        guard let updated = lastUpdated else { return nil }
        return Date().timeIntervalSince(updated) / 3600
    }

    var isStale: Bool {
        guard let hours = ageHours else { return true }
        return hours > Config.staleThresholdHours
    }

    // MARK: - Price source

    enum PriceSource: String {
        case essoFeed    = "essoFeed"
        case manual      = "manual"
        case unknown     = "unknown"
    }

    // MARK: - Equatable (by Place ID)

    static func == (lhs: FuelStation, rhs: FuelStation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - CoreData hydration

extension FuelStation {
    /// Build a FuelStation from a CoreData entity + its latest price record.
    init?(from cd: FuelStationCD) {
        guard let placeID = cd.placeID, let name = cd.name else { return nil }
        self.id         = placeID
        self.name       = name
        self.brand      = cd.brand
        self.coordinate = CLLocationCoordinate2D(latitude: cd.latitude, longitude: cd.longitude)
        self.address    = cd.address

        if let latest = cd.latestPrice() {
            self.pricePerLitre = latest.pricePerLitre
            self.fuelType      = latest.fuelType ?? "unleaded"
            self.lastUpdated   = latest.recordedAt
            self.priceSource   = PriceSource(rawValue: latest.source ?? "") ?? .unknown
        }
    }
}
