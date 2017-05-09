//
//  CloudKitManagedObject.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 23.06.16.
//
//

import Foundation
import CloudKit

protocol CloudKitRecordIDObject: class {

	var cloudKitRecordName: String? { get set }
	var cloudKitRecordID: CKRecordID { get }
	var cloudKitRecordType: String? { get }

}

protocol CloudKitManagedObject: CloudKitRecordIDObject {

	var lastUpdate: NSDate? { get set }

	func asCloudKitRecord() -> CKRecord
	func updateFromRecord(_ record: CKRecord)

}

extension CloudKitRecordIDObject {

	var cloudKitRecordID: CKRecordID {
		if cloudKitRecordName == nil {
			cloudKitRecordName = cloudKitRecordType! + "." + NSUUID().uuidString
		}
		return CKRecordID(recordName: cloudKitRecordName!)
	}

}
