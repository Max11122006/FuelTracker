import Foundation
import CoreData

@objc(FuelStationCD)
public class FuelStationCD: NSManagedObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FuelStationCD> {
        return NSFetchRequest<FuelStationCD>(entityName: "FuelStationCD")
    }

    @NSManaged public var placeID: String?
    @NSManaged public var name: String?
    @NSManaged public var brand: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var address: String?
    @NSManaged public var priceRecords: NSSet?
}

// MARK: - Relationship helpers (KVC-compliant accessors)
extension FuelStationCD {

    @objc(addPriceRecordsObject:)
    @NSManaged public func addToPriceRecords(_ value: FuelPriceRecordCD)

    @objc(removePriceRecordsObject:)
    @NSManaged public func removeFromPriceRecords(_ value: FuelPriceRecordCD)

    @objc(addPriceRecords:)
    @NSManaged public func addToPriceRecords(_ values: NSSet)

    @objc(removePriceRecords:)
    @NSManaged public func removeFromPriceRecords(_ values: NSSet)

    /// Returns price records sorted newest-first.
    var sortedPriceRecords: [FuelPriceRecordCD] {
        (priceRecords?.allObjects as? [FuelPriceRecordCD] ?? [])
            .sorted { ($0.recordedAt ?? .distantPast) > ($1.recordedAt ?? .distantPast) }
    }

    /// The most recently recorded price for a given fuel type.
    func latestPrice(fuelType: String = "unleaded") -> FuelPriceRecordCD? {
        sortedPriceRecords.first { $0.fuelType == fuelType }
    }
}
