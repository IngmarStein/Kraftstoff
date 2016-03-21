//
//  EditablePageCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

protocol EditablePageCellDelegate : class {
	func valueForIdentifier(valueIdentifier: String) -> AnyObject?
	func valueChanged(newValue: AnyObject?, identifier: String)
}

protocol EditablePageCellValidator {
	func valueValid(newValue: AnyObject?, identifier: String) -> Bool
}

protocol EditablePageCellFocusHandler {
	func focusNextFieldForValueIdentifier(valueIdentifier: String)
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
		textField.translatesAutoresizingMaskIntoConstraints = false

		self.contentView.addSubview(textField)

		keyLabel.textAlignment        = .Left
		keyLabel.highlightedTextColor = UIColor.blackColor()
		keyLabel.textColor            = UIColor.blackColor()
		keyLabel.setContentHuggingPriority(750, forAxis: .Horizontal)
		keyLabel.setContentCompressionResistancePriority(1000, forAxis: .Horizontal)
		keyLabel.translatesAutoresizingMaskIntoConstraints = false

		contentView
		self.contentView.addSubview(keyLabel)

		let keyLabelBottomConstraint = NSLayoutConstraint(item: keyLabel, attribute: .Bottom, relatedBy: .Equal, toItem: contentView, attribute: .BottomMargin, multiplier: 1.0, constant: 0.0)
		keyLabelBottomConstraint.priority = 500
		self.contentView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-[keyLabel]-[textField]-|", options: [], metrics: nil, views: ["keyLabel" : keyLabel, "textField" : textField]))
		self.contentView.addConstraint(NSLayoutConstraint(item: keyLabel, attribute: .Top, relatedBy: .Equal, toItem: contentView, attribute: .TopMargin, multiplier: 1.0, constant: 0.0))
		self.contentView.addConstraint(keyLabelBottomConstraint)
		self.contentView.addConstraint(NSLayoutConstraint(item: textField, attribute: .Baseline, relatedBy: .Equal, toItem: keyLabel, attribute: .Baseline, multiplier: 1.0, constant: 0.0))

		setupFonts()
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(EditablePageCell.contentSizeCategoryDidChange(_:)), name: UIContentSizeCategoryDidChangeNotification, object: nil)
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

	override var accessibilityLabel: String? {
		get {
			return String(format:"%@ %@", self.keyLabel.text!, self.textField.text!)
		}
		set {

		}
	}

	override func configureForData(dictionary: [NSObject:AnyObject], viewController: UIViewController, tableView: UITableView, indexPath: NSIndexPath) {
		super.configureForData(dictionary, viewController:viewController, tableView:tableView, indexPath:indexPath)

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
