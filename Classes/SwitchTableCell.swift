//
//  SwitchTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

final class SwitchTableCell: PageCell {
	private let margin : CGFloat = 8.0

	var keyLabel: UILabel
	var valueSwitch: UISwitch
	var valueLabel: UILabel
	var valueIdentifier: String!

	weak var delegate: EditablePageCellDelegate?

	required init () {
		self.keyLabel = UILabel(frame: .zero)
		self.valueSwitch = UISwitch(frame: .zero)
		self.valueLabel = UILabel(frame: .zero)

		super.init()

		// No highlight on touch
		self.selectionStyle = .none

		// Create switch
		valueSwitch.addTarget(self, action:#selector(SwitchTableCell.switchToggledAction(_:)), for: .valueChanged)
		valueSwitch.translatesAutoresizingMaskIntoConstraints = false

		self.contentView.addSubview(self.valueSwitch)

		// Configure the alternate textlabel

		valueLabel.textAlignment            = .right
		valueLabel.backgroundColor          = .clear()
		valueLabel.textColor                = .black()
		valueLabel.isHidden                 = true
		valueLabel.isUserInteractionEnabled = false
		valueLabel.translatesAutoresizingMaskIntoConstraints = false

		self.contentView.addSubview(self.valueLabel)

		// Configure the default textlabel
		keyLabel.textAlignment        = .left
		keyLabel.highlightedTextColor = .black()
		keyLabel.textColor            = .black()
		keyLabel.translatesAutoresizingMaskIntoConstraints = false

		self.contentView.addSubview(keyLabel)

		self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[keyLabel]-[valueSwitch]-|", options: [], metrics: nil, views: ["keyLabel" : keyLabel, "valueSwitch" : valueSwitch]))
		self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[keyLabel]-[valueLabel]-|", options: [], metrics: nil, views: ["keyLabel" : keyLabel, "valueLabel" : valueLabel]))
		self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[keyLabel]-|", options: [], metrics: nil, views: ["keyLabel" : keyLabel]))
		self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=4)-[valueSwitch]-(>=4)-|", options: [], metrics: nil, views: ["valueSwitch" : valueSwitch]))
		self.contentView.addConstraint(NSLayoutConstraint(item: valueSwitch, attribute: .centerY, relatedBy: .equal, toItem: contentView, attribute: .centerY, multiplier: 1.0, constant: 0.0))
		self.contentView.addConstraint(NSLayoutConstraint(item: valueLabel, attribute: .centerY, relatedBy: .equal, toItem: contentView, attribute: .centerY, multiplier: 1.0, constant: 0.0))

		setupFonts()
		NotificationCenter.default().addObserver(self, selector: #selector(SwitchTableCell.contentSizeCategoryDidChange(_:)), name: Notification.Name.UIContentSizeCategoryDidChange, object: nil)
	}

	deinit {
		NotificationCenter.default().removeObserver(self)
	}

	func contentSizeCategoryDidChange(_ notification: NSNotification!) {
		setupFonts()
	}

	private func setupFonts() {
		self.valueLabel.font = UIFont.lightApplicationFontForStyle(UIFontTextStyleCaption2)
		self.keyLabel.font = UIFont.applicationFontForStyle(UIFontTextStyleCaption2)
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
		super.configureForData(dictionary, viewController:viewController, tableView: tableView, indexPath: indexPath)

		self.keyLabel.text   = dictionary["label"] as? String
		self.delegate        = viewController as? EditablePageCellDelegate
		self.valueIdentifier = dictionary["valueIdentifier"] as? String

		let isOn = self.delegate?.valueForIdentifier(self.valueIdentifier) as? Bool ?? false

		self.valueSwitch.isOn = isOn
		self.valueLabel.text = NSLocalizedString(isOn ? "Yes" : "No", comment: "")

		let showAlternate = self.delegate?.valueForIdentifier("showValueLabel") as? Bool ?? false

		self.valueSwitch.isHidden =  showAlternate
		self.valueLabel.isHidden  = !showAlternate
	}

	func switchToggledAction(_ sender: UISwitch) {
		let isOn = sender.isOn

		self.delegate?.valueChanged(isOn as NSNumber, identifier: self.valueIdentifier)
		self.valueLabel.text = NSLocalizedString(isOn ? "Yes" : "No", comment: "")
	}
}
