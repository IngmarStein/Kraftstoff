//
//  FetchOfflineChangesFromCoreDataOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/27/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CoreData
import CloudKit

class FetchOfflineChangesFromCoreDataOperation: Operation {

	var updatedManagedObjects: [NSManagedObjectID]
	var deletedRecordIDs: [CKRecordID]

	private let entityNames: [String]

	init(entityNames: [String]) {
		self.entityNames = entityNames

		self.updatedManagedObjects = []
		self.deletedRecordIDs = []

		super.init()
	}

	override func main() {
		print("FetchOfflineChangesFromCoreDataOperation.main()")

		let managedObjectContext = CoreDataManager.persistentContainer.newBackgroundContext()

		managedObjectContext.performAndWait {
			[unowned self] in

			let lastCloudKitSyncTimestamp = CloudKitManager.lastCloudKitSyncTimestamp

			for entityName in self.entityNames {
				self.fetchOfflineChangesForEntityName(entityName: entityName, lastCloudKitSyncTimestamp: lastCloudKitSyncTimestamp, managedObjectContext: managedObjectContext)
			}

			self.deletedRecordIDs = self.fetchDeletedRecordIDs(managedObjectContext: managedObjectContext)
		}
	}

	func fetchOfflineChangesForEntityName(entityName: String, lastCloudKitSyncTimestamp: Date, managedObjectContext: NSManagedObjectContext) {
		let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
		fetchRequest.predicate = NSPredicate(format: "lastUpdate > %@", lastCloudKitSyncTimestamp as NSDate)

		do {
			let fetchResults = try managedObjectContext.fetch(fetchRequest)
			let managedObjectIDs = fetchResults.flatMap { $0.objectID  }

			updatedManagedObjects.append(contentsOf: managedObjectIDs)
		} catch let error {
			print("Error fetching from CoreData: \(error.localizedDescription)")
		}
	}

	func fetchDeletedRecordIDs(managedObjectContext: NSManagedObjectContext) -> [CKRecordID] {
		let fetchRequest: NSFetchRequest<DeletedCloudKitObject> = DeletedCloudKitObject.fetchRequest()

		do {
			let fetchResults = try managedObjectContext.fetch(fetchRequest)
			return fetchResults.flatMap { $0.cloudKitRecordID }
		} catch let error {
			print("Error fetching from CoreData: \(error.localizedDescription)")
		}

		return []
	}

}
