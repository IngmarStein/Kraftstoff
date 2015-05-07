//
//  NSManagedObject.swift
//  
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import Foundation
import CoreData

public class Car: NSManagedObject {

    @NSManaged public var timestamp: NSDate
    @NSManaged public var distanceTotalSum: NSDecimalNumber
    @NSManaged public var fuelUnit: Int32
    @NSManaged public var order: Int32
    @NSManaged public var fuelVolumeTotalSum: NSDecimalNumber
    @NSManaged public var odometer: NSDecimalNumber
    @NSManaged public var fuelConsumptionUnit: Int32
    @NSManaged public var odometerUnit: Int32
    @NSManaged public var name: String
    @NSManaged public var numberPlate: String
    @NSManaged public var fuelEvents: NSSet

	public var ksFuelUnit: KSVolume {
		get {
			return KSVolume(rawValue: fuelUnit)!
		}
		set {
			fuelUnit = newValue.rawValue
		}
	}

	public var ksFuelConsumptionUnit: KSFuelConsumption {
		get {
			return KSFuelConsumption(rawValue: fuelConsumptionUnit)!
		}
		set {
			fuelConsumptionUnit = newValue.rawValue
		}
	}

	public var ksOdometerUnit: KSDistance {
		get {
			return KSDistance(rawValue: odometerUnit)!
		}
		set {
			odometerUnit = newValue.rawValue
		}
	}
}
