//
//  PageCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

class PageCell: UITableViewCell {
	private static let PageCellDefaultRowHeight: CGFloat = 44.0

	class var rowHeight: CGFloat {
		return PageCellDefaultRowHeight
	}

	class var reuseIdentifier: String {
		return NSStringFromClass(self)
	}

	required init() {
		super.init(style: .Default, reuseIdentifier: self.dynamicType.reuseIdentifier)

		self.detailTextLabel?.hidden = true
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func prepareForReuse() {
		// Suppress default behaviour
	}

	func configureForData(object: AnyObject!, viewController: AnyObject!, tableView: UITableView!, indexPath: NSIndexPath) {
		// Overridepoint for subclasses
	}

}
