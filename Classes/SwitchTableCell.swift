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

	var valueSwitch: UISwitch
	var valueLabel: UILabel
	var valueIdentifier: String!

	weak var delegate: EditablePageCellDelegate?

	required init () {
		self.valueSwitch = UISwitch(frame:CGRectZero)
		self.valueLabel = UILabel(frame:CGRectZero)

		super.init()

		// No highlight on touch
		self.selectionStyle = .None

		// Create switch
		self.valueSwitch.addTarget(self, action:"switchToggledAction:", forControlEvents:.ValueChanged)

		self.contentView.addSubview(self.valueSwitch)

		// Configure the alternate textlabel

		self.valueLabel.textAlignment    = .Right
		self.valueLabel.autoresizingMask = .FlexibleWidth
		self.valueLabel.backgroundColor  = UIColor.clearColor()
		self.valueLabel.textColor        = UIColor.blackColor()

		self.valueLabel.hidden                 = true
		self.valueLabel.userInteractionEnabled = false

		self.contentView.addSubview(self.valueLabel)

		// Configure the default textlabel
		if let label = self.textLabel {
			label.textAlignment        = .Left
			label.highlightedTextColor = UIColor.blackColor()
			label.textColor            = UIColor.blackColor()
		}

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
		self.textLabel?.font = UIFont.applicationFontForStyle(UIFontTextStyleCaption2)
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func configureForData(object: AnyObject!, viewController: AnyObject!, tableView: UITableView!, indexPath: NSIndexPath) {
		super.configureForData(object, viewController:viewController, tableView:tableView, indexPath:indexPath)

		let dictionary = object as! [String:AnyObject]
		self.textLabel?.text  = dictionary["label"] as? String
		self.delegate         = viewController as? EditablePageCellDelegate
		self.valueIdentifier  = dictionary["valueIdentifier"] as? String

		let isON = self.delegate?.valueForIdentifier(self.valueIdentifier)?.boolValue ?? false

		self.valueSwitch.on = isON
		self.valueLabel.text = NSLocalizedString(isON ? "Yes" : "No", comment:"")

		let showAlternate = self.delegate?.valueForIdentifier("showValueLabel")?.boolValue ?? false

		self.valueSwitch.hidden =  showAlternate
		self.valueLabel.hidden  = !showAlternate
	}

	override func layoutSubviews() {
		super.layoutSubviews()

		let leftOffset = CGFloat(6.0)

		// Text label on the left
		let labelWidth = self.textLabel!.text!.sizeWithAttributes([NSFontAttributeName:self.textLabel!.font]).width
		let height     = self.contentView.bounds.size.height
		let width      = self.contentView.bounds.size.width

		self.textLabel!.frame = CGRect(x:margin + leftOffset, y:0.0, width:labelWidth, height:height - 1)

		// UISwitch
		let valueFrame = self.valueSwitch.frame
		self.valueSwitch.frame = CGRect(x: width - margin - valueFrame.size.width,
										y: floor ((height - valueFrame.size.height)/2),
										width: valueFrame.size.width,
										height: valueFrame.size.height)

		// Alternate for UISwitch
		let alternateHeight = self.valueLabel.text!.sizeWithAttributes([NSFontAttributeName:self.valueLabel.font]).height
		self.valueLabel.frame = CGRect(x: width - margin - 100.0, y: floor ((height - alternateHeight)/2), width: 100.0, height: alternateHeight)
	}

	func switchToggledAction(sender: UISwitch) {
		let isON = sender.on

		self.delegate?.valueChanged(isON, identifier:self.valueIdentifier)
		self.valueLabel.text = NSLocalizedString(isON ? "Yes" : "No", comment:"")
	}
}
