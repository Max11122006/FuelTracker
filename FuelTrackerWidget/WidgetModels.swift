import WidgetKit
import Foundation

/// A snapshot of all data needed to render the commute widget at a given moment.
/// Built synchronously from `AppGroupStore` — no async calls allowed in a widget provider.
struct CommuteEntry: TimelineEntry {
    let date: Date

    // Nearest Esso (with card)
    let essoName: String
    let essoStickerPricePence: Double
    let essoDiscountPence: Double
    let essoDistanceMiles: Double

    // Best alternative found along / near the commute route
    let altName: String
    let altPricePence: Double
    let altIsWorthIt: Bool
    let altNetSavingPence: Double  // positive = saving

    // Meta
    let lastUpdated: Date?
    let hasData: Bool

    // MARK: - Derived

    var essoEffectivePricePence: Double { essoStickerPricePence - essoDiscountPence }

    var formattedEssoPrice: String  { String(format: "%.1fp", essoEffectivePricePence) }
    var formattedAltPrice: String   { String(format: "%.1fp", altPricePence) }
    var formattedSaving: String {
        let pounds = abs(altNetSavingPence) / 100.0
        return altIsWorthIt
            ? String(format: "Save £%.2f", pounds)
            : String(format: "£%.2f extra", pounds)
    }

    var isStale: Bool {
        guard let ts = lastUpdated else { return true }
        return Date().timeIntervalSince(ts) > 4 * 3600
    }

    // MARK: - Factory

    static func fromStore() -> CommuteEntry {
        let hasData = AppGroupStore.nearestEssoStickerPrice > 0

        return CommuteEntry(
            date:                   Date(),
            essoName:               AppGroupStore.nearestEssoName,
            essoStickerPricePence:  AppGroupStore.nearestEssoStickerPrice,
            essoDiscountPence:      AppGroupStore.nearestEssoDiscountPence,
            essoDistanceMiles:      AppGroupStore.nearestEssoDistanceMiles,
            altName:                AppGroupStore.bestAltName,
            altPricePence:          AppGroupStore.bestAltPrice,
            altIsWorthIt:           AppGroupStore.bestAltIsWorthIt,
            altNetSavingPence:      AppGroupStore.bestAltNetSavingPence,
            lastUpdated:            AppGroupStore.lastUpdated,
            hasData:                hasData
        )
    }

    // MARK: - Placeholder (shown while widget loads)

    static var placeholder: CommuteEntry {
        CommuteEntry(
            date:                   Date(),
            essoName:               "Esso Edinburgh East",
            essoStickerPricePence:  148.9,
            essoDiscountPence:      10.0,
            essoDistanceMiles:      0.8,
            altName:                "Tesco Extra Petrol",
            altPricePence:          143.9,
            altIsWorthIt:           true,
            altNetSavingPence:      180,
            lastUpdated:            Date(),
            hasData:                true
        )
    }
}
