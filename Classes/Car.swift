//
//  NSManagedObject.swift
//  
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import Foundation
import CoreData

class Car: NSManagedObject {

    @NSManaged var timestamp: NSDate
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
		return KSVolume(rawValue: Int(fuelUnit))!
	}

	var ksFuelConsumptionUnit: KSFuelConsumption {
		return KSFuelConsumption(rawValue: Int(fuelConsumptionUnit))!
	}

	var ksOdometerUnit: KSDistance {
		return KSDistance(rawValue: Int(odometerUnit))!
	}
}
