//
//  ConsumptionTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

final class ConsumptionTableCell: PageCell {

	private(set) var coloredLabel: ConsumptionLabel

	required init() {
		self.coloredLabel = ConsumptionLabel(frame:CGRect.zero)

		super.init()

		self.selectionStyle = .none

		self.coloredLabel.textAlignment             = .center
		self.coloredLabel.adjustsFontSizeToFitWidth = true
		self.coloredLabel.backgroundColor           = UIColor.clear()
		self.coloredLabel.highlightedTextColor      = UIColor(white:0.5, alpha:1.0)
		self.coloredLabel.textColor                 = UIColor.black()
		self.coloredLabel.translatesAutoresizingMaskIntoConstraints = false

		setupFonts()

		self.contentView.addSubview(self.coloredLabel)

		self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[coloredLabel]-|", options: [], metrics: nil, views: ["coloredLabel" : coloredLabel]))
		self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[coloredLabel]-|", options: [], metrics: nil, views: ["coloredLabel" : coloredLabel]))

		NSNotificationCenter.default().addObserver(self, selector: #selector(ConsumptionTableCell.contentSizeCategoryDidChange(notification:)), name: UIContentSizeCategoryDidChangeNotification, object: nil)
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	deinit {
		NSNotificationCenter.default().removeObserver(self)
	}

	func contentSizeCategoryDidChange(notification: NSNotification!) {
		setupFonts()
	}

	private func setupFonts() {
		self.coloredLabel.font               = UIFont.applicationFontForStyle(textStyle: UIFontTextStyleCaption1)
		self.coloredLabel.minimumScaleFactor = 12.0/self.coloredLabel.font.pointSize
	}

	override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: NSIndexPath) {
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
