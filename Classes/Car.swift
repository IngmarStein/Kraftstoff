//
//  Car.swift
//
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import Foundation
import CoreData

@objc(Car)
final class Car: NSManagedObject {

	var ksTimestamp: Date {
		get {
			return timestamp!
		}
		set {
			timestamp = newValue
		}
	}

	var ksDistanceTotalSum: Decimal {
		get {
			return distanceTotalSum! as Decimal
		}
		set {
			distanceTotalSum = newValue as NSDecimalNumber
		}
	}

	var ksFuelVolumeTotalSum: Decimal {
		get {
			return fuelVolumeTotalSum! as Decimal
		}
		set {
			fuelVolumeTotalSum = newValue as NSDecimalNumber
		}
	}

	var ksOdometer: Decimal {
		get {
			return odometer! as Decimal
		}
		set {
			odometer = newValue as NSDecimalNumber
		}
	}

	var ksName: String {
		return name!
	}

	var ksNumberPlate: String {
		return numberPlate!
	}

	var ksFuelEvents: Set<FuelEvent> {
		get {
			return fuelEvents as! Set<FuelEvent>
		}
		set {
			fuelEvents = newValue as NSSet
		}
	}

	var ksFuelUnit: UnitVolume {
		get {
			return .fromPersistentId(fuelUnit)
		}
		set {
			fuelUnit = newValue.persistentId
		}
	}

	var ksFuelConsumptionUnit: UnitFuelEfficiency {
		get {
			return .fromPersistentId(fuelConsumptionUnit)
		}
		set {
			fuelConsumptionUnit = newValue.persistentId
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
