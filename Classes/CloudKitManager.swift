//
//  CloudKitManager.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 22.06.16.
//
//

import UIKit
import CloudKit
import CoreData

final class CloudKitManager {

	private static let container = CKContainer.default()
	private static let recordZone = CKRecordZone.default()

	private static let privateChangesSubscriptionID = "private-changes"
	private static var privateDBChangeToken: CKServerChangeToken?
	private static var defaultZoneChangeToken: CKServerChangeToken?

	private static let syncTimestampKey = "ckSyncTimestamp"

	private static let operationQueue: OperationQueue = {
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = 1
		return queue
	}()

	private static var subscriptionIsLocallyCached: Bool {
		get {
			return UserDefaults.standard.bool(forKey: "ckPrivateSubscription")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "ckPrivateSubscription")
		}
	}

	static var lastCloudKitSyncTimestamp: Date {
		get {
			if let lastCloudKitSyncTimestamp = UserDefaults.standard.object(forKey: syncTimestampKey) as? Date {
				return lastCloudKitSyncTimestamp
			} else {
				return Date.distantPast
			}
		}
		set {
			UserDefaults.standard.set(newValue, forKey: syncTimestampKey)
		}
	}

	static func initialize() {
		container.accountStatus { (accountStatus, error) in
			switch accountStatus {
			case .available:
				initializeCloudKit()
			default:
				handleCloudKitUnavailable(accountStatus: accountStatus, error: error)
			}
		}
	}

	private static func initializeCloudKit() {
		print("CloudKit IS available")

		subscribeToChanges()

		importFromCoreData()
	}

	private static func importFromCoreData() {
		importFetchRequest(Car.fetchRequest())
		importFetchRequest(FuelEvent.fetchRequest())

		// this also saves the changes to CloudKit
		CoreDataManager.saveContext()
	}

	private static func importFetchRequest(_ fetchRequest: NSFetchRequest<NSFetchRequestResult>) {
		if let objects = try? CoreDataManager.managedObjectContext.fetch(fetchRequest) {
			for managedObject in objects {
				if let ckManagedObject = managedObject as? CloudKitManagedObject {
					// this sets the `cloudKitRecordName` field as a side-effect
					_ = ckManagedObject.asCloudKitRecord()
				}
			}
		}
	}

	private static func handleCloudKitUnavailable(accountStatus: CKAccountStatus, error: Error?) {
		var errorText = "Synchronization is disabled\n"
		if let error = error {
			print("handleCloudKitUnavailable ERROR: \(error)")
			print("An error occured: \(error.localizedDescription)")
			errorText += error.localizedDescription
		}

		switch accountStatus {
		case .restricted:
			errorText += "iCloud is not available due to restrictions"
		case .noAccount:
			errorText += "There is no CloudKit account setup.\nYou can setup iCloud in the Settings app."
		default:
			break
		}

		displayCloudKitNotAvailableError(errorText)
	}

	private static func displayCloudKitNotAvailableError(_ errorText: String) {
		guard !UserDefaults.standard.bool(forKey: "SuppressCloudKitError") else { return }

		DispatchQueue.main.async {
			let alertController = UIAlertController(title: "iCloud Synchronization Error", message: errorText, preferredStyle: .alert)

			let firstButtonAction = UIAlertAction(title: "OK", style: .default, handler: nil)
			alertController.addAction(firstButtonAction)

			let secondButtonAction = UIAlertAction(title: "Don't show again", style: .destructive) { _ in
				UserDefaults.standard.set(true, forKey: "SuppressCloudKitError")
			}
			alertController.addAction(secondButtonAction)

			UIApplication.kraftstoffAppDelegate.window?.rootViewController?.present(alertController, animated: true, completion: nil)
		}
	}

	static func subscribeToChanges() {
		guard !subscriptionIsLocallyCached else { return }

		let subscription = CKDatabaseSubscription(subscriptionID: privateChangesSubscriptionID)

		let notificationInfo = CKNotificationInfo()
		notificationInfo.shouldSendContentAvailable = true
		subscription.notificationInfo = notificationInfo

		let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription],
		                                               subscriptionIDsToDelete: nil)
		operation.modifySubscriptionsCompletionBlock = { (savedSubscriptions, deletedSubscriptionIDs, operationError) in
			if operationError == nil {
				subscriptionIsLocallyCached = true
			}
		}

		operation.qualityOfService = .utility
		container.privateCloudDatabase.add(operation)
	}

	static func fetchZoneChanges(_ callback: () -> Void) {
		let options = CKFetchRecordZoneChangesOptions()
		options.previousServerChangeToken = defaultZoneChangeToken
		let changesOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [recordZone.zoneID], optionsByRecordZoneID: [recordZone.zoneID: options])
		changesOperation.recordChangedBlock = { record in
		}
		//changesOperation.recordWithIDWasDeletedBlock = { ckRecordId in
		//}
		changesOperation.recordZoneChangeTokensUpdatedBlock = { (ckRecordZoneID, newChangeToken, data) in
			defaultZoneChangeToken = newChangeToken
		}
		changesOperation.recordZoneFetchCompletionBlock = { (ckRecordZoneID, newChangeToken, clientChangeTokenData, moreComing, error) in
			defaultZoneChangeToken = newChangeToken
		}
		changesOperation.fetchRecordZoneChangesCompletionBlock = { error in
		}
		container.privateCloudDatabase.add(changesOperation)
	}

	/*
	static func fetchPrivateChanges(_ callback: () -> Void) {
		let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: privateDBChangeToken)
		changesOperation.fetchAllChanges = true
		//changesOperation.recordZoneWithIDChangedBlock =
		//changesOperation.recordZoneWithIDWasDeletedBlock =
		changesOperation.changeTokenUpdatedBlock = {
			serverChangeToken in
			privateDBChangeToken = serverChangeToken
		}
		changesOperation.fetchDatabaseChangesCompletionBlock = {
			(newToken, more, error) in
			privateDBChangeToken = newToken
			fetchZoneChanges(callback)
		}
		container.privateCloudDatabase.add(changesOperation)
	}
	*/

	static func handlePush(_ userInfo: [AnyHashable: Any], completionHandler: (UIBackgroundFetchResult) -> Void) {
		let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

		if notification.subscriptionID == privateChangesSubscriptionID {
			fetchZoneChanges {
				completionHandler(.newData)
			}
		} else {
			completionHandler(.noData)
		}
	}

	static func save(modifiedRecords: [CKRecord], deletedRecordIDs: [CKRecordID]) {
		let modifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: modifiedRecords, recordIDsToDelete: deletedRecordIDs)
		modifyRecordsOperation.perRecordCompletionBlock = { (record, error) in
			if let error = error {
				print("CKModifyRecordsOperation error: \(error)")
			} else {
				print("Record modification successful for record: \(record)")
			}
		}
		modifyRecordsOperation.modifyRecordsCompletionBlock = { (savedRecords, deletedRecords, error) in
			if let error = error {
				print("CKModifyRecordsOperation error: \(error)")
			} else {
				if let deletedRecords = deletedRecords {
					for recordID in deletedRecords {
						print("DELETED: \(recordID)")
					}
				}
			}
		}
		container.privateCloudDatabase.add(modifyRecordsOperation)
	}

	private static func queueFullSyncOperations() {
		// 1. Fetch all the changes both locally and from each zone
		let fetchOfflineChangesFromCoreDataOperation = FetchOfflineChangesFromCoreDataOperation(entityNames: ["Car", "FuelEvent"])
		let fetchZoneChangesOperation = FetchRecordChangesForCloudKitZoneOperation(cloudKitZone: CloudKitManager.recordZone.zoneID)

		// 2. Process the changes after transfering
		let processSyncChangesOperation = ProcessSyncChangesOperation()
		let transferDataToProcessSyncChangesOperation = BlockOperation {
			[unowned processSyncChangesOperation, unowned fetchOfflineChangesFromCoreDataOperation, unowned fetchZoneChangesOperation] in

			processSyncChangesOperation.preProcessLocalChangedObjectIDs.append(contentsOf: fetchOfflineChangesFromCoreDataOperation.updatedManagedObjects)
			processSyncChangesOperation.preProcessLocalDeletedRecordIDs.append(contentsOf: fetchOfflineChangesFromCoreDataOperation.deletedRecordIDs)
			processSyncChangesOperation.preProcessServerChangedRecords.append(contentsOf: fetchZoneChangesOperation.changedRecords)
			processSyncChangesOperation.preProcessServerDeletedRecordIDs.append(contentsOf: fetchZoneChangesOperation.deletedRecordIDs)
		}

		// 3. Fetch records from the server that we need to change
		let fetchRecordsForModifiedObjectsOperation = FetchRecordsForModifiedObjectsOperation()
		let transferDataToFetchRecordsOperation = BlockOperation {
			[unowned fetchRecordsForModifiedObjectsOperation, unowned processSyncChangesOperation] in

			fetchRecordsForModifiedObjectsOperation.preFetchModifiedRecords = processSyncChangesOperation.postProcessChangesToServer
		}

		// 4. Modify records in the cloud
		let modifyRecordsFromManagedObjectsOperation = ModifyRecordsFromManagedObjectsOperation()
		let transferDataToModifyRecordsOperation = BlockOperation {
			[unowned fetchRecordsForModifiedObjectsOperation, unowned modifyRecordsFromManagedObjectsOperation, unowned processSyncChangesOperation] in

			if let fetchedRecordsDictionary = fetchRecordsForModifiedObjectsOperation.fetchedRecords {
				modifyRecordsFromManagedObjectsOperation.fetchedRecordsToModify = fetchedRecordsDictionary
			}
			modifyRecordsFromManagedObjectsOperation.preModifiedRecords = processSyncChangesOperation.postProcessChangesToServer

			// also set the recordIDsToDelete from what we processed
			modifyRecordsFromManagedObjectsOperation.recordIDsToDelete = processSyncChangesOperation.postProcessDeletesToServer
		}

		// 5. Modify records locally
		let saveChangedRecordsToCoreDataOperation = SaveChangedRecordsToCoreDataOperation()
		let transferDataToSaveChangesToCoreDataOperation = BlockOperation {
			[unowned saveChangedRecordsToCoreDataOperation, unowned processSyncChangesOperation] in

			saveChangedRecordsToCoreDataOperation.changedRecords = processSyncChangesOperation.postProcessChangesToCoreData
			saveChangedRecordsToCoreDataOperation.deletedRecordIDs = processSyncChangesOperation.postProcessDeletesToCoreData
		}

		// 6. Delete all of the DeletedCloudKitObjects
		let clearDeletedCloudKitObjectsOperation = ClearDeletedCloudKitObjectsOperation()

		// set dependencies
		// 1. transfering all the fetched data to process for conflicts
		transferDataToProcessSyncChangesOperation.addDependency(fetchOfflineChangesFromCoreDataOperation)
		transferDataToProcessSyncChangesOperation.addDependency(fetchZoneChangesOperation)

		// 2. processing the data onces its transferred
		processSyncChangesOperation.addDependency(transferDataToProcessSyncChangesOperation)

		// 3. fetching records changed local
		transferDataToFetchRecordsOperation.addDependency(processSyncChangesOperation)
		fetchRecordsForModifiedObjectsOperation.addDependency(transferDataToFetchRecordsOperation)

		// 4. modifying records in CloudKit
		transferDataToModifyRecordsOperation.addDependency(fetchRecordsForModifiedObjectsOperation)
		modifyRecordsFromManagedObjectsOperation.addDependency(transferDataToModifyRecordsOperation)

		// 5. modifying records in CoreData
		transferDataToSaveChangesToCoreDataOperation.addDependency(processSyncChangesOperation)
		saveChangedRecordsToCoreDataOperation.addDependency(transferDataToModifyRecordsOperation)

		// 6. clear the deleteCloudKitObjects
		clearDeletedCloudKitObjectsOperation.addDependency(saveChangedRecordsToCoreDataOperation)

		// add operations to the queue
		operationQueue.addOperation(fetchOfflineChangesFromCoreDataOperation)
		operationQueue.addOperation(fetchZoneChangesOperation)
		operationQueue.addOperation(transferDataToProcessSyncChangesOperation)
		operationQueue.addOperation(processSyncChangesOperation)
		operationQueue.addOperation(transferDataToFetchRecordsOperation)
		operationQueue.addOperation(fetchRecordsForModifiedObjectsOperation)
		operationQueue.addOperation(transferDataToModifyRecordsOperation)
		operationQueue.addOperation(modifyRecordsFromManagedObjectsOperation)
		operationQueue.addOperation(transferDataToSaveChangesToCoreDataOperation)
		operationQueue.addOperation(saveChangedRecordsToCoreDataOperation)
		operationQueue.addOperation(clearDeletedCloudKitObjectsOperation)
	}

}
