//
//  NumberEditTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

final class NumberEditTableCell: EditablePageCell {

	var numberFormatter: NSNumberFormatter!
	var alternateNumberFormatter: NSNumberFormatter?
	var textFieldSuffix: String?

	required init() {
		super.init()

		self.textField.keyboardType = .NumberPad
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	private func updateTextFieldColorForValue(value: AnyObject?) {
		let valid: Bool
		if let validator = self.delegate as? EditablePageCellValidator {
			valid = validator.valueValid(value, identifier: self.valueIdentifier)
		} else {
			valid = true
		}
		self.textField.textColor = valid ? UIColor.blackColor() : invalidTextColor
	}

	override func configureForData(dictionary: [NSObject:AnyObject], viewController: UIViewController, tableView: UITableView, indexPath: NSIndexPath) {
		super.configureForData(dictionary, viewController:viewController, tableView:tableView, indexPath:indexPath)

		self.textFieldSuffix          = dictionary["suffix"] as? String
		self.numberFormatter          = dictionary["formatter"] as? NSNumberFormatter
		self.alternateNumberFormatter = dictionary["alternateFormatter"] as? NSNumberFormatter

		let value = self.delegate.valueForIdentifier(self.valueIdentifier) as? NSDecimalNumber
		if let value = value {
			self.textField.text = (alternateNumberFormatter ?? numberFormatter).stringFromNumber(value)

			if let suffix = self.textFieldSuffix {
				self.textField.text = self.textField.text!.stringByAppendingString(suffix)
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
	func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
		// Modify text
		var text = textField.text!
		guard let textValue = self.numberFormatter.numberFromString(text) as? NSDecimalNumber else {
			return false
		}
		var value = textValue
		let scale = NSDecimalNumber(mantissa:1, exponent:Int16(self.numberFormatter.maximumFractionDigits), isNegative:false)

		if range.length == 0 {
			if range.location == text.characters.count && string.characters.count == 1 {
				// New character must be a digit
				let digit = NSDecimalNumber(string:string)

				if digit == NSDecimalNumber.notANumber() {
					return false
				}

				// Special shift semantics when appending at end of string
				value = value << 1
				value = value + (digit / scale)
			} else {
				// Normal insert otherwise
				text  = (text as NSString).stringByReplacingCharactersInRange(range, withString:string)
				text  = text.stringByReplacingOccurrencesOfString(self.numberFormatter.groupingSeparator, withString:"")
				value = self.numberFormatter.numberFromString(text) as! NSDecimalNumber
			}

			// Don't append when the result gets too large or below zero
			if value >= NSDecimalNumber(mantissa:1, exponent:6, isNegative:false) {
				return false
			}

			if value < NSDecimalNumber.zero() {
				return false
			}
		} else if range.location >= text.characters.count - 1 {
			let handler = NSDecimalNumberHandler(roundingMode:.RoundDown,
												 scale:Int16(self.numberFormatter.maximumFractionDigits),
                                                 raiseOnExactness:false,
                                                 raiseOnOverflow:false,
                                                 raiseOnUnderflow:false,
                                                 raiseOnDivideByZero:false)

			// Delete only the last digit
			value = value.decimalNumberByMultiplyingByPowerOf10(-1, withBehavior:handler)
			value = value.decimalNumberByRoundingAccordingToBehavior(handler)
		}

		textField.text = self.numberFormatter.stringFromNumber(value)

		// Tell delegate about new value
		self.delegate.valueChanged(value, identifier:self.valueIdentifier)
		updateTextFieldColorForValue(value)

		return false
	}

	// Reset to zero value on clear
	func textFieldShouldClear(textField: UITextField) -> Bool {
		let clearedValue = NSDecimalNumber.zero()

		if textField.editing {
			textField.text = numberFormatter.stringFromNumber(clearedValue)
		} else {
			textField.text = (alternateNumberFormatter ?? numberFormatter).stringFromNumber(clearedValue)

			if let suffix = self.textFieldSuffix {
				textField.text = textField.text!.stringByAppendingString(suffix)
			}
		}

		// Tell delegate about new value
		self.delegate.valueChanged(clearedValue, identifier:self.valueIdentifier)
		updateTextFieldColorForValue(clearedValue)

		return false
	}

	// Editing starts, remove suffix and switch to normal formatter
	func textFieldDidBeginEditing(textField: UITextField) {
		if let suffix = self.textFieldSuffix {
			if textField.text!.hasSuffix(suffix) {
				textField.text = textField.text!.substringToIndex(textField.text!.endIndex.advancedBy(-suffix.characters.count))
			}
		}

		if let alternateNumberFormatter = self.alternateNumberFormatter {
			let value = alternateNumberFormatter.numberFromString(textField.text!) as? NSDecimalNumber ?? NSDecimalNumber.zero()
			textField.text = numberFormatter.stringFromNumber(value)
			self.delegate.valueChanged(value, identifier:self.valueIdentifier)
			updateTextFieldColorForValue(value)
		}
	}

	// Editing ends, switch back to alternate formatter and append specified suffix
	override func textFieldDidEndEditing(textField: UITextField) {
		super.textFieldDidEndEditing(textField)

		let value = self.numberFormatter.numberFromString(textField.text!) as? NSDecimalNumber ?? NSDecimalNumber.zero()

		if let alternateNumberFormatter = self.alternateNumberFormatter {
			textField.text = alternateNumberFormatter.stringFromNumber(value)
		}

		if let suffix = self.textFieldSuffix {
			if !textField.text!.hasSuffix(suffix) {
				textField.text = textField.text!.stringByAppendingString(suffix)
			}
		}

		self.delegate.valueChanged(value, identifier:self.valueIdentifier)
		updateTextFieldColorForValue(value)
	}
}
