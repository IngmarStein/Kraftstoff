//
//  CloudKitManagedObject.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 23.06.16.
//
//

import Foundation
import CloudKit

protocol CloudKitManagedObject {

	var cloudKitRecordID: CKRecordID? { get }

	func asCloudKitRecord() -> CKRecord
	func updateFromRecord(_ record: CKRecord)

}
