//
//  EditablePageCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

@objc protocol EditablePageCellDelegate {

	func valueForIdentifier(valueIdentifier: String) -> AnyObject?
	func valueChanged(newValue: AnyObject?, identifier: String)

	optional func valueValid(newValue: AnyObject?, identifier: String) -> Bool
	optional func focusNextFieldForValueIdentifier(valueIdentifier: String)

}

class EditablePageCell: PageCell, UITextFieldDelegate {

	private let margin = CGFloat(8.0)

	var keyLabel: UILabel
	var textField: EditablePageCellTextField
	var valueIdentifier: String!

	weak var delegate: EditablePageCellDelegate!

	required init() {
		// Create textfield
		textField = EditablePageCellTextField(frame:CGRectZero)
		keyLabel = UILabel(frame: CGRectZero)

		super.init()

		textField.textAlignment            = .Right
		textField.autocapitalizationType   = .None
		textField.autocorrectionType       = .No
		textField.backgroundColor          = UIColor.clearColor()
		textField.clearButtonMode          = .WhileEditing
		textField.contentVerticalAlignment = .Center
		textField.userInteractionEnabled   = false
		textField.setTranslatesAutoresizingMaskIntoConstraints(false)

		self.contentView.addSubview(self.textField)

		keyLabel.textAlignment        = .Left
		keyLabel.highlightedTextColor = UIColor.blackColor()
		keyLabel.textColor            = UIColor.blackColor()
		keyLabel.setTranslatesAutoresizingMaskIntoConstraints(false)

		self.contentView.addSubview(keyLabel)

		self.contentView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-[keyLabel]-[textField]-|", options: .allZeros, metrics: nil, views: ["keyLabel" : keyLabel, "textField" : textField]))
		self.contentView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-[keyLabel]-|", options: .allZeros, metrics: nil, views: ["keyLabel" : keyLabel]))
		self.contentView.addConstraint(NSLayoutConstraint(item: textField, attribute: .Baseline, relatedBy: .Equal, toItem: keyLabel, attribute: .Baseline, multiplier: 1.0, constant: 0.0))

		setupFonts()
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

	func setupFonts() {
		self.textField.font = UIFont.lightApplicationFontForStyle(UIFontTextStyleCaption2)
		self.keyLabel.font = UIFont.applicationFontForStyle(UIFontTextStyleCaption2)
	}

	override var accessibilityLabel: String! {
		get {
			return String(format:"%@ %@", self.keyLabel.text!, self.textField.text)
		}
		set {

		}
	}

	override func configureForData(object: AnyObject!, viewController: AnyObject!, tableView: UITableView!, indexPath: NSIndexPath) {
		super.configureForData(object, viewController:viewController, tableView:tableView, indexPath:indexPath)

		let dictionary = object as! [NSObject:AnyObject]
		self.keyLabel.text   = dictionary["label"] as? String
		self.delegate        = viewController as? EditablePageCellDelegate
		self.valueIdentifier = dictionary["valueIdentifier"] as! String

		self.textField.placeholder = dictionary["placeholder"] as? String
		self.textField.delegate    = self
	}

	var invalidTextColor: UIColor? {
		return UIApplication.sharedApplication().delegate!.window!!.tintColor
	}

	//MARK: - UITextFieldDelegate

	func textFieldDidEndEditing(textField: UITextField) {
		textField.userInteractionEnabled = false
	}
}
