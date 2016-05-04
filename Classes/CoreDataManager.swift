//
//  CoreDataManager.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 21.05.15.
//
//

import UIKit
import CoreData

final class CoreDataManager {
	// CoreData support
	static let managedObjectContext: NSManagedObjectContext = {
		let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
		managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
		managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
		return managedObjectContext
	}()

	private static let managedObjectModel: NSManagedObjectModel = {
		let modelPath = NSBundle.main().pathForResource("Kraftstoffrechner", ofType:"momd")!
		return NSManagedObjectModel(contentsOf:NSURL(fileURLWithPath: modelPath))!
	}()

	private static let applicationDocumentsDirectory: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last!

	private static let localStoreURL = NSURL(fileURLWithPath:applicationDocumentsDirectory).appendingPathComponent("Kraftstoffrechner.sqlite")
	private static let iCloudStoreURL = NSURL(fileURLWithPath:applicationDocumentsDirectory).appendingPathComponent("Fuel.sqlite")

	private static var iCloudLocalStoreURL : NSURL? {
		let ubiquityContainer = NSURL(fileURLWithPath:applicationDocumentsDirectory).appendingPathComponent("CoreDataUbiquitySupport")
		if let peers = try? NSFileManager.default().contentsOfDirectory(at: ubiquityContainer, includingPropertiesForKeys: nil, options: []) {
			let fileManager = NSFileManager.default()
			for peer in peers {
				let localStoreURL = peer.appendingPathComponent("Kraftstoff/local/store/Fuel.sqlite")
				if fileManager.fileExists(atPath: localStoreURL.path!) {
					return localStoreURL
				}
			}
		}
		return nil
	}

	private static let localStoreOptions = [
		NSMigratePersistentStoresAutomaticallyOption: true,
		NSInferMappingModelAutomaticallyOption: true,
	]

	private static let iCloudStoreOptions = [
		NSMigratePersistentStoresAutomaticallyOption: true,
		NSInferMappingModelAutomaticallyOption: true,
		NSPersistentStoreUbiquitousContentNameKey: "Kraftstoff2"
	]

	static let sharedInstance = CoreDataManager()

	private static let persistentStoreCoordinator: NSPersistentStoreCoordinator = {
		let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel:managedObjectModel)

		do {
			try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName:nil, at:iCloudStoreURL, options:iCloudStoreOptions)
		} catch let error as NSError {
			let alertController = UIAlertController(title:NSLocalizedString("Can't Open Database", comment:""),
				message:NSLocalizedString("Sorry, the application database cannot be opened. Please quit the application with the Home button.", comment:""),
				preferredStyle: .alert)
			let defaultAction = UIAlertAction(title:NSLocalizedString("OK", comment:""), style: .`default`) { _ in
				fatalError(error.localizedDescription)
			}
			alertController.addAction(defaultAction)
			UIApplication.shared().keyWindow?.rootViewController?.present(alertController, animated:true, completion:nil)
		} catch {
			fatalError()
		}

		return persistentStoreCoordinator
	}()

	//MARK: - Core Data Support

	static func saveContext(_ context: NSManagedObjectContext = managedObjectContext) -> Bool {
		if context.hasChanges {
			do {
				try context.save()
			} catch let error as NSError {
				let alertController = UIAlertController(title:NSLocalizedString("Can't Save Database", comment:""),
					message:NSLocalizedString("Sorry, the application database cannot be saved. Please quit the application with the Home button.", comment:""),
					preferredStyle: .alert)
				let defaultAction = UIAlertAction(title:NSLocalizedString("OK", comment:""), style: .`default`) { _ in
					fatalError(error.localizedDescription)
				}
				alertController.addAction(defaultAction)
				UIApplication.kraftstoffAppDelegate.window?.rootViewController?.present(alertController, animated:true, completion:nil)
			}

			return true
		}

		return false
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

	static func managedObjectForModelIdentifier(_ identifier: String) -> NSManagedObject? {
		let objectURL = NSURL(string:identifier)!

		if objectURL.scheme == "x-coredata" {
			if let objectID = persistentStoreCoordinator.managedObjectID(forURIRepresentation: objectURL) {
				return try? managedObjectContext.existingObject(with: objectID)
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

	//MARK: - iCloud support

	private static func migrateStore(_ sourceStoreURL: NSURL, options: [NSObject : AnyObject]) {
		let migrationPSC = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

		var migrationOptions = options
		migrationOptions[NSReadOnlyPersistentStoreOption] = true

		// Open the existing local store
		do {
			let sourceStore = try migrationPSC.addPersistentStore(ofType: NSSQLiteStoreType, configurationName:nil, at:sourceStoreURL, options:migrationOptions)
			do {
				try migrationPSC.migratePersistentStore(sourceStore, to: iCloudStoreURL, options: iCloudStoreOptions, withType:NSSQLiteStoreType)
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					let fileCoordinator = NSFileCoordinator()
					var error: NSError?
					fileCoordinator.coordinate(writingItemAt: sourceStoreURL, options: .forMoving, error: &error) { writingURL in
						let targetURL = sourceStoreURL.appendingPathExtension("migrated")
						do {
							try NSFileManager.default().moveItem(at: sourceStoreURL, to: targetURL)
						} catch let error as NSError {
							NSLog("error renaming store after migration: %@", error.localizedDescription)
						}
					}
				}
			} catch let error as NSError {
				NSLog("error while migrating to iCloud: %@", error.localizedDescription)
			}
		} catch let error as NSError {
			NSLog("failed to open local store for migration: %@", error.localizedDescription)
		}
	}

	static func migrateToiCloud() {
		// migrate old non-iCloud store
		if NSFileManager.default().fileExists(atPath: localStoreURL.path!) {
			migrateStore(localStoreURL, options: localStoreOptions)
		}

		// migrate old iCloud store without iCloud Documents entitlement
		if let url = iCloudLocalStoreURL where NSFileManager.default().fileExists(atPath: url.path!) {
			migrateStore(url, options: localStoreOptions)
		}
	}

	func registerForiCloudNotifications() {
		let notificationCenter = NSNotificationCenter.default()

		notificationCenter.addObserver(self,
			selector: #selector(CoreDataManager.storesWillChange(_:)),
			name: NSPersistentStoreCoordinatorStoresWillChangeNotification,
			object: CoreDataManager.persistentStoreCoordinator)

		notificationCenter.addObserver(self,
			selector: #selector(CoreDataManager.storesDidChange(_:)),
			name: NSPersistentStoreCoordinatorStoresDidChangeNotification,
			object: CoreDataManager.persistentStoreCoordinator)

		notificationCenter.addObserver(self,
			selector: #selector(CoreDataManager.persistentStoreDidImportUbiquitousContentChanges(_:)),
			name: NSPersistentStoreDidImportUbiquitousContentChangesNotification,
			object: CoreDataManager.persistentStoreCoordinator)
	}

	private static func cleanupDetachedFuelEvents(_ moc : NSManagedObjectContext) {
		let fetchRequest = NSFetchRequest()
		fetchRequest.entity = NSEntityDescription.entity(forEntityName: "fuelEvent", in:moc)
		fetchRequest.predicate = NSPredicate(format:"car == nil")

		let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
		do {
			try moc.execute(deleteRequest)
		} catch {
			// ignore
		}
	}

	@objc func persistentStoreDidImportUbiquitousContentChanges(_ changeNotification: NSNotification) {
		let context = CoreDataManager.managedObjectContext

		context.perform {
			context.mergeChanges(fromContextDidSave: changeNotification)
			CoreDataManager.cleanupDetachedFuelEvents(context)
		}
	}

	@objc func storesWillChange(_ notification: NSNotification) {
		let context = CoreDataManager.managedObjectContext

		context.performAndWait {
			if context.hasChanges {
				do {
					try context.save()
				} catch let error as NSError {
					NSLog("%@", error.localizedDescription)
				} catch {
					fatalError()
				}
			}

			context.reset()
		}
	}

	@objc func storesDidChange(_ notification: NSNotification) {
		NSLog("storesDidChange: %@", notification)
	}

	//MARK: - Preconfigured Core Data Fetches

	static func fetchRequestForCarsInManagedObjectContext(_ moc: NSManagedObjectContext) -> NSFetchRequest {
		let fetchRequest = NSFetchRequest()

		// Entity name
		let entity = NSEntityDescription.entity(forEntityName: "car", in: moc)
		fetchRequest.entity = entity
		fetchRequest.fetchBatchSize = 32

		// Sorting keys
		let sortDescriptor = NSSortDescriptor(key:"order", ascending:true)
		fetchRequest.sortDescriptors = [sortDescriptor]

		return fetchRequest
	}

	static func fetchRequestForEvents(car: Car,
                                       andDate date: NSDate?,
                                dateComparator dateCompare: String,
                                     fetchSize: Int,
                        inManagedObjectContext moc: NSManagedObjectContext) -> NSFetchRequest {
		let fetchRequest = NSFetchRequest()

		// Entity name
		let entity = NSEntityDescription.entity(forEntityName: "fuelEvent", in: moc)
		fetchRequest.entity = entity
		fetchRequest.fetchBatchSize = fetchSize

		// Predicates
		let parentPredicate = NSPredicate(format:"car == %@", car)

		if let date = date {
			let datePredicate = NSPredicate(format:"timestamp \(dateCompare) %@", date)
			fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates:[parentPredicate, datePredicate])
		} else {
			fetchRequest.predicate = parentPredicate
		}

		// Sorting keys
		let sortDescriptor = NSSortDescriptor(key:"timestamp", ascending:false)
		fetchRequest.sortDescriptors = [sortDescriptor]

		return fetchRequest
	}

	static func fetchRequestForEvents(car: Car,
                                     afterDate date: NSDate?,
                                   dateMatches: Bool,
                        inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext) -> NSFetchRequest {
		return fetchRequestForEvents(car: car,
                                     andDate:date,
                              dateComparator:dateMatches ? ">=" : ">",
                                   fetchSize:128,
                      inManagedObjectContext:moc)
	}

	static func fetchRequestForEvents(car: Car,
                                    beforeDate date: NSDate?,
                                   dateMatches: Bool,
                        inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext) -> NSFetchRequest {
		return fetchRequestForEvents(car: car,
                                     andDate:date,
                              dateComparator:dateMatches ? "<=" : "<",
                                   fetchSize:8,
                      inManagedObjectContext:moc)
	}

	static func fetchedResultsControllerForCars(inContext moc: NSManagedObjectContext = managedObjectContext) -> NSFetchedResultsController {
		let fetchRequest = fetchRequestForCarsInManagedObjectContext(moc)

		// No section names; perform fetch without cache
		let fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchRequest,
			managedObjectContext:moc,
			sectionNameKeyPath:nil,
            cacheName:nil)

		// Perform the Core Data fetch
		do {
			try fetchedResultsController.performFetch()
		} catch let error as NSError {
			fatalError(error.localizedDescription)
		}

		return fetchedResultsController
	}

	static func objectsForFetchRequest(_ fetchRequest: NSFetchRequest, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext) -> [NSManagedObject] {
		let fetchedObjects: [AnyObject]?
		do {
			fetchedObjects = try moc.fetch(fetchRequest)
		} catch let error as NSError {
			fatalError(error.localizedDescription)
		}

		return fetchedObjects as! [NSManagedObject]
	}

	static func containsEventWithCar(_ car: Car, andDate date: NSDate, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext) -> Bool {
		let fetchRequest = NSFetchRequest()

		// Entity name
		let entity = NSEntityDescription.entity(forEntityName: "fuelEvent", in: moc)
		fetchRequest.entity = entity
		fetchRequest.fetchBatchSize = 2

		// Predicates
		let parentPredicate = NSPredicate(format:"car == %@", car)
		let datePredicate = NSPredicate(format:"timestamp == %@", date)

		fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates:[parentPredicate, datePredicate])

		// Check whether fetch would reveal any event objects
		var error: NSError?
		let objectCount = moc.count(for: fetchRequest, error:&error)

		if let error = error {
			fatalError(error.localizedDescription)
		}

		return objectCount > 0
	}

	//MARK: - Core Data Updates

	static func addToArchive(car: Car, date: NSDate, distance: NSDecimalNumber, price: NSDecimalNumber, fuelVolume: NSDecimalNumber, filledUp: Bool, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext, comment: String?, forceOdometerUpdate odometerUpdate: Bool) -> FuelEvent {
		let zero = NSDecimalNumber.zero()

		// Convert distance and fuelvolume to SI units
		let fuelUnit     = car.ksFuelUnit
		let odometerUnit = car.ksOdometerUnit

		let liters        = Units.litersForVolume(fuelVolume, withUnit:fuelUnit)
		let kilometers    = Units.kilometersForDistance(distance, withUnit:odometerUnit)
		let pricePerLiter = Units.pricePerLiter(price: price, withUnit:fuelUnit)

		var inheritedCost       = zero
		var inheritedDistance   = zero
		var inheritedFuelVolume = zero

		var forceOdometerUpdate = odometerUpdate

		// Compute inherited data from older element

		// Fetch older events
        let olderEvents = objectsForFetchRequest(fetchRequestForEvents(car: car,
                                                                                    beforeDate:date,
                                                                                   dateMatches:false,
                                                                        inManagedObjectContext:moc),
                                     inManagedObjectContext:moc) as! [FuelEvent]

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
		let youngerEvents = objectsForFetchRequest(fetchRequestForEvents(car: car,
                                                                                       afterDate:date,
                                                                                     dateMatches:false,
                                                                          inManagedObjectContext:moc),
                                       inManagedObjectContext:moc) as! [FuelEvent]

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
				youngerEvent.inheritedCost = max(youngerEvent.inheritedCost + deltaCost, zero)
				youngerEvent.inheritedDistance = max(youngerEvent.inheritedDistance + deltaDistance, zero)
				youngerEvent.inheritedFuelVolume = max(youngerEvent.inheritedFuelVolume + deltaFuelVolume, zero)

				if youngerEvent.filledUp {
                    break
				}
            }
		} else {
			// New event will be the youngest one => update odometer too
            forceOdometerUpdate = true
		}

		// Create new managed object for this event
		let newEvent = NSEntityDescription.insertNewObject(forEntityName: "fuelEvent", into: moc) as! FuelEvent

		newEvent.car = car
		newEvent.timestamp = date
		newEvent.distance = kilometers
		newEvent.price = pricePerLiter
		newEvent.fuelVolume = liters
		newEvent.comment = comment

		if !filledUp {
			newEvent.filledUp = filledUp
		}

		if inheritedCost != zero {
			newEvent.inheritedCost = inheritedCost
		}

		if inheritedDistance != zero {
			newEvent.inheritedDistance = inheritedDistance
		}

		if inheritedFuelVolume != zero {
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

		// Update total car statistics
		car.distanceTotalSum = car.distanceTotalSum + kilometers
		car.fuelVolumeTotalSum = car.fuelVolumeTotalSum + liters

		if forceOdometerUpdate {
			// Update global odometer
			car.odometer = max(car.odometer + kilometers, car.distanceTotalSum)
		}

		return newEvent
	}

	static func removeEventFromArchive(_ event: FuelEvent!, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext, forceOdometerUpdate odometerUpdate: Bool) {
		// catch nil events
		if event == nil {
			return
		}

		var forceOdometerUpdate = odometerUpdate
		let car = event.car
		let distance = event.distance
		let fuelVolume = event.fuelVolume
		let zero = NSDecimalNumber.zero()

		// Event will be deleted: update inherited distance/fuelVolume for younger events
		let youngerEvents = objectsForFetchRequest(fetchRequestForEvents(car: car,
                                                                                  afterDate:event.timestamp,
                                                                                dateMatches:false,
                                                                     inManagedObjectContext:moc),
                                   inManagedObjectContext:moc) as! [FuelEvent]

		var row = youngerEvents.count
		if row > 0 {
			// Fill-up event deleted => propagate its inherited distance/volume
			if event.filledUp {
				let inheritedCost       = event.inheritedCost
				let inheritedDistance   = event.inheritedDistance
				let inheritedFuelVolume = event.inheritedFuelVolume

				if inheritedCost > zero || inheritedDistance > zero || inheritedFuelVolume > zero {
					while row > 0 {
						row = row - 1
						let youngerEvent = youngerEvents[row]

						youngerEvent.inheritedCost = youngerEvent.inheritedCost + inheritedCost
						youngerEvent.inheritedDistance = youngerEvent.inheritedDistance + inheritedDistance
						youngerEvent.inheritedFuelVolume = youngerEvent.inheritedFuelVolume + inheritedFuelVolume

						if youngerEvent.filledUp {
							break
						}
					}
				}
			} else {
				// Intermediate event deleted => remove distance/volume from inherited data

				while row > 0 {
					row = row - 1
					let youngerEvent = youngerEvents[row]
					let cost = event.price

					youngerEvent.inheritedCost = max(youngerEvent.inheritedCost - cost, zero)
					youngerEvent.inheritedDistance = max(youngerEvent.inheritedDistance - distance, zero)
					youngerEvent.inheritedFuelVolume = max(youngerEvent.inheritedFuelVolume - fuelVolume, zero)

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
		car.distanceTotalSum = max(car.distanceTotalSum - distance, zero)
		car.fuelVolumeTotalSum = max(car.fuelVolumeTotalSum - fuelVolume, zero)

		// Update global odometer
		if forceOdometerUpdate {
			car.odometer = max(car.odometer - distance, zero)
		}

		// Delete the managed event object
		moc.delete(event)
	}

	static func deleteAllObjects() {
		for entity in managedObjectModel.entitiesByName.keys {
			let deleteRequest = NSBatchDeleteRequest(fetchRequest: NSFetchRequest(entityName: entity))

			do {
				try persistentStoreCoordinator.execute(deleteRequest, with: managedObjectContext)
			} catch let error as NSError {
				print(error)
			}
		}
	}
}
