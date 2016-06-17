//
//  NumberEditTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

final class NumberEditTableCell: EditablePageCell {

	var numberFormatter: NumberFormatter!
	var alternateNumberFormatter: NumberFormatter?
	var textFieldSuffix: String?

	required init() {
		super.init()

		self.textField.keyboardType = .numberPad
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	private func updateTextFieldColorForValue(_ value: AnyObject?) {
		let valid: Bool
		if let validator = self.delegate as? EditablePageCellValidator {
			valid = validator.valueValid(value, identifier: self.valueIdentifier)
		} else {
			valid = true
		}
		self.textField.textColor = valid ? UIColor.black() : invalidTextColor
	}

	override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
		super.configureForData(dictionary, viewController: viewController, tableView: tableView, indexPath: indexPath)

		self.textFieldSuffix          = dictionary["suffix"] as? String
		self.numberFormatter          = dictionary["formatter"] as? NumberFormatter
		self.alternateNumberFormatter = dictionary["alternateFormatter"] as? NumberFormatter

		let value = self.delegate.valueForIdentifier(self.valueIdentifier) as? NSDecimalNumber
		if let value = value {
			self.textField.text = (alternateNumberFormatter ?? numberFormatter).string(from: value)

			if let suffix = self.textFieldSuffix {
				self.textField.text = self.textField.text!.appending(suffix)
			}
		} else {
			self.textField.text = ""
		}
		self.accessibilityIdentifier = self.valueIdentifier
		self.textField.accessibilityIdentifier = self.valueIdentifier

		updateTextFieldColorForValue(value)
	}

	// MARK: - UITextFieldDelegate

	// Implement special behavior for newly added characters
	@objc(textField:shouldChangeCharactersInRange:replacementString:)
	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		// Modify text
		var text = textField.text!
		guard let textValue = self.numberFormatter.number(from: text) as? NSDecimalNumber else {
			return false
		}
		var value = textValue
		let scale = NSDecimalNumber(mantissa: 1, exponent: Int16(self.numberFormatter.maximumFractionDigits), isNegative: false)

		if range.length == 0 {
			if range.location == text.characters.count && string.characters.count == 1 {
				// New character must be a digit
				let digit = NSDecimalNumber(string: string)

				if digit == .notANumber() {
					return false
				}

				// Special shift semantics when appending at end of string
				value = value << 1
				value = value + (digit / scale)
			} else {
				// Normal insert otherwise
				text  = (text as NSString).replacingCharacters(in: range, with: string)
				text  = text.replacingOccurrences(of: self.numberFormatter.groupingSeparator, with: "")
				value = self.numberFormatter.number(from: text) as! NSDecimalNumber
			}

			// Don't append when the result gets too large or below zero
			if value >= NSDecimalNumber(mantissa: 1, exponent: 6, isNegative: false) {
				return false
			}

			if value < .zero() {
				return false
			}
		} else if range.location >= text.characters.count - 1 {
			let handler = NSDecimalNumberHandler(roundingMode: .roundDown,
												 scale: Int16(self.numberFormatter.maximumFractionDigits),
                                                 raiseOnExactness: false,
                                                 raiseOnOverflow: false,
                                                 raiseOnUnderflow: false,
                                                 raiseOnDivideByZero: false)

			// Delete only the last digit
			value = value.multiplying(byPowerOf10: -1, withBehavior: handler)
			value = value.rounding(accordingToBehavior: handler)
		}

		textField.text = self.numberFormatter.string(from: value)

		// Tell delegate about new value
		self.delegate.valueChanged(value, identifier: self.valueIdentifier)
		updateTextFieldColorForValue(value)

		return false
	}

	// Reset to zero value on clear
	func textFieldShouldClear(_ textField: UITextField) -> Bool {
		let clearedValue = NSDecimalNumber.zero()

		if textField.isEditing {
			textField.text = numberFormatter.string(from: clearedValue)
		} else {
			textField.text = (alternateNumberFormatter ?? numberFormatter).string(from: clearedValue)

			if let suffix = self.textFieldSuffix {
				textField.text = textField.text!.appending(suffix)
			}
		}

		// Tell delegate about new value
		self.delegate.valueChanged(clearedValue, identifier: self.valueIdentifier)
		updateTextFieldColorForValue(clearedValue)

		return false
	}

	// Editing starts, remove suffix and switch to normal formatter
	func textFieldDidBeginEditing(_ textField: UITextField) {
		if let suffix = self.textFieldSuffix {
			if textField.text!.hasSuffix(suffix) {
				textField.text = textField.text!.substring(to: textField.text!.index(textField.text!.endIndex, offsetBy: -suffix.characters.count))
			}
		}

		if let alternateNumberFormatter = self.alternateNumberFormatter {
			let value = alternateNumberFormatter.number(from: textField.text!) as? NSDecimalNumber ?? .zero()
			textField.text = numberFormatter.string(from: value)
			self.delegate.valueChanged(value, identifier: self.valueIdentifier)
			updateTextFieldColorForValue(value)
		}
	}

	// Editing ends, switch back to alternate formatter and append specified suffix
	override func textFieldDidEndEditing(_ textField: UITextField) {
		super.textFieldDidEndEditing(textField)

		let value = self.numberFormatter.number(from: textField.text!) as? NSDecimalNumber ?? .zero()

		if let alternateNumberFormatter = self.alternateNumberFormatter {
			textField.text = alternateNumberFormatter.string(from: value)
		}

		if let suffix = self.textFieldSuffix {
			if !textField.text!.hasSuffix(suffix) {
				textField.text = textField.text!.appending(suffix)
			}
		}

		self.delegate.valueChanged(value, identifier: self.valueIdentifier)
		updateTextFieldColorForValue(value)
	}

}
