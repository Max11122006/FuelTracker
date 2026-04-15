import Foundation
import CoreLocation

@MainActor
final class StationsViewModel: ObservableObject {

    // MARK: - Published state

    @Published var results: [WorthItResult]     = []
    @Published var essoStation: FuelStation?
    @Published var loadingState: LoadingState   = .idle

    // MARK: - Dependencies

    let locationService = LocationService()
    private let priceService = FuelPriceService.shared

    // MARK: - Derived

    /// All stations for the map (Esso + alternatives).
    var allStationsForMap: [FuelStation] {
        var all = results.map(\.station)
        if let esso = essoStation { all.append(esso) }
        return all
    }

    var cheapestEffectivePrice: Double {
        results.first?.effectivePricePerLitre ?? 0
    }

    // MARK: - Refresh

    func refresh(settings: UserSettings) async {
        loadingState = .locating
        do {
            let location = try await locationService.requestCurrentLocation()
            loadingState = .fetchingPrices

            let (fresh, esso) = try await priceService.refreshPrices(
                for: location.coordinate,
                settings: settings
            )
            results      = fresh
            essoStation  = esso
            loadingState = .loaded(Date())
        } catch {
            loadingState = .error(error.localizedDescription)
        }
    }

    // MARK: - Manual price entry

    func saveManualPrice(for station: FuelStation, price: Double) {
        priceService.saveManualPrice(for: station, price: price)
    }

    // MARK: - LoadingState

    enum LoadingState: Equatable {
        case idle
        case locating
        case fetchingPrices
        case loaded(Date)
        case error(String)

        var isLoading: Bool {
            switch self { case .locating, .fetchingPrices: return true; default: return false }
        }

        var statusText: String {
            switch self {
            case .idle:          return "Pull down to refresh"
            case .locating:      return "Getting your location…"
            case .fetchingPrices: return "Fetching prices…"
            case .loaded(let d):
                let fmt = RelativeDateTimeFormatter()
                fmt.unitsStyle = .abbreviated
                return "Updated \(fmt.localizedString(for: d, relativeTo: Date()))"
            case .error(let msg): return "Error: \(msg)"
            }
        }

        static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.locating, .locating), (.fetchingPrices, .fetchingPrices):
                return true
            case (.loaded(let a), .loaded(let b)):
                return a == b
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }
}
