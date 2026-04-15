import Foundation
import CoreData

@objc(FuelPriceRecordCD)
public class FuelPriceRecordCD: NSManagedObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FuelPriceRecordCD> {
        return NSFetchRequest<FuelPriceRecordCD>(entityName: "FuelPriceRecordCD")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var pricePerLitre: Double
    @NSManaged public var fuelType: String?
    @NSManaged public var recordedAt: Date?
    @NSManaged public var source: String?
    @NSManaged public var station: FuelStationCD?
}
