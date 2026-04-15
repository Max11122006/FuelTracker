import Foundation
import CoreLocation

// Shared between the main app and the widget extension.
// Both targets compile this file so it must not reference any app-only APIs.

private let kAppGroupIdentifier = "group.com.maxd.FuelTracker"

enum AppGroupStore {

    static let defaults: UserDefaults = {
        guard let ud = UserDefaults(suiteName: kAppGroupIdentifier) else {
            fatalError("App Group \(kAppGroupIdentifier) not configured. Register it in the Apple Developer portal and add it to both targets' entitlements.")
        }
        return ud
    }()

    // MARK: - Esso reference station

    static var nearestEssoStickerPrice: Double {
        get { defaults.double(forKey: Keys.nearestEssoStickerPrice) }
        set { defaults.set(newValue, forKey: Keys.nearestEssoStickerPrice) }
    }

    static var nearestEssoDiscountPence: Double {
        get { defaults.object(forKey: Keys.nearestEssoDiscountPence) as? Double ?? 10.0 }
        set { defaults.set(newValue, forKey: Keys.nearestEssoDiscountPence) }
    }

    static var nearestEssoEffectivePrice: Double {
        nearestEssoStickerPrice - nearestEssoDiscountPence
    }

    static var nearestEssoName: String {
        get { defaults.string(forKey: Keys.nearestEssoName) ?? "" }
        set { defaults.set(newValue, forKey: Keys.nearestEssoName) }
    }

    static var nearestEssoDistanceMiles: Double {
        get { defaults.double(forKey: Keys.nearestEssoDistanceMiles) }
        set { defaults.set(newValue, forKey: Keys.nearestEssoDistanceMiles) }
    }

    // MARK: - Best alternative station

    static var bestAltPrice: Double {
        get { defaults.double(forKey: Keys.bestAltPrice) }
        set { defaults.set(newValue, forKey: Keys.bestAltPrice) }
    }

    static var bestAltName: String {
        get { defaults.string(forKey: Keys.bestAltName) ?? "" }
        set { defaults.set(newValue, forKey: Keys.bestAltName) }
    }

    static var bestAltIsWorthIt: Bool {
        get { defaults.bool(forKey: Keys.bestAltIsWorthIt) }
        set { defaults.set(newValue, forKey: Keys.bestAltIsWorthIt) }
    }

    /// Net saving in pence (positive = saving, negative = extra cost).
    static var bestAltNetSavingPence: Double {
        get { defaults.double(forKey: Keys.bestAltNetSavingPence) }
        set { defaults.set(newValue, forKey: Keys.bestAltNetSavingPence) }
    }

    // MARK: - Timestamps

    static var lastUpdated: Date? {
        get {
            let ts = defaults.double(forKey: Keys.lastUpdated)
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Keys.lastUpdated)
        }
    }

    static var isStale: Bool {
        guard let ts = lastUpdated else { return true }
        return Date().timeIntervalSince(ts) > 4 * 3600
    }

    // MARK: - User settings (mirrored for widget)

    static var userMPG: Double {
        get { defaults.object(forKey: Keys.userMPG) as? Double ?? 35.0 }
        set { defaults.set(newValue, forKey: Keys.userMPG) }
    }

    static var userFillLitres: Double {
        get { defaults.object(forKey: Keys.userFillLitres) as? Double ?? 40.0 }
        set { defaults.set(newValue, forKey: Keys.userFillLitres) }
    }

    // MARK: - Last known location (for background refresh)

    static func saveCoordinate(_ coordinate: CLLocationCoordinate2D) {
        defaults.set(coordinate.latitude,  forKey: Keys.lastLat)
        defaults.set(coordinate.longitude, forKey: Keys.lastLon)
    }

    static var lastKnownCoordinate: CLLocationCoordinate2D? {
        let lat = defaults.double(forKey: Keys.lastLat)
        let lon = defaults.double(forKey: Keys.lastLon)
        guard lat != 0 || lon != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Keys

    enum Keys {
        static let nearestEssoStickerPrice  = "nearestEssoStickerPrice"
        static let nearestEssoDiscountPence = "nearestEssoDiscountPence"
        static let nearestEssoName          = "nearestEssoName"
        static let nearestEssoDistanceMiles = "nearestEssoDistanceMiles"
        static let bestAltPrice             = "bestAltPrice"
        static let bestAltName              = "bestAltName"
        static let bestAltIsWorthIt         = "bestAltIsWorthIt"
        static let bestAltNetSavingPence    = "bestAltNetSavingPence"
        static let lastUpdated              = "lastUpdated"
        static let userMPG                  = "userMPG"
        static let userFillLitres           = "userFillLitres"
        static let lastLat                  = "lastKnownLat"
        static let lastLon                  = "lastKnownLon"
    }
}
