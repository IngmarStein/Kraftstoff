//
//  SaveChangedRecordsToCoreDataOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/17/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CloudKit
import CoreData

class SaveChangedRecordsToCoreDataOperation: Operation {

    var changedRecords: [CKRecord]
    var deletedRecordIDs: [CKRecordID]
    private var carRecords: [CKRecord]
    private var fuelEventRecords: [CKRecord]

    override init() {
        self.changedRecords = []
        self.deletedRecordIDs = []
        self.carRecords = []
        self.fuelEventRecords = []
    }

    override func main() {
        print("SaveChangedRecordsToCoreDataOperation.main()")

        // this is where we set the correct managedObjectContext
        let managedObjectContext = CoreDataManager.persistentContainer.newBackgroundContext()

        managedObjectContext.performAndWait {
            [unowned self] in

            // loop through changed records and filter our child records
            for record in self.changedRecords {
				if record.recordType == "car" {
					self.carRecords.append(record)
				} else {
					self.fuelEventRecords.append(record)
                }
            }

            // loop through all the changed root records first and insert or update them in core data
            for record in self.carRecords {
                self.saveRecordToCoreData(record, managedObjectContext: managedObjectContext)
            }

            // loop through all the changed child records next and insert or update them in core data
            for record in self.fuelEventRecords {
                self.saveRecordToCoreData(record, managedObjectContext: managedObjectContext)
            }

            // loop through all the deleted recordIDs and delete the objects from core data
            for recordID in self.deletedRecordIDs {
                self.deleteRecordFromCoreData(recordID: recordID, managedObjectContext: managedObjectContext)
            }

            // save the context
			CoreDataManager.saveBackgroundContext(managedObjectContext)
        }
    }

    private func saveRecordToCoreData(_ record: CKRecord, managedObjectContext: NSManagedObjectContext) {
        print("saveRecordToCoreData: \(record.recordType)")
		let fetchRequest = createFetchRequest(entityName: record.recordType, recordName: record.recordID.recordName)

        if let cloudKitManagedObject = fetchObject(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext) {
            print("UPDATE CORE DATA OBJECT")
            cloudKitManagedObject.updateFromRecord(record)
        } else {
            print("NEW CORE DATA OBJECT")
            let cloudKitManagedObject = createNewCloudKitManagedObject(entityName: record.recordType, managedObjectContext: managedObjectContext)
            cloudKitManagedObject.updateFromRecord(record)
        }
    }

    private func createFetchRequest(entityName: String, recordName: String) -> NSFetchRequest<NSFetchRequestResult> {
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
		fetchRequest.predicate = NSPredicate(format: "recordName LIKE[c] %@", recordName)
		return fetchRequest
    }

    private func fetchObject(fetchRequest: NSFetchRequest<NSFetchRequestResult>, managedObjectContext: NSManagedObjectContext) -> CloudKitManagedObject? {
        do {
            let fetchResults = try managedObjectContext.fetch(fetchRequest)

            guard fetchResults.count <= 1 else {
                fatalError("ERROR: Found more than one core data object with recordName")
            }

            if fetchResults.count == 1 {
                return fetchResults[0] as? CloudKitManagedObject
            }
        } catch let error {
            print("Error fetching from CoreData: \(error.localizedDescription)")
        }

        return nil
    }

	private func createNewCloudKitManagedObject(entityName: String, managedObjectContext: NSManagedObjectContext) -> CloudKitManagedObject {
		guard let newCloudKitManagedObject = NSEntityDescription.insertNewObject(forEntityName: entityName, into: managedObjectContext) as? CloudKitManagedObject else {
			fatalError("SaveChangedRecordsToCoreDataOperation: could not create object")
		}

		return newCloudKitManagedObject
	}

    private func deleteRecordFromCoreData(recordID: CKRecordID, managedObjectContext: NSManagedObjectContext) {
		let entityName = entityNameFromRecordName(recordID.recordName)
		let fetchRequest = createFetchRequest(entityName: entityName, recordName: recordID.recordName)

		if let cloudKitManagedObject = fetchObject(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext) {
			print("DELETE CORE DATA OBJECT: \(cloudKitManagedObject)")
			managedObjectContext.delete(cloudKitManagedObject as! NSManagedObject)
		}
    }

    private func entityNameFromRecordName(_ recordName: String) -> String {
		guard let index = recordName.index(of: ".") else {
			fatalError("ERROR - RecordID.recordName does not contain an entity prefix")
		}

		return String(recordName[..<index])
    }
}
