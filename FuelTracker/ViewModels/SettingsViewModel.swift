import Foundation
import CoreData
import WidgetKit

@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var carMPG: Double
    @Published var fillUpLitres: Double
    @Published var essoDiscountPence: Double
    @Published var homePostcode: String
    @Published var uniLocation: String

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
        let cd = SettingsViewModel.fetchOrCreate(in: PersistenceController.shared.viewContext)
        carMPG            = cd.carMPG            > 0 ? cd.carMPG            : Config.defaultMPG
        fillUpLitres      = cd.fillUpLitres      > 0 ? cd.fillUpLitres      : Config.defaultFillLitres
        essoDiscountPence = cd.essoDiscountPence > 0 ? cd.essoDiscountPence : Config.defaultEssoDiscount
        homePostcode      = cd.homePostcode ?? Config.defaultHomePostcode
        uniLocation       = cd.uniLocation  ?? Config.defaultUniLocation
    }

    // MARK: - Save

    func save() {
        let ctx = persistence.newBackgroundContext()
        let mpg    = carMPG
        let fill   = fillUpLitres
        let disc   = essoDiscountPence
        let home   = homePostcode
        let uni    = uniLocation

        ctx.perform {
            let cd               = SettingsViewModel.fetchOrCreate(in: ctx)
            cd.carMPG            = mpg
            cd.fillUpLitres      = fill
            cd.essoDiscountPence = disc
            cd.homePostcode      = home
            cd.uniLocation       = uni
            try? ctx.save()
        }

        // Mirror to App Group so widget always has fresh settings
        AppGroupStore.userMPG          = carMPG
        AppGroupStore.userFillLitres   = fillUpLitres
        AppGroupStore.nearestEssoDiscountPence = essoDiscountPence

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - CoreData singleton

    @discardableResult
    static func fetchOrCreate(in ctx: NSManagedObjectContext) -> UserSettingsCD {
        let req        = UserSettingsCD.fetchRequest()
        req.fetchLimit = 1
        if let existing = try? ctx.fetch(req).first { return existing }

        let cd               = UserSettingsCD(context: ctx)
        cd.carMPG            = Config.defaultMPG
        cd.fillUpLitres      = Config.defaultFillLitres
        cd.essoDiscountPence = Config.defaultEssoDiscount
        cd.homePostcode      = Config.defaultHomePostcode
        cd.uniLocation       = Config.defaultUniLocation
        return cd
    }
}
