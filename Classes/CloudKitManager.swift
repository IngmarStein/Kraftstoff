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

	private static var subscriptionIsLocallyCached: Bool {
		get {
			return UserDefaults.standard.bool(forKey: "ckPrivateSubscription")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "ckPrivateSubscription")
		}
	}

	static func initialize() {
		container.accountStatus {
			(accountStatus, error) in

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
		// TODO: full sync
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

			let secondButtonAction = UIAlertAction(title: "Don't show again", style: .destructive) {
				action in

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
		changesOperation.recordWithIDWasDeletedBlock = { ckRecordId in
		}
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
		// TODO: remove intermediary cast
		if let stringObjectUserInfo = userInfo as Any as? [String: NSObject] {
			let notification = CKNotification(fromRemoteNotificationDictionary: stringObjectUserInfo)

			if notification.subscriptionID == privateChangesSubscriptionID {
				fetchZoneChanges {
					completionHandler(.newData)
				}
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
				print("Record modification successful for recordID: \(record?.recordID)")
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

}
