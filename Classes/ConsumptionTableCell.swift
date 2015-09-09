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

	required init() {
		self.coloredLabel = ConsumptionLabel(frame:CGRectZero)

		super.init()

		self.selectionStyle = .None

		self.coloredLabel.textAlignment             = .Center
		self.coloredLabel.adjustsFontSizeToFitWidth = true
		self.coloredLabel.backgroundColor           = UIColor.clearColor()
		self.coloredLabel.highlightedTextColor      = UIColor(white:0.5, alpha:1.0)
		self.coloredLabel.textColor                 = UIColor.blackColor()
		self.coloredLabel.translatesAutoresizingMaskIntoConstraints = false

		setupFonts()

		self.contentView.addSubview(self.coloredLabel)

		self.contentView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-[coloredLabel]-|", options: [], metrics: nil, views: ["coloredLabel" : coloredLabel]))
		self.contentView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-[coloredLabel]-|", options: [], metrics: nil, views: ["coloredLabel" : coloredLabel]))

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

	override func configureForData(dictionary: [NSObject:AnyObject], viewController: UIViewController, tableView: UITableView, indexPath: NSIndexPath) {
		super.configureForData(dictionary, viewController:viewController, tableView:tableView, indexPath:indexPath)

		self.coloredLabel.highlightStrings = dictionary["highlightStrings"] as? [String]
		self.coloredLabel.text             = dictionary["label"] as? String
	}

	override var accessibilityLabel: String? {
		get {
			return self.coloredLabel.text
		}
		set {
		}
	}
}
