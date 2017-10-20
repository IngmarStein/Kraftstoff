//
//  ModifyRecordsFromManagedObjectsOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/15/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CloudKit
import CoreData

class ModifyRecordsFromManagedObjectsOperation: CKModifyRecordsOperation {

	var fetchedRecordsToModify: [CKRecordID: CKRecord]?
	var preModifiedRecords: [CKRecord]?
	private let modifiedManagedObjectIDs: [NSManagedObjectID]?

    override init() {
        self.modifiedManagedObjectIDs = nil
        self.fetchedRecordsToModify = nil
        self.preModifiedRecords = nil

		super.init()
    }

    init(modifiedManagedObjectIDs: [NSManagedObjectID], deletedRecordIDs: [CKRecordID]) {
        // save off the modified objects and the fetch operation
        self.modifiedManagedObjectIDs = modifiedManagedObjectIDs
        self.fetchedRecordsToModify = nil

        super.init()

        // get the recordIDs for deleted objects
        recordIDsToDelete = deletedRecordIDs
    }

    override func main() {
        print("ModifyRecordsFromManagedObjectsOperation.main()")

        // setup the CKFetchRecordsOperation blocks
        setOperationBlocks()

        let managedObjectContext = CoreDataManager.persistentContainer.newBackgroundContext()

		managedObjectContext.performAndWait {
            // before we run we need to map the records we fetched in the dependent operation into our records to save
            let modifiedRecords: [CKRecord]
            if let modifiedManagedObjectIDs = self.modifiedManagedObjectIDs {
                modifiedRecords = self.modifyFetchedRecordsIDs(managedObjectContext: managedObjectContext, modifiedManagedObjectIDs: modifiedManagedObjectIDs)
            } else if let preModifiedRecords = self.preModifiedRecords {
                modifiedRecords = preModifiedRecords
            } else {
                modifiedRecords = []
            }

            if modifiedRecords.count > 0 {
                if self.recordsToSave == nil {
                    self.recordsToSave = modifiedRecords
                } else {
					self.recordsToSave?.append(contentsOf: modifiedRecords)
                }
            }

            print("ModifyRecordsFromManagedObjectsOperation.recordsToSave: \(String(describing: self.recordsToSave))")
            print("ModifyRecordsFromManagedObjectsOperation.recordIDsToDelete: \(String(describing: self.recordIDsToDelete))")

            super.main()
        }
    }

    private func modifyFetchedRecordsIDs(managedObjectContext: NSManagedObjectContext, modifiedManagedObjectIDs: [NSManagedObjectID]) -> [CKRecord] {
        guard let fetchedRecords = fetchedRecordsToModify else {
            return []
        }

        var modifiedRecords: [CKRecord] = []

        let modifiedManagedObjects = CoreDataManager.fetchCloudKitManagedObjects(managedObjectContext: managedObjectContext, managedObjectIDs: modifiedManagedObjectIDs)
        for cloudKitManagedObject in modifiedManagedObjects {
			let recordID = cloudKitManagedObject.cloudKitRecordID
            if let record = fetchedRecords[recordID] {
                modifiedRecords.append(cloudKitManagedObject.asCloudKitRecord())
            }
        }

        return modifiedRecords
    }

    private func setOperationBlocks() {
        perRecordCompletionBlock = {
            (record: CKRecord?, error: Error?) -> Void in

            if let error = error {
                print("ModifyRecordsFromManagedObjectsOperation.perRecordCompletionBlock error: \(error)")
            } else {
                print("Record modification successful for recordID: \(String(describing: record?.recordID))")
            }
        }

        modifyRecordsCompletionBlock = {
            (savedRecords: [CKRecord]?, deletedRecords: [CKRecordID]?, error: Error?) -> Void in

            if let error = error {
                print("ModifyRecordsFromManagedObjectsOperation.modifyRecordsCompletionBlock error: \(error)")
            } else if let deletedRecords = deletedRecords {
                for recordID in deletedRecords {
                    print("DELETED: \(recordID)")
                }
            }
            CloudKitManager.lastCloudKitSyncTimestamp = Date()
            print("ModifyRecordsFromManagedObjectsOperation modifyRecordsCompletionBlock")
        }
    }

}
