//
//  CoreDataManager.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 21.05.15.
//
//

import UIKit
import CoreData
import CloudKit

final class CoreDataManager {
	// CoreData support
	static let managedObjectContext: NSManagedObjectContext = {
		let context = persistentContainer.viewContext
		context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
		return context
	}()

	static let persistentContainer: NSPersistentContainer = {
		return NSPersistentContainer(name: "Fuel")
	}()

	private static let applicationDocumentsDirectory: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last!

	static let sharedInstance = CoreDataManager()

	// MARK: - Core Data Support

	@discardableResult static func saveContext(_ context: NSManagedObjectContext = managedObjectContext) -> Bool {
		if context.hasChanges {
			do {
				let modifiedManagedObjects = context.insertedObjects.union(context.updatedObjects)
				let modifiedRecords = modifiedManagedObjects.flatMap { (managedObject) -> CKRecord? in
					if let ckManagedObject = managedObject as? CloudKitManagedObject {
						return ckManagedObject.asCloudKitRecord()
					}
					return nil
				}

				let deletedRecordIDs = context.deletedObjects.flatMap { ($0 as? CloudKitManagedObject)?.cloudKitRecordID }

				try context.save()

				CloudKitManager.save(modifiedRecords: modifiedRecords, deletedRecordIDs: deletedRecordIDs)
			} catch let error {
				let alertController = UIAlertController(title: NSLocalizedString("Can't Save Database", comment: ""),
					message: NSLocalizedString("Sorry, the application database cannot be saved. Please quit the application with the Home button.", comment: ""),
					preferredStyle: .alert)
				let defaultAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
					fatalError(error.localizedDescription)
				}
				alertController.addAction(defaultAction)
				UIApplication.kraftstoffAppDelegate.window?.rootViewController?.present(alertController, animated: true, completion: nil)
			}

			return true
		}

		return false
	}

	static func saveBackgroundContext(_ backgroundContext: NSManagedObjectContext) {
		if backgroundContext.hasChanges {
			do {
				try backgroundContext.save()
			} catch let error {
				fatalError("CoreDataManager - save backgroundManagedObjectContext ERROR: \(error.localizedDescription)")
			}
		}
	}

	static func modelIdentifierForManagedObject(_ object: NSManagedObject) -> String? {
		if object.objectID.isTemporaryID {
			do {
				try managedObjectContext.obtainPermanentIDs(for: [object])
			} catch {
				return nil
			}
		}
		return object.objectID.uriRepresentation().absoluteString
	}

	static func managedObjectForModelIdentifier<ResultType: NSManagedObject>(_ identifier: String) -> ResultType? {
		if let objectURL = URL(string: identifier), objectURL.scheme == "x-coredata" {
			if let objectID = persistentContainer.persistentStoreCoordinator.managedObjectID(forURIRepresentation: objectURL) {
				if let existingObject = try? managedObjectContext.existingObject(with: objectID) {
					return existingObject as? ResultType
				}
			}
		}

		return nil
	}

	static func existingObject(_ object: NSManagedObject, inManagedObjectContext moc: NSManagedObjectContext) -> NSManagedObject? {
		if object.isDeleted {
			return nil
		} else {
			return try? moc.existingObject(with: object.objectID)
		}
	}

	static func load() {
		persistentContainer.loadPersistentStores { (_, error) in
			if let error = error {
				let alertController = UIAlertController(title: NSLocalizedString("Can't Open Database", comment: ""),
				                                        message: NSLocalizedString("Sorry, the application database cannot be opened. Please quit the application with the Home button.", comment: ""),
				                                        preferredStyle: .alert)
				let defaultAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
					fatalError(error.localizedDescription)
				}
				alertController.addAction(defaultAction)
				UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
			}
		}
	}

	// MARK: - Preconfigured Core Data Fetches

	static func fetchRequestForCars() -> NSFetchRequest<Car> {
		let fetchRequest: NSFetchRequest<Car> = Car.fetchRequest()
		fetchRequest.fetchBatchSize = 32

		// Sorting keys
		let sortDescriptor = NSSortDescriptor(key: "order", ascending: true)
		fetchRequest.sortDescriptors = [sortDescriptor]

		return fetchRequest
	}

	static func fetchRequestForEvents(car: Car,
	                                  andDate date: Date?,
	                                  dateComparator dateCompare: String,
	                                  fetchSize: Int) -> NSFetchRequest<FuelEvent> {
		let fetchRequest: NSFetchRequest<FuelEvent> = FuelEvent.fetchRequest()
		fetchRequest.fetchBatchSize = fetchSize

		// Predicates
		let parentPredicate = NSPredicate(format: "car == %@", car)

		if let date = date {
			let datePredicate = NSPredicate(format: "timestamp \(dateCompare) %@", date as NSDate)
			fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [parentPredicate, datePredicate])
		} else {
			fetchRequest.predicate = parentPredicate
		}

		// Sorting keys
		let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: false)
		fetchRequest.sortDescriptors = [sortDescriptor]

		return fetchRequest
	}

	static func fetchRequestForEvents(car: Car,
	                                  afterDate date: Date?,
	                                  dateMatches: Bool) -> NSFetchRequest<FuelEvent> {
		return fetchRequestForEvents(car: car,
		                             andDate: date,
		                             dateComparator: dateMatches ? ">=" : ">",
		                             fetchSize: 128)
	}

	static func fetchRequestForEvents(car: Car,
	                                  beforeDate date: Date?,
	                                  dateMatches: Bool) -> NSFetchRequest<FuelEvent> {
		return fetchRequestForEvents(car: car,
		                             andDate: date,
		                             dateComparator: dateMatches ? "<=" : "<",
		                             fetchSize: 8)
	}

	static func fetchedResultsControllerForCars(inContext moc: NSManagedObjectContext = managedObjectContext) -> NSFetchedResultsController<Car> {
		let fetchRequest = fetchRequestForCars()

		// No section names; perform fetch without cache
		let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
		                                                          managedObjectContext: moc,
		                                                          sectionNameKeyPath: nil,
		                                                          cacheName: nil)

		// Perform the Core Data fetch
		do {
			try fetchedResultsController.performFetch()
		} catch let error {
			fatalError(error.localizedDescription)
		}

		return fetchedResultsController
	}

	static func objectsForFetchRequest<ResultType>(_ fetchRequest: NSFetchRequest<ResultType>, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext) -> [ResultType] {
		let fetchedObjects: [ResultType]?
		do {
			fetchedObjects = try moc.fetch(fetchRequest)
		} catch let error {
			fatalError(error.localizedDescription)
		}

		return fetchedObjects!
	}

	static func containsEventWithCar(_ car: Car, andDate date: Date, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext) -> Bool {
		let fetchRequest: NSFetchRequest<FuelEvent> = FuelEvent.fetchRequest()
		fetchRequest.fetchBatchSize = 2

		// Predicates
		let parentPredicate = NSPredicate(format: "car == %@", car)
		let datePredicate = NSPredicate(format: "timestamp == %@", date as NSDate)

		fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [parentPredicate, datePredicate])

		// Check whether fetch would reveal any event objects
		do {
			return try moc.count(for: fetchRequest) > 0
		} catch let error {
			fatalError(error.localizedDescription)
		}
	}

	// MARK: - Core Data Updates

	@discardableResult static func addToArchive(car: Car, date: Date, distance: Decimal, price: Decimal, fuelVolume: Decimal, filledUp: Bool, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext, comment: String?, forceOdometerUpdate odometerUpdate: Bool) -> FuelEvent {
		// Convert distance and fuelvolume to SI units
		let fuelUnit     = car.ksFuelUnit
		let odometerUnit = car.ksOdometerUnit

		let liters        = Units.litersForVolume(fuelVolume, withUnit: fuelUnit)
		let kilometers    = Units.kilometersForDistance(distance, withUnit: odometerUnit)
		let pricePerLiter = Units.pricePerLiter(price, withUnit: fuelUnit)

		var inheritedCost = Decimal(0)
		var inheritedDistance = Decimal(0)
		var inheritedFuelVolume = Decimal(0)

		var forceOdometerUpdate = odometerUpdate

		// Compute inherited data from older element

		// Fetch older events
		let olderEvents = objectsForFetchRequest(fetchRequestForEvents(car: car,
		                                                               beforeDate: date,
		                                                               dateMatches: false),
		                                         inManagedObjectContext: moc)

        if olderEvents.count > 0 {
			let olderEvent = olderEvents.first!

			if !olderEvent.filledUp {
				let cost = olderEvent.cost

				inheritedCost       = cost + olderEvent.ksInheritedCost
				inheritedDistance   = olderEvent.ksDistance + olderEvent.ksInheritedDistance
				inheritedFuelVolume = olderEvent.ksFuelVolume + olderEvent.ksInheritedFuelVolume
			}
		}

		// Update inherited distance/volume for younger events, probably mark the car odometer for an update
		// Fetch younger events
		let youngerEvents = objectsForFetchRequest(fetchRequestForEvents(car: car,
		                                                                 afterDate: date,
		                                                                 dateMatches: false),
		                                           inManagedObjectContext: moc)

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
				youngerEvent.ksInheritedCost = max(youngerEvent.ksInheritedCost + deltaCost, 0)
				youngerEvent.ksInheritedDistance = max(youngerEvent.ksInheritedDistance + deltaDistance, 0)
				youngerEvent.ksInheritedFuelVolume = max(youngerEvent.ksInheritedFuelVolume + deltaFuelVolume, 0)

				if youngerEvent.filledUp {
					break
				}
			}
		} else {
			// New event will be the youngest one => update odometer too
            forceOdometerUpdate = true
		}

		// Create new managed object for this event
		let newEvent = FuelEvent(context: moc)

		newEvent.lastUpdate = Date()
		newEvent.car = car
		newEvent.ksTimestamp = date
		newEvent.ksDistance = kilometers
		newEvent.ksPrice = pricePerLiter
		newEvent.ksFuelVolume = liters
		newEvent.comment = comment

		if !filledUp {
			newEvent.filledUp = filledUp
		}

		if !inheritedCost.isZero {
			newEvent.ksInheritedCost = inheritedCost
		}

		if !inheritedDistance.isZero {
			newEvent.ksInheritedDistance = inheritedDistance
		}

		if !inheritedFuelVolume.isZero {
			newEvent.ksInheritedFuelVolume = inheritedFuelVolume
		}

		// Conditions for update of global odometer:
		// - when the new event is the youngest one
		// - when sum of all events equals the odometer value
		// - when forced to do so
		if !forceOdometerUpdate {
			if car.ksOdometer <= car.ksDistanceTotalSum {
				forceOdometerUpdate = true
			}
		}

		// Update total car statistics
		car.ksDistanceTotalSum += kilometers
		car.ksFuelVolumeTotalSum += liters

		if forceOdometerUpdate {
			// Update global odometer
			car.ksOdometer = max(car.ksOdometer + kilometers, car.ksDistanceTotalSum)
		}

		return newEvent
	}

	static func removeEventFromArchive(_ event: FuelEvent!, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext, forceOdometerUpdate odometerUpdate: Bool) {
		// catch nil events
		if event == nil {
			return
		}

		var forceOdometerUpdate = odometerUpdate
		let car = event.car!
		let distance = event.ksDistance
		let fuelVolume = event.ksFuelVolume

		// Event will be deleted: update inherited distance/fuelVolume for younger events
		let youngerEvents = objectsForFetchRequest(fetchRequestForEvents(car: car,
		                                                                 afterDate: event.ksTimestamp,
		                                                                 dateMatches: false),
		                                           inManagedObjectContext: moc)

		var row = youngerEvents.count
		if row > 0 {
			// Fill-up event deleted => propagate its inherited distance/volume
			if event.filledUp {
				let inheritedCost       = event.ksInheritedCost
				let inheritedDistance   = event.ksInheritedDistance
				let inheritedFuelVolume = event.ksInheritedFuelVolume

				if inheritedCost > 0 || inheritedDistance > 0 || inheritedFuelVolume > 0 {
					while row > 0 {
						row -= 1
						let youngerEvent = youngerEvents[row]

						youngerEvent.ksInheritedCost += inheritedCost
						youngerEvent.ksInheritedDistance += inheritedDistance
						youngerEvent.ksInheritedFuelVolume += inheritedFuelVolume

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
					let cost = event.ksPrice

					youngerEvent.ksInheritedCost = max(youngerEvent.ksInheritedCost - cost, 0)
					youngerEvent.ksInheritedDistance = max(youngerEvent.ksInheritedDistance - distance, 0)
					youngerEvent.ksInheritedFuelVolume = max(youngerEvent.ksInheritedFuelVolume - fuelVolume, 0)

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
			if car.ksOdometer <= car.ksDistanceTotalSum {
				forceOdometerUpdate = true
			}
		}

		// Update total car statistics
		car.ksDistanceTotalSum = max(car.ksDistanceTotalSum - distance, 0)
		car.ksFuelVolumeTotalSum = max(car.ksFuelVolumeTotalSum - fuelVolume, 0)

		// Update global odometer
		if forceOdometerUpdate {
			car.ksOdometer = max(car.ksOdometer - distance, 0)
		}

		// Delete the managed event object
		moc.delete(event)
	}

	static func deleteAllObjects() {
		for entity in persistentContainer.managedObjectModel.entitiesByName.keys {
			let deleteRequest = NSBatchDeleteRequest(fetchRequest: NSFetchRequest(entityName: entity))

			do {
				try persistentContainer.persistentStoreCoordinator.execute(deleteRequest, with: managedObjectContext)
			} catch let error {
				print(error)
			}
		}
	}

	static func fetchCloudKitManagedObjects(managedObjectContext: NSManagedObjectContext, managedObjectIDs: [NSManagedObjectID]) -> [CloudKitManagedObject] {
		return managedObjectIDs.flatMap { managedObjectID in
			do {
				return try managedObjectContext.existingObject(with: managedObjectID) as? CloudKitManagedObject
			} catch {
				return nil
			}
		}
	}

}
