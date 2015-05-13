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

	var textField: EditablePageCellTextField
	var valueIdentifier: String!

	weak var delegate: EditablePageCellDelegate!

	required init() {
		// Create textfield
		self.textField = EditablePageCellTextField(frame:CGRectZero)

		super.init()

		self.textField.textAlignment            = .Right
		self.textField.autocapitalizationType   = .None
		self.textField.autocorrectionType       = .No
		self.textField.backgroundColor          = UIColor.clearColor()
		self.textField.clearButtonMode          = .WhileEditing
		self.textField.contentVerticalAlignment = .Center
		self.textField.autoresizingMask         = .FlexibleWidth
		self.textField.userInteractionEnabled   = false

		self.contentView.addSubview(self.textField)

		// Configure the default textlabel
		if let label = self.textLabel {
			label.textAlignment        = .Left
			label.highlightedTextColor = UIColor.blackColor()
			label.textColor            = UIColor.blackColor()
		}

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
		self.textField.font  = UIFont.lightApplicationFontForStyle(UIFontTextStyleCaption2)
		self.textLabel?.font = UIFont.applicationFontForStyle(UIFontTextStyleCaption2)
	}

	override var accessibilityLabel: String! {
		get {
			return String(format:"%@ %@", self.textLabel!.text!, self.textField.text)
		}
		set {

		}
	}

	override func configureForData(object: AnyObject!, viewController: AnyObject!, tableView: UITableView!, indexPath: NSIndexPath) {
		super.configureForData(object, viewController:viewController, tableView:tableView, indexPath:indexPath)

		let dictionary = object as! [NSObject:AnyObject]
		self.textLabel!.text  = dictionary["label"] as? String
		self.delegate         = viewController as? EditablePageCellDelegate
		self.valueIdentifier  = dictionary["valueIdentifier"] as! String

		self.textField.placeholder = dictionary["placeholder"] as? String
		self.textField.delegate    = self
	}

	override func layoutSubviews() {
		super.layoutSubviews()
    
		let leftOffset: CGFloat = 6.0
		let labelWidth = self.textLabel!.text!.sizeWithAttributes([NSFontAttributeName:self.textLabel!.font]).width
		let height     = self.contentView.bounds.size.height
		let width      = self.contentView.bounds.size.width

		self.textLabel!.frame = CGRect(x: leftOffset + margin, y: 0.0, width: labelWidth,                    height: height - 1)
		self.textField.frame  = CGRect(x: leftOffset + margin, y: 0.0, width: width - 2*margin - leftOffset, height: height - 1)
	}

	var invalidTextColor: UIColor? {
		return UIApplication.sharedApplication().delegate!.window!!.tintColor
	}

	//MARK: - UITextFieldDelegate

	func textFieldDidEndEditing(textField: UITextField) {
		textField.userInteractionEnabled = false
	}
}
