//
//  ProcessOfflineChangesOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/27/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CoreData
import CloudKit
import Swift

class ProcessSyncChangesOperation: Operation {

	var preProcessLocalChangedObjectIDs: [NSManagedObjectID]
	var preProcessLocalDeletedRecordIDs: [CKRecordID]
	var preProcessServerChangedRecords: [CKRecord]
	var preProcessServerDeletedRecordIDs: [CKRecordID]

	var postProcessChangesToCoreData: [CKRecord]
	var postProcessChangesToServer: [CKRecord]
	var postProcessDeletesToCoreData: [CKRecordID]
	var postProcessDeletesToServer: [CKRecordID]

	private var changedCloudKitManagedObjects: [CloudKitManagedObject]

	override init() {
		self.preProcessLocalChangedObjectIDs = []
		self.preProcessLocalDeletedRecordIDs = []
		self.preProcessServerChangedRecords = []
		self.preProcessServerDeletedRecordIDs = []

		self.postProcessChangesToCoreData = []
		self.postProcessChangesToServer = []
		self.postProcessDeletesToCoreData = []
		self.postProcessDeletesToServer = []

		self.changedCloudKitManagedObjects = []

		super.init()
	}

	override func main() {
		print("ProcessSyncChangesOperation.main()")

		let managedObjectContext = CoreDataManager.persistentContainer.newBackgroundContext()

		managedObjectContext.performAndWait {
			[unowned self] in

			print("------------------------------------------")
			print("preProcessLocalChangedObjectIDs: \(self.preProcessLocalChangedObjectIDs.count)")
			print("preProcessLocalDeletedRecordIDs: \(self.preProcessLocalDeletedRecordIDs.count)")
			print("preProcessServerChangedRecords: \(self.preProcessServerChangedRecords.count)")
			print("preProcessServerDeletedRecordIDs: \(self.preProcessServerDeletedRecordIDs.count)")
			print("------------------------------------------")

			// first we need CloudKitManagedObjects from NSManagedObjectIDs
			self.changedCloudKitManagedObjects = CoreDataManager.fetchCloudKitManagedObjects(managedObjectContext: managedObjectContext, managedObjectIDs: self.preProcessLocalChangedObjectIDs)

			// deletes are the first thing we should process
			// anything deleted on the server should be removed from any local changes
			// anything deleted local should be removed from any server changes
			self.processServerDeletions(managedObjectContext: managedObjectContext)
			self.processLocalDeletions()

			// next process the conflicts
			self.processConflicts(managedObjectContext: managedObjectContext)

			// anything left in changedCloudKitManagedObjects needs to be added to postProcessChangesToServer
			let changedLocalRecords = self.changedCloudKitManagedObjects.flatMap { $0.asCloudKitRecord() }
			self.postProcessChangesToServer.append(contentsOf: changedLocalRecords)

			// anything left in preProcessServerChangedRecords needs to be added to postProcessChangesToCoreData
			self.postProcessChangesToCoreData.append(contentsOf: self.preProcessServerChangedRecords)

			print("postProcessChangesToServer: \(self.postProcessChangesToServer.count)")
			print("postProcessDeletesToServer: \(self.postProcessDeletesToServer.count)")
			print("postProcessChangesToCoreData: \(self.postProcessChangesToCoreData.count)")
			print("postProcessDeletesToCoreData: \(self.postProcessDeletesToCoreData.count)")
			print("------------------------------------------")

			CoreDataManager.saveBackgroundContext(managedObjectContext)
		}
	}

	// MARK: Process Deleted Objects
	func processServerDeletions(managedObjectContext: NSManagedObjectContext) {
		// anything deleted on the server needs to be removed from local change objects
		// and then added to the postProcessDeletesToCoreData array
		for deletedServerRecordID in preProcessServerDeletedRecordIDs {
			// do we have this record locally? We need to know so we can remove it from the changedCloudKitManagedObjects
			if let index = changedCloudKitManagedObjects.index(where: { $0.cloudKitRecordID.recordName == deletedServerRecordID.recordName }) {
				changedCloudKitManagedObjects.remove(at: index)
			}

			// make sure to add it to the postProcessDeletesToCoreData array so we delete it from core data
			postProcessDeletesToCoreData.append(deletedServerRecordID)
		}
	}

	func processLocalDeletions() {
		// anything deleted locally needs to be removed from the server change objects
		// and also added to the postProcessDeletesToServer array

		for deletedLocalRecordID in preProcessLocalDeletedRecordIDs {
			if let index = preProcessServerChangedRecords.index(where: { $0.recordID.recordName == deletedLocalRecordID.recordName}) {
				preProcessServerChangedRecords.remove(at: index)
			}

			// make sure to add it to the
			postProcessDeletesToServer.append(deletedLocalRecordID)
		}
	}

	// MARK: Process Conflicts
	func processConflicts(managedObjectContext: NSManagedObjectContext) {
		// make sets of the recordNames for both local and server changes
		let changedLocalRecordNamesArray = changedCloudKitManagedObjects.map { $0.cloudKitRecordID.recordName }
		let changedServerRecordNamesArray = preProcessServerChangedRecords.map { $0.recordID.recordName }
		let changedLocalRecordNamesSet = Set(changedLocalRecordNamesArray)
		let changedServerRecordNamesSet = Set(changedServerRecordNamesArray)

		// the interset of the sets are the recordNames we need to resolve conflicts with
		let conflictRecordNameSet = changedLocalRecordNamesSet.intersection(changedServerRecordNamesSet)

		for recordName in conflictRecordNameSet {
			resolveConflict(recordName: recordName, managedObjectContext: managedObjectContext)
		}
	}

	func resolveConflict(recordName: String, managedObjectContext: NSManagedObjectContext) {
		// only do the comparison if we have both objects. If we don't that's really bad
		guard let serverChangedRecordIndex = preProcessServerChangedRecords.index(where: { $0.recordID.recordName == recordName }),
			let localChangedObjectIndex = changedCloudKitManagedObjects.index(where: { $0.cloudKitRecordID.recordName == recordName }) else {
				fatalError("Could not find either the server record or local managed object to compare in conflict")
		}

		// get the objects from their respective arrays
		let serverChangedRecord = preProcessServerChangedRecords[serverChangedRecordIndex]
		let localChangedObject = changedCloudKitManagedObjects[localChangedObjectIndex]

		// also would be really bad if either of them don't have a lastUpdate property
		guard let serverChangedRecordLastUpdate = serverChangedRecord["lastUpdate"] as? Date,
			  let localChangedObjectLastUpdate = localChangedObject.lastUpdate as Date? else {
			fatalError("Could not find either the server record or local managed object lastUpdate property to compare in conflict")
		}

		// we need to remove the change from their respective preProcess arrays so they don't end up there later in the process
		preProcessServerChangedRecords.remove(at: serverChangedRecordIndex)
		changedCloudKitManagedObjects.remove(at: localChangedObjectIndex)

		// finally we check which time stamp is newer
		if serverChangedRecordLastUpdate > localChangedObjectLastUpdate {
			// server wins - add the record to those that will go to core data
			print("CONFLICT: \(recordName) - SERVER WINS. UPDATE COREDATA")
			postProcessChangesToCoreData.append(serverChangedRecord)
		} else if serverChangedRecordLastUpdate < localChangedObjectLastUpdate {
			// local wins - add the NSManagedObjectID to those that will go to the server
			print("CONFLICT: \(recordName) - LOCAL WINS. UPDATE CLOUDKIT")
			postProcessChangesToServer.append(localChangedObject.asCloudKitRecord())
		} else {
			// they're the same - we can just ignore these changes (curious how they would be the same ever though)
			print("CONFLICT: \(recordName) - SAME!! Will ignore")
		}
	}

}
