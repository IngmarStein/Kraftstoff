//
//  TextEditTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

final class TextEditTableCell: EditablePageCell {
	static let DefaultMaximumTextFieldLength = 15

	private var maximumTextFieldLength = 0

	required init() {
		super.init()

		self.textField.keyboardType  = .default
		self.textField.returnKeyType = .next
		self.textField.allowCut      = true
		self.textField.allowPaste    = true
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
		super.configureForData(dictionary, viewController: viewController, tableView: tableView, indexPath: indexPath)

		if let autocapitalizeAll = dictionary["autocapitalizeAll"] as? Bool where autocapitalizeAll {
			self.textField.autocapitalizationType = .allCharacters
		} else {
			self.textField.autocapitalizationType = .words
		}
		if let maximumTextFieldLength = dictionary["maximumTextFieldLength"] as? Int {
			self.maximumTextFieldLength = maximumTextFieldLength
		} else {
			self.maximumTextFieldLength = TextEditTableCell.DefaultMaximumTextFieldLength
		}

		self.textField.text = self.delegate.valueForIdentifier(self.valueIdentifier) as? String
		self.textField.accessibilityIdentifier = self.valueIdentifier
	}

	// MARK: - UITextFieldDelegate

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		// Let the focus handler handle switching to next textfield
		if let focusHandler = self.delegate as? EditablePageCellFocusHandler {
			focusHandler.focusNextFieldForValueIdentifier(self.valueIdentifier)
		}

		return false
	}

	func textFieldShouldClear(_ textField: UITextField) -> Bool {
		// Propagate cleared value to the delegate
		self.delegate.valueChanged("", identifier: self.valueIdentifier)

		return true
	}

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		var newValue = (textField.text! as NSString).replacingCharacters(in: range, with: string)

		// Don't allow too large strings
		if maximumTextFieldLength > 0 && newValue.characters.count > maximumTextFieldLength {
			return false
		}

		if textField.textAlignment == .right {
			// http://stackoverflow.com/questions/19569688/right-aligned-uitextfield-spacebar-does-not-advance-cursor-in-ios-7
			newValue = newValue.replacingOccurrences(of: " ", with: "\u{00a0}")
		}

		// Do the update here and propagate the new value back to the delegate
		textField.text = newValue

		self.delegate.valueChanged(newValue as NSString, identifier: self.valueIdentifier)

		return false
	}

	override func textFieldDidEndEditing(_ textField: UITextField) {
		super.textFieldDidEndEditing(textField)

		textField.text = textField.text?.replacingOccurrences(of: "\u{00a0}", with: " ")
	}

}
