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
		return String(describing: self)
	}

	required init() {
		super.init(style: .default, reuseIdentifier: type(of: self).reuseIdentifier)

		self.detailTextLabel?.isHidden = true
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	func configureForData(_ object: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
		// Overridepoint for subclasses
	}

}
