//
//  ClearDeletedCloudKitObjectsOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/27/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CoreData

class ClearDeletedCloudKitObjectsOperation: Operation {

	override func main() {
		print("ClearDeletedCloudKitObjectsOperation.main()")

		let managedObjectContext = CoreDataManager.persistentContainer.newBackgroundContext()

		managedObjectContext.performAndWait {
			let fetchRequest: NSFetchRequest<NSFetchRequestResult> = DeletedCloudKitObject.fetchRequest()
			let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

			do {
				try managedObjectContext.execute(deleteRequest)
			} catch let error {
				print("Error deleting from CoreData: \(error.localizedDescription)")
			}

			CoreDataManager.saveBackgroundContext(managedObjectContext)
		}
	}

}
