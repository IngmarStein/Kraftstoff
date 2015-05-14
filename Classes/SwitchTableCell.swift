//
//  SwitchTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

class SwitchTableCell: PageCell {
	private let margin : CGFloat = 8.0

	var keyLabel: UILabel
	var valueSwitch: UISwitch
	var valueLabel: UILabel
	var valueIdentifier: String!

	weak var delegate: EditablePageCellDelegate?

	required init () {
		self.keyLabel = UILabel(frame: CGRectZero)
		self.valueSwitch = UISwitch(frame:CGRectZero)
		self.valueLabel = UILabel(frame:CGRectZero)

		super.init()

		// No highlight on touch
		self.selectionStyle = .None

		// Create switch
		valueSwitch.addTarget(self, action:"switchToggledAction:", forControlEvents:.ValueChanged)
		valueSwitch.setTranslatesAutoresizingMaskIntoConstraints(false)

		self.contentView.addSubview(self.valueSwitch)

		// Configure the alternate textlabel

		valueLabel.textAlignment          = .Right
		valueLabel.backgroundColor        = UIColor.clearColor()
		valueLabel.textColor              = UIColor.blackColor()
		valueLabel.hidden                 = true
		valueLabel.userInteractionEnabled = false
		valueLabel.setTranslatesAutoresizingMaskIntoConstraints(false)

		self.contentView.addSubview(self.valueLabel)

		// Configure the default textlabel
		keyLabel.textAlignment        = .Left
		keyLabel.highlightedTextColor = UIColor.blackColor()
		keyLabel.textColor            = UIColor.blackColor()
		keyLabel.setTranslatesAutoresizingMaskIntoConstraints(false)

		self.contentView.addSubview(keyLabel)

		self.contentView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-[keyLabel]-[valueSwitch]-|", options: .allZeros, metrics: nil, views: ["keyLabel" : keyLabel, "valueSwitch" : valueSwitch]))
		self.contentView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-[keyLabel]-[valueLabel]-|", options: .allZeros, metrics: nil, views: ["keyLabel" : keyLabel, "valueLabel" : valueLabel]))
		self.contentView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-[keyLabel]-|", options: .allZeros, metrics: nil, views: ["keyLabel" : keyLabel]))
		self.contentView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-(>=4)-[valueSwitch]-(>=4)-|", options: .allZeros, metrics: nil, views: ["valueSwitch" : valueSwitch]))
		self.contentView.addConstraint(NSLayoutConstraint(item: valueSwitch, attribute: .CenterY, relatedBy: .Equal, toItem: contentView, attribute: .CenterY, multiplier: 1.0, constant: 0.0))
		self.contentView.addConstraint(NSLayoutConstraint(item: valueLabel, attribute: .CenterY, relatedBy: .Equal, toItem: contentView, attribute: .CenterY, multiplier: 1.0, constant: 0.0))

		setupFonts()
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "contentSizeCategoryDidChange:", name: UIContentSizeCategoryDidChangeNotification, object: nil)
	}

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	func contentSizeCategoryDidChange(notification: NSNotification!) {
		setupFonts()
	}

	private func setupFonts() {
		self.valueLabel.font = UIFont.lightApplicationFontForStyle(UIFontTextStyleCaption2)
		self.keyLabel.font = UIFont.applicationFontForStyle(UIFontTextStyleCaption2)
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func configureForData(object: AnyObject!, viewController: AnyObject!, tableView: UITableView!, indexPath: NSIndexPath) {
		super.configureForData(object, viewController:viewController, tableView:tableView, indexPath:indexPath)

		let dictionary = object as! [String:AnyObject]
		self.keyLabel.text   = dictionary["label"] as? String
		self.delegate        = viewController as? EditablePageCellDelegate
		self.valueIdentifier = dictionary["valueIdentifier"] as? String

		let isON = self.delegate?.valueForIdentifier(self.valueIdentifier)?.boolValue ?? false

		self.valueSwitch.on = isON
		self.valueLabel.text = NSLocalizedString(isON ? "Yes" : "No", comment:"")

		let showAlternate = self.delegate?.valueForIdentifier("showValueLabel")?.boolValue ?? false

		self.valueSwitch.hidden =  showAlternate
		self.valueLabel.hidden  = !showAlternate
	}

	func switchToggledAction(sender: UISwitch) {
		let isON = sender.on

		self.delegate?.valueChanged(isON, identifier:self.valueIdentifier)
		self.valueLabel.text = NSLocalizedString(isON ? "Yes" : "No", comment:"")
	}
}
