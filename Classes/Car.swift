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

	var cloudKitRecordID: CKRecordID {
		if cloudKitRecordName == nil {
			cloudKitRecordName = NSUUID().uuidString
		}
		return CKRecordID(recordName: cloudKitRecordName!)
	}

	func asCloudKitRecord() -> CKRecord {
		let record = CKRecord(recordType: "car", recordID: cloudKitRecordID)

		record["timestamp"] = timestamp
		record["distanceTotalSum"] = distanceTotalSum
		record["fuelUnit"] = Int(fuelUnit)
		record["order"] = Int(order)
		record["fuelVolumeTotalSum"] = fuelVolumeTotalSum
		record["odometer"] = odometer
		record["fuelConsumptionUnit"] = Int(fuelConsumptionUnit)
		record["odometerUnit"] = Int(odometerUnit)
		record["name"] = name
		record["numberPlate"] = numberPlate

		return record
	}

	func updateFromRecord(_ record: CKRecord) {
		cloudKitRecordName = record.recordID.recordName
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
	}
	
}
