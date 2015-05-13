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

	var rowHeight: CGFloat {
		return ConsumptionRowHeight
	}

	required init() {
		self.coloredLabel = ConsumptionLabel(frame:CGRectZero)

		super.init()

		self.selectionStyle = .None

		self.coloredLabel.textAlignment             = .Center
		self.coloredLabel.adjustsFontSizeToFitWidth = true
		self.coloredLabel.backgroundColor           = UIColor.clearColor()
		self.coloredLabel.highlightedTextColor      = UIColor(white:0.5, alpha:1.0)
		self.coloredLabel.textColor                 = UIColor.blackColor()
		self.coloredLabel.setTranslatesAutoresizingMaskIntoConstraints(false)

		setupFonts()

		self.contentView.addSubview(self.coloredLabel)

		self.contentView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-(10)-[coloredLabel]-(10)-|", options: .allZeros, metrics: nil, views: ["coloredLabel" : coloredLabel]))
		self.contentView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-(1)-[coloredLabel]-(1)-|", options: .allZeros, metrics: nil, views: ["coloredLabel" : coloredLabel]))

		NSNotificationCenter.defaultCenter().addObserver(self, selector: "contentSizeCategoryDidChange:", name: UIContentSizeCategoryDidChangeNotification, object: nil)
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	func contentSizeCategoryDidChange(notification: NSNotification!) {
		setupFonts()
	}
	private func setupFonts() {
		self.coloredLabel.font               = UIFont.applicationFontForStyle(UIFontTextStyleCaption1)
		self.coloredLabel.minimumScaleFactor = 12.0/self.coloredLabel.font.pointSize
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
}
