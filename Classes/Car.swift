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

	@NSManaged var cloudKitRecordName: String?
	@NSManaged var lastUpdate: Date?
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
	@NSManaged var fuelEvents: Set<FuelEvent>

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

	var cloudKitRecordID: CKRecordID {
		if cloudKitRecordName == nil {
			cloudKitRecordName = NSUUID().uuidString
		}
		return CKRecordID(recordName: cloudKitRecordName!)
	}

	func asCloudKitRecord() -> CKRecord {
		guard let lastUpdate = lastUpdate else {
			fatalError("Required properties for record not set")
		}

		let record = CKRecord(recordType: "car", recordID: cloudKitRecordID)

		record["lastUpdate"] = lastUpdate as NSDate
		record["timestamp"] = timestamp as NSDate
		record["distanceTotalSum"] = distanceTotalSum
		record["fuelUnit"] = NSNumber(value: fuelUnit)
		record["order"] = NSNumber(value: order)
		record["fuelVolumeTotalSum"] = fuelVolumeTotalSum
		record["odometer"] = odometer
		record["fuelConsumptionUnit"] = NSNumber(value: fuelConsumptionUnit)
		record["odometerUnit"] = NSNumber(value: odometerUnit)
		record["name"] = name as NSString
		record["numberPlate"] = numberPlate as NSString

		return record
	}

	func updateFromRecord(_ record: CKRecord) {
		cloudKitRecordName = record.recordID.recordName
		lastUpdate = record["lastUpdate"] as? Date
		// swiftlint:disable force_cast
		timestamp = record["timestamp"] as! Date
		distanceTotalSum = record["distanceTotalSum"] as! NSDecimalNumber
		fuelUnit = record["fuelUnit"] as! Int32
		order = record["order"] as! Int32
		fuelVolumeTotalSum = record["fuelVolumeTotalSum"] as! NSDecimalNumber
		odometer = record["odometer"] as! NSDecimalNumber
		fuelConsumptionUnit = record["fuelConsumptionUnit"] as! Int32
		odometerUnit = record["odometerUnit"] as! Int32
		name = record["name"] as! String
		numberPlate = record["numberPlate"] as! String
		// swiftlint:enable force_cast
	}

}
