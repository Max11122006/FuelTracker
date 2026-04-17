import Foundation

struct UserSettings {
    var carMPG: Double
    var fillUpLitres: Double        // litres needed to fill the tank (derived from gauge level)
    var essoDiscountPence: Double
    var homePostcode: String
    var uniLocation: String

    init(
        carMPG: Double            = Config.defaultMPG,
        fillUpLitres: Double      = Config.hondaCivicTankLitres * (1.0 - Config.defaultFuelGaugeLevel),
        essoDiscountPence: Double = Config.defaultEssoDiscount,
        homePostcode: String      = Config.defaultHomePostcode,
        uniLocation: String       = Config.defaultUniLocation
    ) {
        self.carMPG            = carMPG
        self.fillUpLitres      = fillUpLitres
        self.essoDiscountPence = essoDiscountPence
        self.homePostcode      = homePostcode
        self.uniLocation       = uniLocation
    }
}
