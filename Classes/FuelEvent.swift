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
	@objc dynamic var car: Car?

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
			"private",
		]
	}

}

extension FuelEvent: CKRecordConvertible {
}

extension FuelEvent: CKRecordRecoverable {
	typealias O = FuelEvent
}
