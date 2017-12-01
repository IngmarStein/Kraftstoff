//
//  UITableView+Realm.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 03.12.17.
//

import UIKit
import RealmSwift

extension UITableView {
	func applyChanges<T>(changes: RealmCollectionChange<T>, with animation: UITableViewRowAnimation) {
		switch changes {
		case .initial: reloadData()
		case .update(_, let deletions, let insertions, let updates):
			let fromRow = { (row: Int) in return IndexPath(row: row, section: 0) }

			beginUpdates()
			insertRows(at: insertions.map(fromRow), with: animation)
			reloadRows(at: updates.map(fromRow), with: animation)
			deleteRows(at: deletions.map(fromRow), with: animation)
			endUpdates()
		case .error(let error): fatalError("\(error)")
		}
	}
}
