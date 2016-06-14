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

	var ksFuelUnit: KSVolume {
		get {
			return KSVolume(rawValue: fuelUnit)!
		}
		set {
			fuelUnit = newValue.rawValue
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

	var ksOdometerUnit: KSDistance {
		get {
			return KSDistance(rawValue: odometerUnit)!
		}
		set {
			odometerUnit = newValue.rawValue
		}
	}
}
