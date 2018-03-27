//
//  NSManagedObject.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import RealmSwift
import IceCream

final class FuelEvent: Object {

	@objc dynamic var id = UUID().uuidString
	@objc dynamic var isDeleted = false
	@objc dynamic var comment: String?
	@objc private dynamic var _distance = "0.0"
	@objc dynamic var filledUp = true
	@objc private dynamic var _fuelVolume = "0.0"
	@objc private dynamic var _inheritedCost = "0.0"
	@objc private dynamic var _inheritedDistance = "0.0"
	@objc private dynamic var _inheritedFuelVolume = "0.0"
	@objc private dynamic var _price = "0.0"
	@objc dynamic var timestamp = Date()

	// See https://github.com/realm/realm-cocoa/issues/3494 why this is a
	// bidirectional relationship: if we only keep the backlink to Car, every
	// change to the linked Car triggers modification notifications for all
	// fuel events stored for this car. When adding a new car, the order field
	// is updated and this might exceed the limit of 400 objects in a
	// CloudKit request.
	let cars = LinkingObjects(fromType: Car.self, property: "fuelEvents")

	var cost: Decimal {
		return fuelVolume * price
	}

	var distance: Decimal {
		get { return Decimal(string: _distance)! }
		set { _distance = String(describing: newValue) }
	}

	var fuelVolume: Decimal {
		get { return Decimal(string: _fuelVolume)! }
		set { _fuelVolume = String(describing: newValue) }
	}

	var inheritedCost: Decimal {
		get { return Decimal(string: _inheritedCost)! }
		set { _inheritedCost = String(describing: newValue) }
	}

	var inheritedDistance: Decimal {
		get { return Decimal(string: _inheritedDistance)! }
		set { _inheritedDistance = String(describing: newValue) }
	}

	var inheritedFuelVolume: Decimal {
		get { return Decimal(string: _inheritedFuelVolume)! }
		set { _inheritedFuelVolume = String(describing: newValue) }
	}

	var price: Decimal {
		get { return Decimal(string: _price)! }
		set { _price = String(describing: newValue) }
	}

	override class func primaryKey() -> String? {
		return #keyPath(FuelEvent.id)
	}

	public override class func ignoredProperties() -> [String] {
		return [
			"cost",
			"distance",
			"fuelVolume",
			"inheritedCost",
			"inheritedDistance",
			"inheritedFuelVolume",
			"private"
		]
	}

	override static func indexedProperties() -> [String] {
		return ["timestamp"]
	}

}

extension FuelEvent: CKRecordConvertible {
}

extension FuelEvent: CKRecordRecoverable {
}
