//
//  ConsumptionTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

class ConsumptionTableCell: PageCell {

	private(set) var coloredLabel: ConsumptionLabel

	// Standard cell geometry
	private let ConsumptionRowHeight: CGFloat = 50.0
	private let cellHMargin: CGFloat          = 10.0
	private let cellVMargin: CGFloat          =  1.0

	var rowHeight: CGFloat {
		return ConsumptionRowHeight
	}

	override init() {
		self.coloredLabel = ConsumptionLabel(frame:CGRectZero)

		super.init()

		self.selectionStyle = .None

		self.coloredLabel.textAlignment             = .Center
		self.coloredLabel.adjustsFontSizeToFitWidth = true
		self.coloredLabel.font                      = UIFont(name:"HelveticaNeue", size:20)
		self.coloredLabel.minimumScaleFactor        = 12.0/self.coloredLabel.font.pointSize
		self.coloredLabel.backgroundColor           = UIColor.clearColor()
		self.coloredLabel.highlightedTextColor      = UIColor(white:0.5, alpha:1.0)
		self.coloredLabel.textColor                 = UIColor.blackColor()

		self.contentView.addSubview(self.coloredLabel)
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func configureForData(object: AnyObject!, viewController: AnyObject!, tableView: UITableView!, indexPath: NSIndexPath) {
		super.configureForData(object, viewController:viewController, tableView:tableView, indexPath:indexPath)

		let dictionary = object as! [NSObject:AnyObject]
		self.coloredLabel.highlightStrings = dictionary["highlightStrings"] as? [String]
		self.coloredLabel.text             = dictionary["label"] as? String
	}

	override var accessibilityLabel: String! {
		get {
			return self.coloredLabel.text
		}
		set {
		}
	}

	override func layoutSubviews() {
		super.layoutSubviews()

		let size = self.contentView.frame.size

		self.coloredLabel.frame = CGRect(x: cellHMargin, y: cellVMargin, width: size.width-2*cellHMargin, height: size.height-2*cellVMargin)
	}
}
