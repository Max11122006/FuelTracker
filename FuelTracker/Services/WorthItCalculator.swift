import Foundation
import CoreLocation

/// Pure, stateless calculation engine. No network, no persistence, no side effects.
/// Fully unit-testable without any mocking.
enum WorthItCalculator {

    /// Imperial gallon in litres (UK standard).
    static let litresPerGallon: Double = 4.54609

    // MARK: - Worth-it calculation

    /// Returns a `WorthItResult` comparing `altStation` against the nearest Esso (with fuel card).
    ///
    /// - Parameters:
    ///   - essoStickerPricePence:   Esso pump price in pence/litre (before card discount).
    ///   - essoDiscountPence:       Fuel card discount in pence/litre (default 10p).
    ///   - altPricePence:           Price at the alternative station in pence/litre.
    ///   - distanceToEssoMiles:     Straight-line distance from user to nearest Esso (miles).
    ///   - distanceToAltMiles:      Straight-line distance from user to alt station (miles).
    ///   - mpg:                     Car fuel economy in miles per gallon (UK).
    ///   - fillLitres:              Typical fill-up volume in litres.
    ///   - station:                 The alternative `FuelStation` value.
    /// - Returns: `nil` if inputs are invalid (zero MPG / fill volume).
    static func calculate(
        essoStickerPricePence: Double,
        essoDiscountPence: Double,
        altPricePence: Double,
        distanceToEssoMiles: Double,
        distanceToAltMiles: Double,
        mpg: Double,
        fillLitres: Double,
        station: FuelStation
    ) -> WorthItResult? {
        guard mpg > 0, fillLitres > 0 else { return nil }

        let essoEffective     = essoStickerPricePence - essoDiscountPence
        let extraDistance     = max(0, distanceToAltMiles - distanceToEssoMiles)
        let litresPerMile     = litresPerGallon / mpg
        // Round-trip detour (go to alt, come back on original route) × 2
        let extraFuelLitres   = extraDistance * 2.0 * litresPerMile
        let extraFuelCost     = extraFuelLitres * essoEffective

        let savingsPerLitre   = essoEffective - altPricePence
        let grossSavings      = savingsPerLitre * fillLitres
        let netSavings        = grossSavings - extraFuelCost

        // Normalise detour cost back into a per-litre figure for sorting.
        let effectivePrice    = altPricePence + (extraFuelCost / fillLitres)

        return WorthItResult(
            id:                       station.id,
            station:                  station,
            essoEffectivePricePence:  essoEffective,
            altPricePence:            altPricePence,
            distanceToEssoMiles:      distanceToEssoMiles,
            distanceToAltMiles:       distanceToAltMiles,
            extraDistanceMiles:       extraDistance,
            extraFuelLitres:          extraFuelLitres,
            extraFuelCostPence:       extraFuelCost,
            grossSavingsPence:        grossSavings,
            netSavingsPence:          netSavings,
            effectivePricePerLitre:   effectivePrice,
            isWorthIt:                netSavings > 0
        )
    }

    // MARK: - Haversine distance

    /// Straight-line road approximation using the haversine formula.
    /// Used as a fast fallback when `MKDirections` is unavailable (e.g. widget context).
    static func haversineDistanceMiles(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let R = 3958.8  // Earth radius, miles
        let dLat = (to.latitude  - from.latitude)  * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(from.latitude * .pi / 180) * cos(to.latitude * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
