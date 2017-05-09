//
//  Car.swift
//
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import Foundation
import CoreData
import CloudKit

final class Car: NSManagedObject, CloudKitManagedObject {

	var cloudKitRecordType: String? {
		return "Car"
	}

	var ksTimestamp: Date {
		get {
			return timestamp! as Date
		}
		set {
			timestamp = newValue as NSDate
		}
	}

	var ksDistanceTotalSum: NSDecimalNumber {
		get {
			return distanceTotalSum!
		}
	}

	var ksFuelVolumeTotalSum: NSDecimalNumber {
		get {
			return fuelVolumeTotalSum!
		}
	}

	var ksOdometer: NSDecimalNumber {
		get {
			return odometer!
		}
	}

	var ksName: String {
		get {
			return name!
		}
	}

	var ksNumberPlate: String {
		get {
			return numberPlate!
		}
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

	func asCloudKitRecord() -> CKRecord {
		guard let lastUpdate = lastUpdate else {
			fatalError("Required properties for record not set")
		}

		let record = CKRecord(recordType: cloudKitRecordType!, recordID: cloudKitRecordID)

		record["lastUpdate"] = lastUpdate
		record["timestamp"] = timestamp
		record["distanceTotalSum"] = distanceTotalSum
		record["fuelUnit"] = NSNumber(value: fuelUnit)
		record["order"] = NSNumber(value: order)
		record["fuelVolumeTotalSum"] = fuelVolumeTotalSum
		record["odometer"] = odometer
		record["fuelConsumptionUnit"] = NSNumber(value: fuelConsumptionUnit)
		record["odometerUnit"] = NSNumber(value: odometerUnit)
		record["name"] = name as NSString?
		record["numberPlate"] = numberPlate as NSString?

		return record
	}

	func updateFromRecord(_ record: CKRecord) {
		cloudKitRecordName = record.recordID.recordName
		lastUpdate = record["lastUpdate"] as? NSDate
		// swiftlint:disable force_cast
		timestamp = record["timestamp"] as? NSDate
		distanceTotalSum = record["distanceTotalSum"] as? NSDecimalNumber
		fuelUnit = record["fuelUnit"] as! Int32
		order = record["order"] as! Int32
		fuelVolumeTotalSum = record["fuelVolumeTotalSum"] as? NSDecimalNumber
		odometer = record["odometer"] as? NSDecimalNumber
		fuelConsumptionUnit = record["fuelConsumptionUnit"] as! Int32
		odometerUnit = record["odometerUnit"] as! Int32
		name = record["name"] as? String
		numberPlate = record["numberPlate"] as? String
		// swiftlint:enable force_cast
	}

}
