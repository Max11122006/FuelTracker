import Foundation

// Main-app-only constants. Not compiled into the widget extension.
enum Config {

    // MARK: - App Group

    static let appGroupIdentifier        = "group.com.maxd.FuelTracker"
    static let backgroundRefreshTaskID   = "com.maxd.FuelTracker.priceRefresh"

    // MARK: - Google Places API
    // Key is injected at build time from Secrets.xcconfig via the GOOGLE_PLACES_API_KEY
    // build setting, which is then written into Info.plist as $(GOOGLE_PLACES_API_KEY).

    static let googlePlacesAPIKey: String = {
        let key = Bundle.main.infoDictionary?["GOOGLE_PLACES_API_KEY"] as? String ?? ""
        if key.isEmpty || key.hasPrefix("YOUR_") {
            print("⚠️ FuelTracker: GOOGLE_PLACES_API_KEY not configured. " +
                  "Copy Secrets.xcconfig.template → Secrets.xcconfig and add your key.")
        }
        return key
    }()

    static var isPlacesAPIConfigured: Bool {
        !googlePlacesAPIKey.isEmpty && !googlePlacesAPIKey.hasPrefix("YOUR_")
    }

    // MARK: - API Endpoints

    static let placesNearbyBaseURL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
    static let placesDetailBaseURL = "https://maps.googleapis.com/maps/api/place/details/json"

    /// CMA-mandated Esso live price feed — free, no API key required.
    static let essoFeedURL = URL(string: "https://fuelprices.esso.co.uk/fuel_prices_data.json")!

    // MARK: - Commute route defaults

    static let defaultHomePostcode = "EH17 8LW"
    static let defaultUniLocation  = "Heriot-Watt University Edinburgh"

    // MARK: - User setting defaults

    static let defaultMPG: Double          = 35.0
    static let defaultFillLitres: Double   = 40.0
    static let defaultEssoDiscount: Double = 10.0  // pence per litre

    // MARK: - Staleness thresholds (hours)

    static let freshThresholdHours: Double = 1.0
    static let staleThresholdHours: Double = 4.0

    // MARK: - Map

    static let defaultSearchRadiusMetres: Double = 5000

    // MARK: - Pin colour thresholds (pence per litre above cheapest)

    static let greenThreshold: Double = 1.0   // within 1p of cheapest = green
    static let amberThreshold: Double = 3.0   // 1–3p above cheapest = amber
}
