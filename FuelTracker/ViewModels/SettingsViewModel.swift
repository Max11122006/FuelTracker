import Foundation
import CoreData
import WidgetKit

@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var carMPG: Double
    /// Current gauge level: 0.0 = empty, 1.0 = full. Drives fillUpLitres.
    @Published var fuelGaugeLevel: Double
    @Published var essoDiscountPence: Double
    @Published var homePostcode: String
    @Published var uniLocation: String

    /// Fuel Finder API credentials — written to Keychain on Save, never persisted elsewhere.
    /// Fields are blank when first launched; populated from Keychain on init if already stored.
    @Published var fuelFinderClientID: String     = ""
    @Published var fuelFinderClientSecret: String = ""

    /// Computed from gauge level: how many litres it takes to fill the Honda Civic to full.
    var fillUpLitres: Double {
        Config.hondaCivicTankLitres * (1.0 - fuelGaugeLevel)
    }

    var credentialsConfigured: Bool {
        KeychainService.shared.hasCredentials
    }

    private let persistence = PersistenceController.shared

    var currentSettings: UserSettings {
        UserSettings(
            carMPG:            carMPG,
            fillUpLitres:      fillUpLitres,
            essoDiscountPence: essoDiscountPence,
            homePostcode:      homePostcode,
            uniLocation:       uniLocation
        )
    }

    init() {
        let cd = fetchOrCreateSettings(in: PersistenceController.shared.viewContext)
        carMPG            = cd.carMPG            > 0 ? cd.carMPG            : Config.defaultMPG
        fuelGaugeLevel    = cd.fuelGaugeLevel > 0 ? cd.fuelGaugeLevel : Config.defaultFuelGaugeLevel
        essoDiscountPence = cd.essoDiscountPence > 0 ? cd.essoDiscountPence : Config.defaultEssoDiscount
        homePostcode      = cd.homePostcode ?? Config.defaultHomePostcode
        uniLocation       = cd.uniLocation  ?? Config.defaultUniLocation
        // Credential fields remain blank — we don't pre-fill from Keychain so the
        // user can't accidentally see/copy saved secrets. The badge shows status.
    }

    // MARK: - Save

    func save() {
        let ctx   = persistence.newBackgroundContext()
        let mpg   = carMPG
        let gauge = fuelGaugeLevel
        let disc  = essoDiscountPence
        let home  = homePostcode
        let uni   = uniLocation

        ctx.perform {
            let cd               = fetchOrCreateSettings(in: ctx)
            cd.carMPG            = mpg
            cd.fuelGaugeLevel    = gauge
            cd.essoDiscountPence = disc
            cd.homePostcode      = home
            cd.uniLocation       = uni
            try? ctx.save()
        }

        // Save credentials to Keychain if the user typed something in.
        let id     = fuelFinderClientID.trimmingCharacters(in: .whitespaces)
        let secret = fuelFinderClientSecret.trimmingCharacters(in: .whitespaces)
        if !id.isEmpty && !secret.isEmpty {
            KeychainService.shared.save(clientID: id, clientSecret: secret)
            // Clear fields after save — don't leave secrets in @Published state.
            fuelFinderClientID     = ""
            fuelFinderClientSecret = ""
        }

        // Mirror to App Group so widget always has fresh settings.
        AppGroupStore.userMPG                  = carMPG
        AppGroupStore.userFillLitres           = fillUpLitres   // computed from gauge
        AppGroupStore.nearestEssoDiscountPence = essoDiscountPence

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Clear credentials

    func clearCredentials() {
        KeychainService.shared.deleteCredentials()
        fuelFinderClientID     = ""
        fuelFinderClientSecret = ""
    }
}

// MARK: - CoreData helper (file-private, no actor isolation)

@discardableResult
func fetchOrCreateSettings(in ctx: NSManagedObjectContext) -> UserSettingsCD {
    let req        = UserSettingsCD.fetchRequest()
    req.fetchLimit = 1
    if let existing = try? ctx.fetch(req).first { return existing }

    let cd               = UserSettingsCD(context: ctx)
    cd.carMPG            = Config.defaultMPG
    cd.fuelGaugeLevel    = Config.defaultFuelGaugeLevel
    cd.essoDiscountPence = Config.defaultEssoDiscount
    cd.homePostcode      = Config.defaultHomePostcode
    cd.uniLocation       = Config.defaultUniLocation
    return cd
}
