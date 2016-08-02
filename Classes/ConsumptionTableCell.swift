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
		self.coloredLabel = ConsumptionLabel(frame: .zero)

		super.init()

		self.selectionStyle = .none

		self.coloredLabel.textAlignment             = .center
		self.coloredLabel.adjustsFontSizeToFitWidth = true
		self.coloredLabel.backgroundColor           = .clear
		self.coloredLabel.highlightedTextColor      = #colorLiteral(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
		self.coloredLabel.textColor                 = .black
		self.coloredLabel.translatesAutoresizingMaskIntoConstraints = false
		self.coloredLabel.adjustsFontForContentSizeCategory = true
		self.coloredLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyleTitle3)

		self.contentView.addSubview(self.coloredLabel)

		self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[coloredLabel]-|", options: [], metrics: nil, views: ["coloredLabel": coloredLabel]))
		self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[coloredLabel]-|", options: [], metrics: nil, views: ["coloredLabel": coloredLabel]))
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
		super.configureForData(dictionary, viewController: viewController, tableView: tableView, indexPath: indexPath)

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
