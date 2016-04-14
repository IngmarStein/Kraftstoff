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
		self.keyLabel = UILabel(frame: CGRect.zero)
		self.valueSwitch = UISwitch(frame:CGRect.zero)
		self.valueLabel = UILabel(frame:CGRect.zero)

		super.init()

		// No highlight on touch
		self.selectionStyle = .none

		// Create switch
		valueSwitch.addTarget(self, action:#selector(SwitchTableCell.switchToggledAction(_:)), for: .valueChanged)
		valueSwitch.translatesAutoresizingMaskIntoConstraints = false

		self.contentView.addSubview(self.valueSwitch)

		// Configure the alternate textlabel

		valueLabel.textAlignment          = .right
		valueLabel.backgroundColor        = UIColor.clear()
		valueLabel.textColor              = UIColor.black()
		valueLabel.isHidden                 = true
		valueLabel.isUserInteractionEnabled = false
		valueLabel.translatesAutoresizingMaskIntoConstraints = false

		self.contentView.addSubview(self.valueLabel)

		// Configure the default textlabel
		keyLabel.textAlignment        = .left
		keyLabel.highlightedTextColor = UIColor.black()
		keyLabel.textColor            = UIColor.black()
		keyLabel.translatesAutoresizingMaskIntoConstraints = false

		self.contentView.addSubview(keyLabel)

		self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[keyLabel]-[valueSwitch]-|", options: [], metrics: nil, views: ["keyLabel" : keyLabel, "valueSwitch" : valueSwitch]))
		self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[keyLabel]-[valueLabel]-|", options: [], metrics: nil, views: ["keyLabel" : keyLabel, "valueLabel" : valueLabel]))
		self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[keyLabel]-|", options: [], metrics: nil, views: ["keyLabel" : keyLabel]))
		self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=4)-[valueSwitch]-(>=4)-|", options: [], metrics: nil, views: ["valueSwitch" : valueSwitch]))
		self.contentView.addConstraint(NSLayoutConstraint(item: valueSwitch, attribute: .centerY, relatedBy: .equal, toItem: contentView, attribute: .centerY, multiplier: 1.0, constant: 0.0))
		self.contentView.addConstraint(NSLayoutConstraint(item: valueLabel, attribute: .centerY, relatedBy: .equal, toItem: contentView, attribute: .centerY, multiplier: 1.0, constant: 0.0))

		setupFonts()
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SwitchTableCell.contentSizeCategoryDidChange(_:)), name: UIContentSizeCategoryDidChangeNotification, object: nil)
	}

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	func contentSizeCategoryDidChange(_ notification: NSNotification!) {
		setupFonts()
	}

	private func setupFonts() {
		self.valueLabel.font = UIFont.lightApplicationFontForStyle(textStyle: UIFontTextStyleCaption2)
		self.keyLabel.font = UIFont.applicationFontForStyle(textStyle: UIFontTextStyleCaption2)
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func configureForData(_ dictionary: [NSObject:AnyObject], viewController: UIViewController, tableView: UITableView, indexPath: NSIndexPath) {
		super.configureForData(dictionary, viewController:viewController, tableView:tableView, indexPath:indexPath)

		self.keyLabel.text   = dictionary["label"] as? String
		self.delegate        = viewController as? EditablePageCellDelegate
		self.valueIdentifier = dictionary["valueIdentifier"] as? String

		let isON = self.delegate?.valueForIdentifier(self.valueIdentifier)?.boolValue ?? false

		self.valueSwitch.isOn = isON
		self.valueLabel.text = NSLocalizedString(isON ? "Yes" : "No", comment:"")

		let showAlternate = self.delegate?.valueForIdentifier("showValueLabel")?.boolValue ?? false

		self.valueSwitch.isHidden =  showAlternate
		self.valueLabel.isHidden  = !showAlternate
	}

	func switchToggledAction(_ sender: UISwitch) {
		let isON = sender.isOn

		self.delegate?.valueChanged(isON, identifier:self.valueIdentifier)
		self.valueLabel.text = NSLocalizedString(isON ? "Yes" : "No", comment:"")
	}
}
