//
//  TextEditTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

class TextEditTableCell: EditablePageCell {
	static let maximumTextFieldLength = 15

	required init() {
		super.init()

		self.textField.keyboardType  = .ASCIICapable
		self.textField.returnKeyType = .Next
		self.textField.allowCut      = true
		self.textField.allowPaste    = true
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func configureForData(object: AnyObject?, viewController: UIViewController, tableView: UITableView, indexPath: NSIndexPath) {
		super.configureForData(object, viewController:viewController, tableView:tableView, indexPath:indexPath)

		let dictionary = object as! [NSObject:AnyObject]
		if dictionary["autocapitalizeAll"]?.boolValue ?? false {
			self.textField.autocapitalizationType = .AllCharacters
		} else {
			self.textField.autocapitalizationType = .Words
		}

		self.textField.text = self.delegate.valueForIdentifier(self.valueIdentifier) as? String
	}

	//MARK: - UITextFieldDelegate

	func textFieldShouldReturn(textField: UITextField) -> Bool {
		// Let delegate handle switching to next textfield
		self.delegate.focusNextFieldForValueIdentifier?(self.valueIdentifier)

		return false
	}

	func textFieldShouldClear(textField: UITextField) -> Bool {
		// Propagate cleared value to the delegate
		self.delegate.valueChanged("", identifier:self.valueIdentifier)

		return true
	}

	func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
		let newValue = (textField.text as NSString).stringByReplacingCharactersInRange(range, withString:string)

		// Don't allow too large strings
		if count(newValue) > TextEditTableCell.maximumTextFieldLength {
			return false
		}

		// Do the update here and propagate the new value back to the delegate
		textField.text = newValue

		self.delegate.valueChanged(newValue, identifier:self.valueIdentifier)
		return false
	}

}
