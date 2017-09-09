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

final class FuelEvent: NSManagedObject, CloudKitManagedObject {

	var cloudKitRecordType: String? {
		return "FuelEvent"
	}

	var ksInheritedCost: Decimal {
		get {
			return inheritedCost! as Decimal
		}
		set {
			inheritedCost = newValue as NSDecimalNumber
		}
	}

	var ksDistance: Decimal {
		get {
			return distance! as Decimal
		}
		set {
			distance = newValue as NSDecimalNumber
		}
	}

	var ksPrice: Decimal {
		get {
			return price! as Decimal
		}
		set {
			price = newValue as NSDecimalNumber
		}
	}

	var ksInheritedDistance: Decimal {
		get {
			return inheritedDistance! as Decimal
		}
		set {
			inheritedDistance = newValue as NSDecimalNumber
		}
	}

	var ksInheritedFuelVolume: Decimal {
		get {
			return inheritedFuelVolume! as Decimal
		}
		set {
			inheritedFuelVolume = newValue as NSDecimalNumber
		}
	}

	var ksTimestamp: Date {
		get {
			return timestamp!
		}
		set {
			timestamp = newValue
		}
	}

	var ksFuelVolume: Decimal {
		get {
			return fuelVolume! as Decimal
		}
		set {
			fuelVolume = newValue as NSDecimalNumber
		}
	}

	var cost: Decimal {
		return ksFuelVolume * ksPrice
	}

	func asCloudKitRecord() -> CKRecord {
		guard let lastUpdate = lastUpdate else {
			fatalError("Required properties for record not set")
		}

		let record = CKRecord(recordType: cloudKitRecordType!, recordID: cloudKitRecordID)

		record["lastUpdate"] = lastUpdate as NSDate
		record["inheritedCost"] = inheritedCost
		record["distance"] = distance
		record["price"] = price
		record["inheritedDistance"] = inheritedDistance
		record["inheritedFuelVolume"] = inheritedFuelVolume
		record["timestamp"] = timestamp as NSDate?
		record["filledUp"] = NSNumber(value: filledUp)
		record["comment"] = comment as NSString?
		record["fuelVolume"] = fuelVolume
		if let car = car {
			record.parent = CKReference(recordID: car.cloudKitRecordID, action: .none)
		}

		return record
	}

	func updateFromRecord(_ record: CKRecord) {
		cloudKitRecordName = record.recordID.recordName
		lastUpdate = record["lastUpdate"] as? Date
		// swiftlint:disable force_cast
		inheritedCost = record["inheritedCost"] as? NSDecimalNumber
		distance = record["distance"] as? NSDecimalNumber
		price = record["price"] as? NSDecimalNumber
		inheritedDistance = record["inheritedDistance"] as? NSDecimalNumber
		inheritedFuelVolume = record["inheritedFuelVolume"] as? NSDecimalNumber
		timestamp = record["timestamp"] as? Date
		filledUp = record["filledUp"] as! Bool
		comment = record["comment"] as? String
		fuelVolume = record["fuelVolume"] as? NSDecimalNumber
		// swiftlint:enable force_cast

		if let parent = record.parent {
			let fetchRequest: NSFetchRequest<Car> = Car.fetchRequest()
			fetchRequest.predicate = NSPredicate(format: "cloudKitRecordName LIKE[c] %@", parent.recordID.recordName)

			let fetchResults = CoreDataManager.objectsForFetchRequest(fetchRequest)
			if fetchResults.count == 1 {
				car = fetchResults[0]
			} else {
				print("Unexpected number of cars: \(fetchResults)")
			}
		}
	}

}
