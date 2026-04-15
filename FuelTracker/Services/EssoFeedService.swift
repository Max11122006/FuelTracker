import Foundation
import CoreLocation

/// Fetches live pump prices from the CMA-mandated Esso UK price feed.
/// No API key required. Prices are in pence per litre.
final class EssoFeedService {
    static let shared = EssoFeedService()
    private init() {}

    private var cache: [EssoStation]?
    private var cacheDate: Date?
    private let cacheTTL: TimeInterval = 3600  // 1 hour

    // MARK: - Public

    /// Fetches (or returns cached) Esso station list with live prices.
    func fetchStations() async throws -> [EssoStation] {
        if let cached = cache, let date = cacheDate,
           Date().timeIntervalSince(date) < cacheTTL {
            return cached
        }

        let (data, response) = try await URLSession.shared.data(from: Config.essoFeedURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return cache ?? []  // Return stale cache on network failure
        }

        // The CMA-mandated format uses snake_case keys; try multiple shapes for resilience.
        let stations = (try? decode(data)) ?? []
        cache     = stations
        cacheDate = Date()
        return stations
    }

    /// Returns the unleaded price in pence/litre for the Esso station nearest to `coordinate`,
    /// or `nil` if no Esso station is within 0.15 miles.
    func price(
        near coordinate: CLLocationCoordinate2D,
        fuelType: String = "unleaded"
    ) async -> Double? {
        guard let stations = try? await fetchStations() else { return nil }

        let nearest = stations.min {
            WorthItCalculator.haversineDistanceMiles(
                from: coordinate,
                to: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            ) <
            WorthItCalculator.haversineDistanceMiles(
                from: coordinate,
                to: CLLocationCoordinate2D(latitude: $1.latitude, longitude: $1.longitude)
            )
        }

        guard let match = nearest else { return nil }

        let dist = WorthItCalculator.haversineDistanceMiles(
            from: coordinate,
            to: CLLocationCoordinate2D(latitude: match.latitude, longitude: match.longitude)
        )
        guard dist < 0.15 else { return nil }

        return match.price(for: fuelType)
    }

    // MARK: - Decoding

    private func decode(_ data: Data) throws -> [EssoStation] {
        // Try the CMA standard shape first
        if let feed = try? JSONDecoder().decode(EssoFeedEnvelope.self, from: data) {
            return feed.stations
        }
        // Fall back to a bare array
        return try JSONDecoder().decode([EssoStation].self, from: data)
    }

    // MARK: - Models

    struct EssoFeedEnvelope: Decodable {
        let stations: [EssoStation]
        enum CodingKeys: String, CodingKey {
            case stations = "stations"
        }
    }

    struct EssoStation: Decodable {
        let siteId: String
        let postcode: String?
        let latitude: Double
        let longitude: Double
        let prices: EssoPrices

        enum CodingKeys: String, CodingKey {
            case siteId   = "site_id"
            case postcode = "postcode"
            case latitude, longitude, prices
        }

        func price(for fuelType: String) -> Double? {
            switch fuelType {
            case "unleaded": return prices.E10 ?? prices.B7
            case "diesel":   return prices.B7
            case "premium":  return prices.E5
            default:         return prices.E10 ?? prices.B7
            }
        }
    }

    /// CMA standard fuel type codes: E10 = standard petrol, B7 = diesel, E5 = premium petrol.
    struct EssoPrices: Decodable {
        let E10: Double?
        let E5:  Double?
        let B7:  Double?

        enum CodingKeys: String, CodingKey {
            case E10, E5, B7
        }
    }
}
