import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject {

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: Error?

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate        = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus     = manager.authorizationStatus
    }

    // MARK: - Permission

    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationError = LocationError.permissionDenied
        default:
            break
        }
    }

    var hasPermission: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
        }
    }

    // MARK: - One-shot location request

    /// Returns the current location. Re-uses a recent fix (< 30 s) to avoid unnecessary radio use.
    func requestCurrentLocation() async throws -> CLLocation {
        if let existing = currentLocation,
           Date().timeIntervalSince(existing.timestamp) < 30 {
            return existing
        }
        if !hasPermission { requestPermission() }
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            manager.requestLocation()
        }
    }

    // MARK: - Errors

    enum LocationError: LocalizedError {
        case permissionDenied
        case locationUnavailable

        var errorDescription: String? {
            switch self {
            case .permissionDenied:    return "Location access denied. Enable it in Settings → Privacy → Location Services."
            case .locationUnavailable: return "Unable to get your current location. Please try again."
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if hasPermission { locationError = nil }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            currentLocation = location
            AppGroupStore.saveCoordinate(location.coordinate)
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            locationError = error
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
        }
    }
}
