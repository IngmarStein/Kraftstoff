//
//  NSManagedObject.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import Foundation
import CoreData
import CloudKit

final class FuelEvent: NSManagedObject {

	@NSManaged var cloudKitRecordName: String?
    @NSManaged var inheritedCost: NSDecimalNumber
    @NSManaged var distance: NSDecimalNumber
    @NSManaged var price: NSDecimalNumber
    @NSManaged var inheritedDistance: NSDecimalNumber
    @NSManaged var inheritedFuelVolume: NSDecimalNumber
    @NSManaged var timestamp: Date
    @NSManaged var filledUp: Bool
	@NSManaged var comment: String?
    @NSManaged var fuelVolume: NSDecimalNumber
    @NSManaged var car: Car

	@nonobjc class func fetchRequest() -> NSFetchRequest<FuelEvent> {
		return NSFetchRequest<FuelEvent>(entityName: "fuelEvent")
	}

	var cost: NSDecimalNumber {
		return fuelVolume * price
	}

	func asCloudKitRecord() -> CKRecord {
		let record = CKRecord(recordType: "fuelEvent")

		record["inheritedCost"] = inheritedCost
		record["distance"] = distance
		record["price"] = price
		record["inheritedDistance"] = inheritedDistance
		record["inheritedFuelVolume"] = inheritedFuelVolume
		record["timestamp"] = timestamp
		record["filledUp"] = filledUp
		record["comment"] = comment
		record["fuelVolume"] = fuelVolume

		return record
	}

	func updateFromRecord(record: CKRecord) {
		cloudKitRecordName = record.recordID.recordName
		inheritedCost = record["inheritedCost"] as! NSDecimalNumber
		distance = record["distance"] as! NSDecimalNumber
		price = record["price"] as! NSDecimalNumber
		inheritedDistance = record["inheritedDistance"] as! NSDecimalNumber
		inheritedFuelVolume = record["inheritedFuelVolume"] as! NSDecimalNumber
		timestamp = record["timestamp"] as! Date
		filledUp = record["filledUp"] as! Bool
		comment = record["comment"] as? String
		fuelVolume = record["fuelVolume"] as! NSDecimalNumber
	}
	
}
