//
//  PageCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

class PageCell: UITableViewCell {
	class var reuseIdentifier: String {
		return String(self)
	}

	required init() {
		super.init(style: .Default, reuseIdentifier: self.dynamicType.reuseIdentifier)

		self.detailTextLabel?.hidden = true
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	func configureForData(object: [NSObject:AnyObject], viewController: UIViewController, tableView: UITableView, indexPath: NSIndexPath) {
		// Overridepoint for subclasses
	}

}
