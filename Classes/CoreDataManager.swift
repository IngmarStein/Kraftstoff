//
//  CoreDataManager.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 21.05.15.
//
//

import UIKit
import CoreData

public class CoreDataManager {
	// CoreData support
	static let managedObjectContext: NSManagedObjectContext! = {
		let managedObjectContext = NSManagedObjectContext(concurrencyType:.MainQueueConcurrencyType)
		managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
		managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
		return managedObjectContext
	}()

	private static let managedObjectModel: NSManagedObjectModel = {
		let modelPath = NSBundle.mainBundle().pathForResource("Kraftstoffrechner", ofType:"momd")!
		return NSManagedObjectModel(contentsOfURL:NSURL(fileURLWithPath: modelPath)!)!
	}()

	private static let applicationDocumentsDirectory: String = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).last as! String
	
	private static let localStoreURL = NSURL(fileURLWithPath:applicationDocumentsDirectory)!.URLByAppendingPathComponent("Kraftstoffrechner.sqlite")
	private static let iCloudStoreURL = NSURL(fileURLWithPath:applicationDocumentsDirectory)!.URLByAppendingPathComponent("Fuel.sqlite")

	private static var iCloudLocalStoreURL : NSURL? {
		let ubiquityContainer = NSURL(fileURLWithPath:applicationDocumentsDirectory)!.URLByAppendingPathComponent("CoreDataUbiquitySupport")
		var error : NSError?
		if let peers = NSFileManager.defaultManager().contentsOfDirectoryAtURL(ubiquityContainer, includingPropertiesForKeys: nil, options: .allZeros, error: &error) as? [NSURL] {
			let fileManager = NSFileManager.defaultManager()
			for peer in peers {
				let localStoreURL = peer.URLByAppendingPathComponent("Kraftstoff/local/store/Fuel.sqlite")
				if fileManager.fileExistsAtPath(localStoreURL.path!) {
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
		var error: NSError?

		let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel:managedObjectModel)

		if persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration:nil, URL:iCloudStoreURL, options:iCloudStoreOptions, error:&error) == nil {
			let alertController = UIAlertController(title:NSLocalizedString("Can't Open Database", comment:""),
				message:NSLocalizedString("Sorry, the application database cannot be opened. Please quit the application with the Home button.", comment:""),
				preferredStyle:.Alert)
			let defaultAction = UIAlertAction(title:NSLocalizedString("OK", comment:""), style:.Default) { _ in
				fatalError(error!.localizedDescription)
			}
			alertController.addAction(defaultAction)
			UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alertController, animated:true, completion:nil)
		}

		return persistentStoreCoordinator
	}()

	//MARK: - Core Data Support

	static func saveContext(context: NSManagedObjectContext = managedObjectContext) -> Bool {
		if context.hasChanges {
			var error : NSError?

			if !context.save(&error) {
				let alertController = UIAlertController(title:NSLocalizedString("Can't Save Database", comment:""),
					message:NSLocalizedString("Sorry, the application database cannot be saved. Please quit the application with the Home button.", comment:""),
					preferredStyle:.Alert)
				let defaultAction = UIAlertAction(title:NSLocalizedString("OK", comment:""), style:.Default) { _ in
					fatalError(error!.localizedDescription)
				}
				alertController.addAction(defaultAction)
				UIApplication.kraftstoffAppDelegate.window?.rootViewController?.presentViewController(alertController, animated:true, completion:nil)
			}

			return true
		}

		return false
	}

	static func modelIdentifierForManagedObject(object: NSManagedObject) -> String? {
		if !object.objectID.temporaryID {
			return object.objectID.URIRepresentation().absoluteString
		} else {
			return nil
		}
	}

	static func managedObjectForModelIdentifier(identifier: String) -> NSManagedObject? {
		let objectURL = NSURL(string:identifier)!

		if objectURL.scheme == "x-coredata" {
			if let objectID = persistentStoreCoordinator.managedObjectIDForURIRepresentation(objectURL) {
				return managedObjectContext.existingObjectWithID(objectID, error:nil)
			}
		}

		return nil
	}

	static func existingObject(object: NSManagedObject, inManagedObjectContext moc: NSManagedObjectContext) -> NSManagedObject? {
		if object.deleted {
			return nil
		} else {
			return moc.existingObjectWithID(object.objectID, error:nil)
		}
	}

	//MARK: - iCloud support

	private static func migrateStore(sourceStoreURL: NSURL, options: [NSObject : AnyObject]) {
		let migrationPSC = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

		var migrationOptions = options
		migrationOptions[NSReadOnlyPersistentStoreOption] = true

		// Open the existing local store
		var error: NSError?
		if let sourceStore = migrationPSC.addPersistentStoreWithType(NSSQLiteStoreType, configuration:nil, URL:sourceStoreURL, options:migrationOptions, error:&error) {
			if let newStore = migrationPSC.migratePersistentStore(sourceStore, toURL:iCloudStoreURL, options:iCloudStoreOptions, withType:NSSQLiteStoreType, error:&error) {
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					let fileCoordinator = NSFileCoordinator()
					fileCoordinator.coordinateWritingItemAtURL(sourceStoreURL, options: .ForMoving, error: &error) { writingURL in
						var renameError: NSError?
						let targetURL = sourceStoreURL.URLByAppendingPathExtension("migrated")
						if !NSFileManager.defaultManager().moveItemAtURL(sourceStoreURL, toURL: targetURL, error: &renameError) {
							if let error = renameError {
								NSLog("error renaming store after migration: %@", error.localizedDescription)
							}
						}
					}
				}
			} else  {
				if let error = error {
					NSLog("error while migrating to iCloud: %@", error.localizedDescription)
				}
			}
		} else {
			if let error = error {
				NSLog("failed to open local store for migration: %@", error.localizedDescription)
			}
		}
	}

	static func migrateToiCloud() {
		// migrate old non-iCloud store
		if NSFileManager.defaultManager().fileExistsAtPath(localStoreURL.path!) {
			migrateStore(localStoreURL, options: localStoreOptions)
		}

		// migrate old iCloud store without iCloud Documents entitlement
		if let url = iCloudLocalStoreURL where NSFileManager.defaultManager().fileExistsAtPath(url.path!) {
			migrateStore(url, options: localStoreOptions)
		}
	}

	func registerForiCloudNotifications() {
		let notificationCenter = NSNotificationCenter.defaultCenter()

		notificationCenter.addObserver(self,
			selector: "storesWillChange:",
			name: NSPersistentStoreCoordinatorStoresWillChangeNotification,
			object: CoreDataManager.persistentStoreCoordinator)

		notificationCenter.addObserver(self,
			selector: "storesDidChange:",
			name: NSPersistentStoreCoordinatorStoresDidChangeNotification,
			object: CoreDataManager.persistentStoreCoordinator)

		notificationCenter.addObserver(self,
			selector: "persistentStoreDidImportUbiquitousContentChanges:",
			name: NSPersistentStoreDidImportUbiquitousContentChangesNotification,
			object: CoreDataManager.persistentStoreCoordinator)
	}

	@objc func persistentStoreDidImportUbiquitousContentChanges(changeNotification: NSNotification) {
		let context = CoreDataManager.managedObjectContext

		context.performBlock {
			context.mergeChangesFromContextDidSaveNotification(changeNotification)
		}
	}

	@objc func storesWillChange(notification: NSNotification) {
		let context = CoreDataManager.managedObjectContext

		context.performBlockAndWait {
			if context.hasChanges {
				var error: NSError?
				let success = context.save(&error)

				if let error = error where !success {
					// perform error handling
					NSLog("%@", error.localizedDescription)
				}
			}

			context.reset()
		}
	}

	@objc func storesDidChange(notification: NSNotification) {
	}

	//MARK: - Preconfigured Core Data Fetches

	static func fetchRequestForCarsInManagedObjectContext(moc: NSManagedObjectContext) -> NSFetchRequest {
		let fetchRequest = NSFetchRequest()

		// Entity name
		let entity = NSEntityDescription.entityForName("car", inManagedObjectContext:moc)
		fetchRequest.entity = entity
		fetchRequest.fetchBatchSize = 32

		// Sorting keys
		let sortDescriptor = NSSortDescriptor(key:"order", ascending:true)
		fetchRequest.sortDescriptors = [sortDescriptor]

		return fetchRequest
	}

	static func fetchRequestForEventsForCar(car: Car,
                                       andDate date: NSDate?,
                                dateComparator dateCompare: String,
                                     fetchSize: Int,
                        inManagedObjectContext moc: NSManagedObjectContext) -> NSFetchRequest {
		let fetchRequest = NSFetchRequest()

		// Entity name
		let entity = NSEntityDescription.entityForName("fuelEvent", inManagedObjectContext:moc)
		fetchRequest.entity = entity
		fetchRequest.fetchBatchSize = fetchSize

		// Predicates
		let parentPredicate = NSPredicate(format:"car == %@", car)

		if let date = date {
			let dateDescription = NSExpression(forConstantValue:date).description
			let datePredicate = NSPredicate(format:String(format:"timestamp %@ %@", dateCompare, dateDescription))

			fetchRequest.predicate = NSCompoundPredicate.andPredicateWithSubpredicates([parentPredicate, datePredicate])
		} else {
			fetchRequest.predicate = parentPredicate
		}

		// Sorting keys
		let sortDescriptor = NSSortDescriptor(key:"timestamp", ascending:false)
		fetchRequest.sortDescriptors = [sortDescriptor]

		return fetchRequest
	}

	public static func fetchRequestForEventsForCar(car: Car,
                                     afterDate date: NSDate?,
                                   dateMatches: Bool,
                        inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext) -> NSFetchRequest {
		return fetchRequestForEventsForCar(car,
                                     andDate:date,
                              dateComparator:dateMatches ? ">=" : ">",
                                   fetchSize:128,
                      inManagedObjectContext:moc)
	}

	public static func fetchRequestForEventsForCar(car: Car,
                                    beforeDate date: NSDate?,
                                   dateMatches: Bool,
                        inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext) -> NSFetchRequest {
		return fetchRequestForEventsForCar(car,
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
		var error: NSError?
		if !fetchedResultsController.performFetch(&error) {
			fatalError(error!.localizedDescription)
		}

		return fetchedResultsController
	}

	public static func objectsForFetchRequest(fetchRequest: NSFetchRequest, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext) -> [NSManagedObject] {
		var error: NSError?
		let fetchedObjects = moc.executeFetchRequest(fetchRequest, error:&error)

		if let error = error {
			fatalError(error.localizedDescription)
		}

		return fetchedObjects as! [NSManagedObject]
	}

	static func containsEventWithCar(car: Car, andDate date: NSDate, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext) -> Bool {
		let fetchRequest = NSFetchRequest()

		// Entity name
		let entity = NSEntityDescription.entityForName("fuelEvent", inManagedObjectContext:moc)
		fetchRequest.entity = entity
		fetchRequest.fetchBatchSize = 2

		// Predicates
		let parentPredicate = NSPredicate(format:"car == %@", car)

		let dateDescription = NSExpression(forConstantValue:date).description
		let datePredicate = NSPredicate(format:String(format:"timestamp == %@", dateDescription))

		fetchRequest.predicate = NSCompoundPredicate.andPredicateWithSubpredicates([parentPredicate, datePredicate])

		// Check whether fetch would reveal any event objects
		var error: NSError?
		let objectCount = moc.countForFetchRequest(fetchRequest, error:&error)

		if let error = error {
			fatalError(error.localizedDescription)
		}

		return objectCount > 0
	}

	//MARK: - Core Data Updates

	static func addToArchiveWithCar(car: Car, date: NSDate, distance: NSDecimalNumber, price: NSDecimalNumber, fuelVolume: NSDecimalNumber, filledUp: Bool, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext, var forceOdometerUpdate: Bool) -> FuelEvent {
		let zero = NSDecimalNumber.zero()

		// Convert distance and fuelvolume to SI units
		let fuelUnit     = car.ksFuelUnit
		let odometerUnit = car.ksOdometerUnit

		let liters        = Units.litersForVolume(fuelVolume, withUnit:fuelUnit)
		let kilometers    = Units.kilometersForDistance(distance, withUnit:odometerUnit)
		let pricePerLiter = Units.pricePerLiter(price, withUnit:fuelUnit)

		var inheritedCost       = zero
		var inheritedDistance   = zero
		var inheritedFuelVolume = zero

		// Compute inherited data from older element

		// Fetch older events
        let olderEvents = objectsForFetchRequest(fetchRequestForEventsForCar(car,
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
        let youngerEvents = objectsForFetchRequest(fetchRequestForEventsForCar(car,
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

            for var row = youngerEvents.count; row > 0; {
				let youngerEvent = youngerEvents[--row]

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
		let newEvent = NSEntityDescription.insertNewObjectForEntityForName("fuelEvent", inManagedObjectContext:moc) as! FuelEvent

		newEvent.car = car
		newEvent.timestamp = date
		newEvent.distance = kilometers
		newEvent.price = pricePerLiter
		newEvent.fuelVolume = liters

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

	static func removeEventFromArchive(event: FuelEvent!, inManagedObjectContext moc: NSManagedObjectContext = managedObjectContext, forceOdometerUpdate odometerUpdate: Bool) {
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
		let youngerEvents = objectsForFetchRequest(fetchRequestForEventsForCar(car,
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
						let youngerEvent = youngerEvents[--row]

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
					let youngerEvent = youngerEvents[--row]
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
		moc.deleteObject(event)
	}
}
