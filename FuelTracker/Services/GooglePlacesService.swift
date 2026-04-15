import Foundation
import CoreLocation

final class GooglePlacesService {
    static let shared = GooglePlacesService()
    private init() {}

    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    // MARK: - Nearby gas stations

    func fetchNearbyStations(coordinate: CLLocationCoordinate2D) async throws -> [FuelStation] {
        guard Config.isPlacesAPIConfigured else {
            return []  // Graceful no-op — user falls back to manual price entry
        }

        var components = URLComponents(string: Config.placesNearbyBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "location", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "rankby",   value: "distance"),   // nearest-first; incompatible with radius
            URLQueryItem(name: "type",     value: "gas_station"),
            URLQueryItem(name: "key",      value: Config.googlePlacesAPIKey)
        ]

        guard let url = components.url else { throw PlacesError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PlacesError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let body = try decoder.decode(PlacesNearbyResponse.self, from: data)

        switch body.status {
        case "OK", "ZERO_RESULTS":
            break
        case "REQUEST_DENIED":
            throw PlacesError.apiError("REQUEST_DENIED — check your API key and that the Places API is enabled.")
        default:
            throw PlacesError.apiError(body.status)
        }

        return body.results.map { result in
            FuelStation(
                id:          result.placeID,
                name:        result.name,
                brand:       nil,
                coordinate:  CLLocationCoordinate2D(
                    latitude:  result.geometry.location.lat,
                    longitude: result.geometry.location.lng
                ),
                address:     result.vicinity
            )
        }
    }

    // MARK: - Response models

    private struct PlacesNearbyResponse: Decodable {
        let results: [PlaceResult]
        let status: String
        enum CodingKeys: String, CodingKey {
            case results, status
        }
    }

    private struct PlaceResult: Decodable {
        let placeID: String
        let name: String
        let vicinity: String?
        let geometry: PlaceGeometry
        enum CodingKeys: String, CodingKey {
            case placeID = "place_id"
            case name, vicinity, geometry
        }
    }

    private struct PlaceGeometry: Decodable {
        let location: PlaceLatLng
    }

    private struct PlaceLatLng: Decodable {
        let lat: Double
        let lng: Double
    }

    // MARK: - Errors

    enum PlacesError: LocalizedError {
        case invalidURL
        case httpError(Int)
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:           return "Invalid Places API URL."
            case .httpError(let code):  return "Places API HTTP error \(code)."
            case .apiError(let status): return "Places API error: \(status)."
            }
        }
    }
}
