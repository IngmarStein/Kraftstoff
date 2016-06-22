//
//  CloudKitManager.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 22.06.16.
//
//

import UIKit
import CloudKit

final class CloudKitManager {
	private static let container = CKContainer.default()
	private static let recordZone = CKRecordZone.default()

	private static let privateChangesSubscriptionID = "private-changes"
	private static var privateDBChangeToken: CKServerChangeToken?
	private static var defaultZoneChangeToken: CKServerChangeToken?

	private static var subscriptionIsLocallyCached: Bool {
		get {
			return UserDefaults.standard().bool(forKey: "ckPrivateSubscription")
		}
		set {
			UserDefaults.standard().set(newValue, forKey: "ckPrivateSubscription")
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

	static func handlePush(_ userInfo: [NSObject: AnyObject], completionHandler: (UIBackgroundFetchResult) -> Void) {
		if let stringObjectUserInfo = userInfo as? [String: NSObject] {
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

}
