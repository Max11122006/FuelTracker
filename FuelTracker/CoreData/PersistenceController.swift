import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FuelTracker")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Place the store in the App Group container so the widget can read it if needed.
            // Primary widget data path is UserDefaults (AppGroupStore), but keeping the
            // SQLite file in the shared container is good hygiene.
            if let groupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Config.appGroupIdentifier
            ) {
                let storeURL = groupURL.appendingPathComponent("FuelTracker.sqlite")
                container.persistentStoreDescriptions.first?.url = storeURL
            }
        }

        container.loadPersistentStores { _, error in
            if let error {
                // In production you'd handle migration errors gracefully.
                fatalError("CoreData load failed: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }

    // MARK: - Preview helper

    static var preview: PersistenceController = {
        let c = PersistenceController(inMemory: true)
        let ctx = c.viewContext

        let station = FuelStationCD(context: ctx)
        station.placeID = "ChIJpreview001"
        station.name = "Esso Edinburgh East"
        station.brand = "Esso"
        station.latitude = 55.9376
        station.longitude = -3.0985
        station.address = "123 Gilmerton Road, Edinburgh"

        let price = FuelPriceRecordCD(context: ctx)
        price.id = UUID()
        price.pricePerLitre = 148.9
        price.fuelType = "unleaded"
        price.recordedAt = Date()
        price.source = "essoFeed"
        price.station = station

        let station2 = FuelStationCD(context: ctx)
        station2.placeID = "ChIJpreview002"
        station2.name = "Tesco Extra Petrol"
        station2.latitude = 55.9321
        station2.longitude = -3.1050
        station2.address = "Straiton, Edinburgh"

        let price2 = FuelPriceRecordCD(context: ctx)
        price2.id = UUID()
        price2.pricePerLitre = 143.9
        price2.fuelType = "unleaded"
        price2.recordedAt = Date()
        price2.source = "manual"
        price2.station = station2

        try? ctx.save()
        return c
    }()
}
