//
//  FetchRecordChangesForCloudKitZoneOperation.swift
//

import CloudKit
import CoreData

class FetchRecordChangesForCloudKitZoneOperation: CKFetchRecordZoneChangesOperation {

	var changedRecords: [CKRecord]
	var deletedRecordIDs: [CKRecordID]
	var cloudKitZoneID: CKRecordZoneID
	var operationError: Error?

	init(cloudKitZone: CKRecordZoneID) {
		self.changedRecords = []
		self.deletedRecordIDs = []
		self.cloudKitZoneID = cloudKitZone

		super.init()

		let options = CKFetchRecordZoneChangesOptions()
		options.previousServerChangeToken = serverChangeToken

		self.recordZoneIDs = [cloudKitZone]
		self.optionsByRecordZoneID = [cloudKitZone: options]
	}

	override func main() {
		print("FetchCKRecordChangesForCloudKitZoneOperation.main() - \(String(describing: serverChangeToken))")

		setOperationBlocks()
		super.main()
	}

	// MARK: Set operation blocks
	func setOperationBlocks() {
		recordChangedBlock = {
			[unowned self]
			(record: CKRecord) -> Void in

			print("Record changed: \(record)")
			self.changedRecords.append(record)
		}

		recordWithIDWasDeletedBlock = {
			[unowned self]
			(recordID: CKRecordID, recordType: String) -> Void in

			print("Record deleted: \(recordID)")
			self.deletedRecordIDs.append(recordID)
		}

		recordZoneFetchCompletionBlock = {
			[unowned self]
			(recordZoneID: CKRecordZoneID, serverChangeToken: CKServerChangeToken?, clientChangeToken: Data?, moreComing: Bool, error: Error?) -> Void in

			if let operationError = error {
				print("SyncRecordChangesToCoreDataOperation resulted in an error: \(operationError)")
				self.operationError = operationError
			} else {
				self.serverChangeToken = serverChangeToken
			}
		}
	}

	// MARK: Change token user default methods
	var serverChangeToken: CKServerChangeToken? {
		get {
			let key = "ServerChangeTokenKey-\(cloudKitZoneID.zoneName)"

			if let encodedObjectData = UserDefaults.standard.object(forKey: key) as? Data {
				return NSKeyedUnarchiver.unarchiveObject(with: encodedObjectData) as? CKServerChangeToken
			} else {
				return nil
			}
		}

		set {
			let key = "ServerChangeTokenKey-\(cloudKitZoneID.zoneName)"
			if let serverChangeToken = newValue {
				UserDefaults.standard.set(NSKeyedArchiver.archivedData(withRootObject: serverChangeToken), forKey: key)
			} else {
				UserDefaults.standard.removeObject(forKey: key)
			}
		}
	}

}
