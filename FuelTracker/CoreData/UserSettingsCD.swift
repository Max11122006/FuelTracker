import Foundation
import CoreData

@objc(UserSettingsCD)
public class UserSettingsCD: NSManagedObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserSettingsCD> {
        return NSFetchRequest<UserSettingsCD>(entityName: "UserSettingsCD")
    }

    @NSManaged public var carMPG: Double
    @NSManaged public var fillUpLitres: Double
    @NSManaged public var essoDiscountPence: Double
    @NSManaged public var homePostcode: String?
    @NSManaged public var uniLocation: String?
}
