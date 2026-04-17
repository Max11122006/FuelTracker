import Foundation

// Main-app-only constants. Not compiled into the widget extension.
enum Config {

    // MARK: - App Group

    static let appGroupIdentifier      = "group.com.maxd.FuelTracker"
    static let backgroundRefreshTaskID = "com.maxd.FuelTracker.priceRefresh"

    // MARK: - UK Government Fuel Finder API
    // Credentials are stored in Keychain (via KeychainService), never in source code.
    // Enter them in Settings → Fuel Finder API after first launch.
    //
    // Developer portal: https://developer.fuel-finder.service.gov.uk
    // GOV.UK guidance:  https://www.gov.uk/guidance/access-the-latest-fuel-prices-and-forecourt-data-via-api-or-email

    static let fuelFinderBaseURL      = "https://www.fuel-finder.service.gov.uk"
    static let fuelFinderTokenPath    = "/api/v1/oauth/generate_access_token"
    static let fuelFinderStationsPath = "/api/v1/pfs"
    static let fuelFinderPricesPath   = "/api/v1/pfs/fuel-prices"

    // MARK: - Commute route defaults (empty → user prompted to fill in Settings)

    static let defaultHomePostcode = ""
    static let defaultUniLocation  = ""

    // MARK: - User setting defaults

    static let defaultMPG: Double          = 35.0
    static let defaultEssoDiscount: Double = 10.0  // pence per litre

    // MARK: - Fuel gauge (2006 Honda Civic petrol — 50 L tank)

    static let hondaCivicTankLitres: Double   = 50.0
    static let defaultFuelGaugeLevel: Double  = 0.5   // half tank on first launch

    // MARK: - Staleness thresholds (hours)

    static let freshThresholdHours: Double = 1.0
    static let staleThresholdHours: Double = 4.0

    // MARK: - Map

    static let defaultSearchRadiusMiles: Double = 10.0

    // MARK: - Pin colour thresholds (pence per litre above cheapest)

    static let greenThreshold: Double = 1.0   // within 1p of cheapest = green
    static let amberThreshold: Double = 3.0   // 1–3p above cheapest = amber
}
