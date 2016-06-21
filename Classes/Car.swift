//
//  Car.swift
//
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import Foundation
import CoreData

final class Car: NSManagedObject {

	@NSManaged var cloudKitRecordName: String?
    @NSManaged var timestamp: Date
    @NSManaged var distanceTotalSum: NSDecimalNumber
    @NSManaged var fuelUnit: Int32
    @NSManaged var order: Int32
    @NSManaged var fuelVolumeTotalSum: NSDecimalNumber
    @NSManaged var odometer: NSDecimalNumber
    @NSManaged var fuelConsumptionUnit: Int32
    @NSManaged var odometerUnit: Int32
    @NSManaged var name: String
    @NSManaged var numberPlate: String
    @NSManaged var fuelEvents: NSSet

	@nonobjc class func fetchRequest() -> NSFetchRequest<Car> {
		return NSFetchRequest<Car>(entityName: "car")
	}

	var ksFuelUnit: UnitVolume {
		get {
			return .fromPersistentId(fuelUnit)
		}
		set {
			fuelUnit = newValue.persistentId
		}
	}

	var ksFuelConsumptionUnit: KSFuelConsumption {
		get {
			return KSFuelConsumption(rawValue: fuelConsumptionUnit)!
		}
		set {
			fuelConsumptionUnit = newValue.rawValue
		}
	}

	var ksOdometerUnit: UnitLength {
		get {
			return .fromPersistentId(odometerUnit)
		}
		set {
			odometerUnit = newValue.persistentId
		}
	}
}
