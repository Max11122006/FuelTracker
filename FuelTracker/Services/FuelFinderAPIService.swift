import Foundation
import CoreLocation

/// Client for the UK Government Fuel Finder API.
///
/// Data strategy:
/// - Station metadata  → in-memory cache, TTL 24 h  (paginated via batch-number)
/// - Fuel prices       → in-memory cache, TTL 15 min (paginated via batch-number)
/// - OAuth token       → in-memory cache, refreshed 60 s before expiry
///
/// On first launch a full sync is performed (station list + prices).
/// Subsequent calls return cached data immediately; background refresh keeps prices fresh.
final class FuelFinderAPIService {
    static let shared = FuelFinderAPIService()
    private init() {}

    // MARK: - Configuration (see Config.swift)

    private var baseURL: URL { URL(string: Config.fuelFinderBaseURL)! }

    // MARK: - OAuth token cache

    private var cachedToken: String?
    private var tokenExpiry: Date = .distantPast

    // MARK: - Data caches

    /// node_id → station metadata (only stations within fetchRadiusMiles of last fetch coordinate)
    private var stationCache: [String: FFStation]?
    private var stationCacheDate: Date = .distantPast
    private var stationCacheCenter: CLLocationCoordinate2D?

    /// node_id → array of price records (one per fuel type, only for cached stations)
    private var priceCache: [String: [FFPrice]]?
    private var priceCacheDate: Date = .distantPast

    private let stationCacheTTL:   TimeInterval = 24 * 3600  // 24 h
    private let priceCacheTTL:     TimeInterval = 15 * 60    // 15 min
    /// Generous radius used when downloading — larger than the display radius so nearby
    /// stations are in cache even after a short drive.
    private let fetchRadiusMiles:  Double       = 20.0
    /// If the user moves more than this from the cache centre, re-download stations.
    private let cacheInvalidationMiles: Double  = 5.0
    private let maxConcurrentBatches            = 6           // parallel batch requests

    // MARK: - Public API

    /// Returns all stations within `radiusMiles` of `coordinate`, with current prices attached.
    /// Throws `FuelFinderError.credentialsNotConfigured` if no credentials are stored in Keychain.
    func fetchNearbyStations(
        coordinate: CLLocationCoordinate2D,
        radiusMiles: Double = 5.0
    ) async throws -> [FuelStation] {
        let token = try await getToken()

        // Fetch stations first (needed to know which node_ids to keep in prices).
        let stations = try await getStations(token: token, near: coordinate)
        let knownIDs = Set(stations.keys)
        let prices   = try await getPrices(token: token, knownIDs: knownIDs)

        return stations.values
            .filter { station in
                let coord = CLLocationCoordinate2D(
                    latitude:  station.location.latitude,
                    longitude: station.location.longitude
                )
                return WorthItCalculator.haversineDistanceMiles(from: coordinate, to: coord) <= radiusMiles
            }
            .compactMap { makeFuelStation(from: $0, prices: prices[$0.node_id] ?? []) }
            .sorted {
                WorthItCalculator.haversineDistanceMiles(from: coordinate, to: $0.coordinate) <
                WorthItCalculator.haversineDistanceMiles(from: coordinate, to: $1.coordinate)
            }
    }

    /// Forces a full refresh of both caches (bypass TTL). Called by BGAppRefreshTask.
    func forceRefresh(near coordinate: CLLocationCoordinate2D) async throws {
        let token = try await getToken()
        stationCache      = nil
        priceCache        = nil
        stationCacheDate  = .distantPast
        priceCacheDate    = .distantPast
        stationCacheCenter = nil
            let s = try await getStations(token: token, near: coordinate)
        _ = try await getPrices(token: token, knownIDs: Set(s.keys))
    }

    // MARK: - Token management

    private func getToken() async throws -> String {
        if let token = cachedToken, Date() < tokenExpiry {
            return token
        }
        return try await fetchToken()
    }

    private func fetchToken() async throws -> String {
        guard let credentials = KeychainService.shared.loadCredentials() else {
            throw FuelFinderError.credentialsNotConfigured
        }

        let url = baseURL.appendingPathComponent(Config.fuelFinderTokenPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // OAuth 2.0 client credentials — RFC 6749 §4.4 requires form encoding, not JSON.
        let body = "grant_type=client_credentials"
            + "&client_id=\(credentials.clientID.urlEncoded)"
            + "&client_secret=\(credentials.clientSecret.urlEncoded)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        cachedToken = tokenResponse.data.access_token
        // Subtract 60 s buffer so we refresh before actual expiry
        tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.data.expires_in) - 60)
        return tokenResponse.data.access_token
    }

    // MARK: - Cached data access

    private func getStations(token: String,
                             near coordinate: CLLocationCoordinate2D) async throws -> [String: FFStation] {
        // Cache hit: still fresh AND user hasn't moved far from the cache centre.
        if let cache = stationCache,
           Date().timeIntervalSince(stationCacheDate) < stationCacheTTL,
           let centre = stationCacheCenter,
           WorthItCalculator.haversineDistanceMiles(from: coordinate, to: centre) < cacheInvalidationMiles {
            return cache
        }
        let fresh = try await fetchAllStations(token: token, near: coordinate)
        stationCache       = fresh
        stationCacheDate   = Date()
        stationCacheCenter = coordinate
        return fresh
    }

    private func getPrices(token: String,
                           knownIDs: Set<String>?) async throws -> [String: [FFPrice]] {
        if let cache = priceCache,
           Date().timeIntervalSince(priceCacheDate) < priceCacheTTL {
            return cache
        }
        // Use the incremental endpoint when we have a prior cache, merging the delta.
        if var existing = priceCache, priceCacheDate > .distantPast {
            let delta = try await fetchAllPrices(token: token, since: priceCacheDate, knownIDs: knownIDs)
            for (id, prices) in delta { existing[id] = prices }
            priceCache     = existing
            priceCacheDate = Date()
            return existing
        }
        let fresh = try await fetchAllPrices(token: token, knownIDs: knownIDs)
        priceCache     = fresh
        priceCacheDate = Date()
        return fresh
    }

    // MARK: - Paginated fetching

    private func fetchAllStations(token: String,
                                   near coordinate: CLLocationCoordinate2D) async throws -> [String: FFStation] {
        let box = BoundingBox(center: coordinate, radiusMiles: fetchRadiusMiles)
        return try await fetchAllBatches(
            token: token,
            path: Config.fuelFinderStationsPath,
            extraParams: []
        ) { (stations: [FFStation]) in
            let filtered = stations.filter { box.contains($0.location.latitude, $0.location.longitude) }
            return Dictionary(filtered.map { ($0.node_id, $0) }, uniquingKeysWith: { $1 })
        }
    }

    /// Fetches prices for stations we know about.  Pass `since` to use the incremental endpoint.
    private func fetchAllPrices(token: String,
                                since: Date? = nil,
                                knownIDs: Set<String>?) async throws -> [String: [FFPrice]] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        var extra: [URLQueryItem] = []
        if let since {
            extra.append(URLQueryItem(name: "effective-start-timestamp", value: iso.string(from: since)))
        }
        return try await fetchAllBatches(
            token: token,
            path: Config.fuelFinderPricesPath,
            extraParams: extra
        ) { (entries: [FFPriceEntry]) in
            var dict: [String: [FFPrice]] = [:]
            for entry in entries {
                // Skip price records for stations outside our area.
                if let ids = knownIDs, !ids.contains(entry.node_id) { continue }
                dict[entry.node_id] = entry.fuel_prices
            }
            return dict
        }
    }

    /// Generic concurrent paginator.
    /// Fetches batches in windows of `maxConcurrentBatches`. Stops when a batch returns HTTP 404.
    private func fetchAllBatches<Item: Decodable, Result>(
        token: String,
        path: String,
        extraParams: [URLQueryItem],
        merge: ([Item]) -> [String: Result]
    ) async throws -> [String: Result] {
        var combined: [String: Result] = [:]
        var nextBatch = 1
        var done = false

        while !done {
            // Launch a window of concurrent requests.
            let window = nextBatch ..< (nextBatch + maxConcurrentBatches)
            nextBatch += maxConcurrentBatches

            try await withThrowingTaskGroup(of: (Int, [Item]?).self) { group in
                for batch in window {
                    var components = URLComponents(
                        url: baseURL.appendingPathComponent(path),
                        resolvingAgainstBaseURL: false
                    )!
                    var items = [URLQueryItem(name: "batch-number", value: "\(batch)")]
                    items.append(contentsOf: extraParams)
                    components.queryItems = items
                    let url = components.url!

                    group.addTask {
                        do {
                            let items: [Item] = try await self.authorisedGET(url: url, token: token)
                            return (batch, items)
                        } catch FuelFinderError.httpError(404, _) {
                            return (batch, nil)   // nil = no more batches
                        }
                    }
                }

                for try await (_, items) in group {
                    if let items {
                        combined.merge(merge(items)) { $1 }
                    } else {
                        done = true
                    }
                }
            }
        }

        return combined
    }

    // MARK: - HTTP helper

    private func authorisedGET<T: Decodable>(url: URL, token: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw FuelFinderError.invalidResponse
        }
        switch http.statusCode {
        case 200...299: break
        case 401: throw FuelFinderError.unauthorised
        case 429: throw FuelFinderError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            throw FuelFinderError.httpError(http.statusCode, body)
        }
    }

    // MARK: - Model mapping

    /// Maps a Fuel Finder station + its price records to the app's `FuelStation` value type.
    private func makeFuelStation(from station: FFStation, prices: [FFPrice]) -> FuelStation? {
        guard !station.temporary_closure, station.permanent_closure != true else { return nil }
        // Exclude membership-only stations (Costco requires a paid membership to fill up).
        guard !station.brand_name.uppercased().contains("COSTCO") else { return nil }

        let coordinate = CLLocationCoordinate2D(
            latitude:  station.location.latitude,
            longitude: station.location.longitude
        )

        // Prefer E10 (standard unleaded) as the headline price
        let preferredOrder = ["E10", "E5", "B7_STANDARD", "SDV", "B10", "HVO"]
        let bestPrice = preferredOrder.compactMap { code -> FFPrice? in
            prices.first { $0.fuel_type == code }
        }.first

        // Build a human-readable name: "Brand, Postcode" e.g. "ESSO, EH17 8LW"
        let postcode = station.location.postcode ?? ""
        let name = postcode.isEmpty ? station.brand_name : "\(station.brand_name), \(postcode)"

        // Compose address from location fields
        let addressParts = [
            station.location.address_line_1,
            station.location.address_line_2,
            station.location.city
        ].compactMap { $0 }.filter { !$0.isEmpty }
        let address = addressParts.joined(separator: ", ")

        let lastUpdated: Date? = {
            guard let str = bestPrice?.price_last_updated else { return nil }
            return ISO8601DateFormatter().date(from: str)
        }()

        return FuelStation(
            id:            station.node_id,
            name:          name,
            brand:         station.brand_name,
            coordinate:    coordinate,
            address:       address,
            pricePerLitre: bestPrice?.price,
            fuelType:      fuelTypeDisplayName(bestPrice?.fuel_type ?? "E10"),
            lastUpdated:   lastUpdated,
            priceSource:   .fuelFinderAPI
        )
    }

    private func fuelTypeDisplayName(_ code: String) -> String {
        switch code {
        case "E10":        return "unleaded"
        case "E5":         return "premium"
        case "B7_STANDARD": return "diesel"
        case "SDV":        return "super diesel"
        case "B10":        return "B10 diesel"
        case "HVO":        return "HVO"
        default:           return code.lowercased()
        }
    }

    // MARK: - Errors

    enum FuelFinderError: LocalizedError {
        case credentialsNotConfigured
        case invalidResponse
        case unauthorised
        case rateLimited
        case httpError(Int, String)

        var errorDescription: String? {
            switch self {
            case .credentialsNotConfigured:
                return "Fuel Finder API credentials not set. Add your Client ID and Secret in Settings."
            case .invalidResponse:
                return "Invalid response from Fuel Finder API."
            case .unauthorised:
                return "Fuel Finder API credentials rejected (401). Check your Client ID and Secret in Settings."
            case .rateLimited:
                return "Fuel Finder API rate limit hit (429). Try again in a moment."
            case .httpError(let code, let body):
                return "Fuel Finder API error \(code): \(body)"
            }
        }
    }
}

// MARK: - OAuth response models
// Actual response: { "success": true, "data": { "access_token": "...", "expires_in": 3600, ... } }

private struct TokenResponse: Decodable {
    let data: TokenData

    struct TokenData: Decodable {
        let access_token: String
        let expires_in:   Int
    }
}

// MARK: - String helper for URL-encoding credential values

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

// MARK: - Fuel Finder response models

/// A single petrol filling station from GET /api/v1/pfs
struct FFStation: Decodable {
    let node_id:           String
    let brand_name:        String
    let trading_name:      String
    let temporary_closure: Bool
    let permanent_closure: Bool?
    let location:          FFLocation

    struct FFLocation: Decodable {
        let address_line_1: String?
        let address_line_2: String?
        let city:           String?
        let postcode:       String?
        let latitude:       Double
        let longitude:      Double
    }
}

/// One entry from GET /api/v1/pfs/fuel-prices — a station with nested prices
struct FFPriceEntry: Decodable {
    let node_id:     String
    let fuel_prices: [FFPrice]
}

/// A single price record nested inside FFPriceEntry
struct FFPrice: Decodable {
    let fuel_type:          String   // "E10", "E5", "B7_STANDARD", "SDV", "B10", "HVO"
    let price:              Double   // pence per litre, e.g. 153.9
    let price_last_updated: String?  // ISO8601 string
}

// MARK: - Geographic bounding box (rough pre-filter before haversine)

private struct BoundingBox {
    let minLat, maxLat, minLon, maxLon: Double

    init(center: CLLocationCoordinate2D, radiusMiles: Double) {
        let deltaLat = radiusMiles / 69.0
        let deltaLon = radiusMiles / (69.0 * cos(center.latitude * .pi / 180))
        minLat = center.latitude  - deltaLat
        maxLat = center.latitude  + deltaLat
        minLon = center.longitude - deltaLon
        maxLon = center.longitude + deltaLon
    }

    func contains(_ lat: Double, _ lon: Double) -> Bool {
        lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon
    }
}
