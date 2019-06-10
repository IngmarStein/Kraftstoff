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

	private func updateTextFieldColorForValue(_ value: Any?) {
		let valid: Bool
		if let validator = self.delegate as? EditablePageCellValidator {
			valid = validator.valueValid(value, identifier: self.valueIdentifier)
		} else {
			valid = true
		}
		self.textField.textColor = valid ? .label : invalidTextColor
	}

	override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
		super.configureForData(dictionary, viewController: viewController, tableView: tableView, indexPath: indexPath)

		self.textFieldSuffix          = dictionary["suffix"] as? String
		self.numberFormatter          = dictionary["formatter"] as? NumberFormatter
		self.alternateNumberFormatter = dictionary["alternateFormatter"] as? NumberFormatter

		let value = self.delegate.valueForIdentifier(self.valueIdentifier) as? Decimal
		if let value = value {
			self.textField.text = (alternateNumberFormatter ?? numberFormatter).string(from: value as NSNumber)

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
		guard let textValue = self.numberFormatter.number(from: text) as? Decimal else {
			return false
		}
		var value = textValue
		let scale = NSDecimalNumber(mantissa: 1, exponent: Int16(self.numberFormatter.maximumFractionDigits), isNegative: false) as Decimal

		if range.length == 0 {
			if range.location == text.count && string.count == 1 {
				// New character must be a digit
				guard let digit = Decimal(string: string) else { return false }

				if digit.isNaN {
					return false
				}

				// Special shift semantics when appending at end of string
				value = value << 1
				value += digit / scale
			} else {
				// Normal insert otherwise
				guard let editRange = Range(range, in: text) else { return false }
				text = text.replacingCharacters(in: editRange, with: string)
				text = text.replacingOccurrences(of: self.numberFormatter.groupingSeparator, with: "")
				guard let newValue = self.numberFormatter.number(from: text) as? Decimal else { return false }
				value = newValue
			}

			// Don't append when the result gets too large or below zero
			if value >= Decimal.fromLiteral(mantissa: 1, exponent: 6, isNegative: false) {
				return false
			}

			if value.isSignMinus {
				return false
			}
		} else if range.location >= text.count - 1 {
			let handler = NSDecimalNumberHandler(roundingMode: .down,
												 scale: Int16(self.numberFormatter.maximumFractionDigits),
                                                 raiseOnExactness: false,
                                                 raiseOnOverflow: false,
                                                 raiseOnUnderflow: false,
                                                 raiseOnDivideByZero: false)

			// Delete only the last digit
			value = (value as NSDecimalNumber).multiplying(byPowerOf10: -1, withBehavior: handler).rounding(accordingToBehavior: handler) as Decimal
		}

		textField.text = self.numberFormatter.string(from: value as NSNumber)

		// Tell delegate about new value
		self.delegate.valueChanged(value, identifier: self.valueIdentifier)
		updateTextFieldColorForValue(value)

		return false
	}

	// Reset to zero value on clear
	func textFieldShouldClear(_ textField: UITextField) -> Bool {
		let clearedValue = Decimal(0)

		if textField.isEditing {
			textField.text = numberFormatter.string(from: clearedValue as NSNumber)
		} else {
			textField.text = (alternateNumberFormatter ?? numberFormatter).string(from: clearedValue as NSNumber)

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
				textField.text = String(textField.text![..<textField.text!.index(textField.text!.endIndex, offsetBy: -suffix.count)])
			}
		}

		if let alternateNumberFormatter = self.alternateNumberFormatter {
			let value = alternateNumberFormatter.number(from: textField.text!) as? NSDecimalNumber ?? .zero
			textField.text = numberFormatter.string(from: value)
			self.delegate.valueChanged(value, identifier: self.valueIdentifier)
			updateTextFieldColorForValue(value)
		}
	}

	// Editing ends, switch back to alternate formatter and append specified suffix
	override func textFieldDidEndEditing(_ textField: UITextField) {
		super.textFieldDidEndEditing(textField)

		let value = self.numberFormatter.number(from: textField.text!) as? NSDecimalNumber ?? .zero

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
