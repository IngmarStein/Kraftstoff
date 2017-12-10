//
//  Car.swift
//
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import RealmSwift
import IceCream

final class Car: Object {

	@objc dynamic var id = UUID().uuidString
	@objc dynamic var isDeleted = false
	@objc private dynamic var _distanceTotalSum = "0.0"
	@objc private dynamic var _fuelConsumptionUnit = 0
	@objc private dynamic var _fuelUnit = 0
	@objc private dynamic var _fuelVolumeTotalSum = "0.0"
	@objc dynamic var name = ""
	@objc dynamic var numberPlate = ""
	@objc private dynamic var _odometer = "0.0"
	@objc private dynamic var _odometerUnit = 0
	@objc dynamic var order = 0
	@objc dynamic var timestamp = Date()
	let fuelEvents = List<FuelEvent>()

	override class func primaryKey() -> String? {
		return #keyPath(Car.id)
	}

	public override class func ignoredProperties() -> [String] {
		return [
			"distanceTotalSum",
			"fuelConsumptionUnit",
			"fuelUnit",
			"fuelVolumeTotalSum",
			"odometer",
			"odometerUnit"
		]
	}

	var distanceTotalSum: Decimal {
		get { return Decimal(string: _distanceTotalSum)! }
		set { _distanceTotalSum = String(describing: newValue) }
	}

	var fuelVolumeTotalSum: Decimal {
		get { return Decimal(string: _fuelVolumeTotalSum)! }
		set { _fuelVolumeTotalSum = String(describing: newValue) }
	}

	var odometer: Decimal {
		get { return Decimal(string: _odometer)! }
		set { _odometer = String(describing: newValue) }
	}

	var fuelUnit: UnitVolume {
		get { return .fromPersistentId(_fuelUnit) }
		set { _fuelUnit = newValue.persistentId }
	}

	var fuelConsumptionUnit: UnitFuelEfficiency {
		get { return .fromPersistentId(_fuelConsumptionUnit) }
		set { _fuelConsumptionUnit = newValue.persistentId }
	}

	var odometerUnit: UnitLength {
		get { return .fromPersistentId(_odometerUnit) }
		set { _odometerUnit = newValue.persistentId	}
	}

}

extension Car: CKRecordConvertible {
}

extension Car: CKRecordRecoverable {
	// swiftlint:disable:next type_name
	typealias O = Car
}
