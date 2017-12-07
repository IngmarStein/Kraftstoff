//
//  DataManager.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 21.05.15.
//
//

import UIKit
import RealmSwift

final class DataManager {

	// MARK: - Preconfigured Data Fetches

	static func cars() -> Results<Car> {
		// swiftlint:disable:next force_try
		let realm = try! Realm()
		let isNotDeletedPredicate = NSPredicate(format: "isDeleted == false")
		return realm.objects(Car.self)
			.filter(isNotDeletedPredicate)
			.sorted(byKeyPath: "order", ascending: true)
	}

	static func fuelEventsForCar(car: Car,
	                             andDate date: Date?,
	                             dateComparator dateCompare: String) -> Results<FuelEvent> {
		// swiftlint:disable:next force_try
		let realm = try! Realm()
		let parentPredicate = NSPredicate(format: "car == %@", car)
		let isNotDeletedPredicate = NSPredicate(format: "isDeleted == false")

		let subpredicates: [NSPredicate]
		if let date = date {
			let datePredicate = NSPredicate(format: "timestamp \(dateCompare) %@", date as NSDate)
			subpredicates = [parentPredicate, isNotDeletedPredicate, datePredicate]
		} else {
			subpredicates = [parentPredicate, isNotDeletedPredicate]
		}
		let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)

		return realm.objects(FuelEvent.self)
			.filter(compoundPredicate)
			.sorted(byKeyPath: "timestamp", ascending: false)
	}

	static func fuelEventsForCar(car: Car,
	                             afterDate date: Date?,
	                             dateMatches: Bool) -> Results<FuelEvent> {
		return fuelEventsForCar(car: car,
		                        andDate: date,
		                        dateComparator: dateMatches ? ">=" : ">")
	}

	static func fuelEventsForCar(car: Car,
	                             beforeDate date: Date?,
	                             dateMatches: Bool) -> Results<FuelEvent> {
		return fuelEventsForCar(car: car,
		                        andDate: date,
		                        dateComparator: dateMatches ? "<=" : "<")
	}

	static func containsEventWithCar(_ car: Car, andDate date: Date) -> Bool {
		// swiftlint:disable:next force_try
		let realm = try! Realm()
		// Predicates
		let parentPredicate = NSPredicate(format: "car == %@", car)
		let datePredicate = NSPredicate(format: "timestamp == %@", date as NSDate)

		let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [parentPredicate, datePredicate])
		return realm.objects(FuelEvent.self).filter(compoundPredicate).count > 0
	}

	// MARK: - Data Updates

	@discardableResult static func addToArchive(car: Car, date: Date, distance: Decimal, price: Decimal, fuelVolume: Decimal, filledUp: Bool, comment: String?, forceOdometerUpdate odometerUpdate: Bool) -> FuelEvent {
		// Convert distance and fuelvolume to SI units
		let fuelUnit     = car.fuelUnit
		let odometerUnit = car.odometerUnit

		let liters        = Units.litersForVolume(fuelVolume, withUnit: fuelUnit)
		let kilometers    = Units.kilometersForDistance(distance, withUnit: odometerUnit)
		let pricePerLiter = Units.pricePerLiter(price, withUnit: fuelUnit)

		var inheritedCost = Decimal(0)
		var inheritedDistance = Decimal(0)
		var inheritedFuelVolume = Decimal(0)

		var forceOdometerUpdate = odometerUpdate

		// Compute inherited data from older element

		// Fetch older events
		let olderEvents = fuelEventsForCar(car: car, beforeDate: date, dateMatches: false)

        if olderEvents.count > 0 {
			let olderEvent = olderEvents.first!

			if !olderEvent.filledUp {
				let cost = olderEvent.cost

				inheritedCost       = cost + olderEvent.inheritedCost
				inheritedDistance   = olderEvent.distance + olderEvent.inheritedDistance
				inheritedFuelVolume = olderEvent.fuelVolume + olderEvent.inheritedFuelVolume
			}
		}

		// Update inherited distance/volume for younger events, probably mark the car odometer for an update
		// Fetch younger events
		let youngerEvents = fuelEventsForCar(car: car, afterDate: date, dateMatches: false)

        if youngerEvents.count > 0 {

			let deltaCost = filledUp
				? -inheritedCost
				: liters * pricePerLiter

			let deltaDistance = filledUp
				? -inheritedDistance
				: kilometers

			let deltaFuelVolume = filledUp
				? -inheritedFuelVolume
				: liters

			for youngerEvent in youngerEvents.reversed() {
				youngerEvent.inheritedCost = max(youngerEvent.inheritedCost + deltaCost, 0)
				youngerEvent.inheritedDistance = max(youngerEvent.inheritedDistance + deltaDistance, 0)
				youngerEvent.inheritedFuelVolume = max(youngerEvent.inheritedFuelVolume + deltaFuelVolume, 0)

				if youngerEvent.filledUp {
					break
				}
			}
		} else {
			// New event will be the youngest one => update odometer too
            forceOdometerUpdate = true
		}

		// Create new managed object for this event
		let newEvent = FuelEvent()

		newEvent.car = car
		newEvent.timestamp = date
		newEvent.distance = kilometers
		newEvent.price = pricePerLiter
		newEvent.fuelVolume = liters
		newEvent.comment = comment

		if !filledUp {
			newEvent.filledUp = filledUp
		}

		if !inheritedCost.isZero {
			newEvent.inheritedCost = inheritedCost
		}

		if !inheritedDistance.isZero {
			newEvent.inheritedDistance = inheritedDistance
		}

		if !inheritedFuelVolume.isZero {
			newEvent.inheritedFuelVolume = inheritedFuelVolume
		}

		// Conditions for update of global odometer:
		// - when the new event is the youngest one
		// - when sum of all events equals the odometer value
		// - when forced to do so
		if !forceOdometerUpdate {
			if car.odometer <= car.distanceTotalSum {
				forceOdometerUpdate = true
			}
		}

		// swiftlint:disable:next force_try
		let realm = try! Realm()
		// swiftlint:disable:next force_try
		try! realm.write {
			// Update total car statistics
			car.distanceTotalSum += kilometers
			car.fuelVolumeTotalSum += liters

			if forceOdometerUpdate {
				// Update global odometer
				car.odometer = max(car.odometer + kilometers, car.distanceTotalSum)
			}

			realm.add(newEvent)
		}

		return newEvent
	}

	static func removeEvent(_ event: FuelEvent!, forceOdometerUpdate odometerUpdate: Bool) {
		// catch nil events
		if event == nil {
			return
		}

		var forceOdometerUpdate = odometerUpdate
		let car = event.car!
		let distance = event.distance
		let fuelVolume = event.fuelVolume

		// Event will be deleted: update inherited distance/fuelVolume for younger events
		let youngerEvents = fuelEventsForCar(car: car,
											 afterDate: event.timestamp,
		                                     dateMatches: false)

		// swiftlint:disable:next force_try
		let realm = try! Realm()
		// swiftlint:disable:next force_try
		try! realm.write {
			var row = youngerEvents.count
			if row > 0 {
				// Fill-up event deleted => propagate its inherited distance/volume
				if event.filledUp {
					let inheritedCost       = event.inheritedCost
					let inheritedDistance   = event.inheritedDistance
					let inheritedFuelVolume = event.inheritedFuelVolume

					if inheritedCost > 0 || inheritedDistance > 0 || inheritedFuelVolume > 0 {
						while row > 0 {
							row -= 1
							let youngerEvent = youngerEvents[row]

							youngerEvent.inheritedCost += inheritedCost
							youngerEvent.inheritedDistance += inheritedDistance
							youngerEvent.inheritedFuelVolume += inheritedFuelVolume

							if youngerEvent.filledUp {
								break
							}
						}
					}
				} else {
					// Intermediate event deleted => remove distance/volume from inherited data

					while row > 0 {
						row -= 1
						let youngerEvent = youngerEvents[row]
						let cost = event.price

						youngerEvent.inheritedCost = max(youngerEvent.inheritedCost - cost, 0)
						youngerEvent.inheritedDistance = max(youngerEvent.inheritedDistance - distance, 0)
						youngerEvent.inheritedFuelVolume = max(youngerEvent.inheritedFuelVolume - fuelVolume, 0)

						if youngerEvent.filledUp {
							break
						}
					}
				}
			} else {
				forceOdometerUpdate = true
			}

			// Conditions for update of global odometer:
			// - when youngest element gets deleted
			// - when sum of all events equals the odometer value
			// - when forced to do so
			if !forceOdometerUpdate {
				if car.odometer <= car.distanceTotalSum {
					forceOdometerUpdate = true
				}
			}

			// Update total car statistics
			car.distanceTotalSum = max(car.distanceTotalSum - distance, 0)
			car.fuelVolumeTotalSum = max(car.fuelVolumeTotalSum - fuelVolume, 0)

			// Update global odometer
			if forceOdometerUpdate {
				car.odometer = max(car.odometer - distance, 0)
			}

			// Delete the managed event object
			realm.delete(event)
		}
	}

}
