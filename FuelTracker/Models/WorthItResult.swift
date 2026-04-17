import Foundation
import SwiftUI

struct WorthItResult: Identifiable, Equatable {
    let id: String              // station.id

    let station: FuelStation

    // Volume (stored so views can show fill-up cost without needing settings)
    let fillLitres: Double

    // Prices in pence per litre
    let essoEffectivePricePence: Double     // sticker − discount
    let altPricePence: Double               // raw price at this station

    // Distance
    let distanceToEssoMiles: Double
    let distanceToAltMiles: Double
    let extraDistanceMiles: Double          // max(0, alt − esso)

    // Extra cost of detour
    let extraFuelLitres: Double
    let extraFuelCostPence: Double

    // Savings
    let grossSavingsPence: Double
    let netSavingsPence: Double             // positive = saving, negative = extra cost

    // For list sorting — comparable pence/litre including detour cost
    let effectivePricePerLitre: Double

    let isWorthIt: Bool

    // MARK: - Fill-up costs

    var fillUpCostPounds: Double     { altPricePence           * fillLitres / 100.0 }
    var essoFillUpCostPounds: Double { essoEffectivePricePence * fillLitres / 100.0 }

    // MARK: - Formatted strings

    var formattedStickerPrice: String {
        String(format: "%.1fp", altPricePence)
    }

    var formattedEffectivePrice: String {
        String(format: "%.1fp", effectivePricePerLitre)
    }

    var formattedFillUpCost: String {
        String(format: "£%.2f", fillUpCostPounds)
    }

    var formattedEssoFillUpCost: String {
        String(format: "£%.2f", essoFillUpCostPounds)
    }

    var formattedFillVolume: String {
        String(format: "%.0f L", fillLitres)
    }

    var formattedDistance: String {
        distanceToAltMiles < 0.1
            ? "< 0.1 mi"
            : String(format: "%.1f mi", distanceToAltMiles)
    }

    var formattedExtraDistance: String {
        extraDistanceMiles < 0.1
            ? "no detour"
            : String(format: "%.1f mi further", extraDistanceMiles)
    }

    var formattedExtraFuelCost: String {
        extraFuelCostPence < 0.5
            ? "no detour cost"
            : String(format: "£%.2f detour fuel", extraFuelCostPence / 100.0)
    }

    var formattedGrossSaving: String {
        String(format: "£%.2f", abs(grossSavingsPence) / 100.0)
    }

    var formattedNetSaving: String {
        let pounds = abs(netSavingsPence) / 100.0
        return isWorthIt
            ? String(format: "Save £%.2f", pounds)
            : String(format: "£%.2f extra", pounds)
    }

    // MARK: - Pin colour

    enum PinColour { case green, amber, red }

    func pinColour(cheapestEffectivePrice: Double) -> PinColour {
        let diff = effectivePricePerLitre - cheapestEffectivePrice
        if diff <= Config.greenThreshold { return .green }
        if diff <= Config.amberThreshold { return .amber }
        return .red
    }

    var pinColor: Color {
        // Convenience — caller may not know the cheapest; used when creating
        // annotations from inside a view that has the full result set.
        .gray
    }
}

extension WorthItResult.PinColour {
    var color: Color {
        switch self {
        case .green: return Color("PinGreen")
        case .amber: return Color("PinAmber")
        case .red:   return Color("PinRed")
        }
    }
}
