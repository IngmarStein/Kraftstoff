//
//  DateEditTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

class DateEditTableCell: EditableProxyPageCell {

	var valueTimestamp: String?
	var dateFormatter: NSDateFormatter!
	var autoRefreshedDate = false

	required init() {
		super.init()

		NSNotificationCenter.defaultCenter().addObserver(self,
												selector:"significantTimeChange:",
													name:UIApplicationSignificantTimeChangeNotification,
												object:nil)
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	private func updateTextFieldColorForValue(value: AnyObject?) {
		let valid = self.delegate.valueValid?(value, identifier: self.valueIdentifier) ?? true
		self.textFieldProxy.textColor = valid ? UIColor.blackColor() : invalidTextColor
	}

	override func configureForData(object: AnyObject?, viewController: UIViewController, tableView: UITableView, indexPath: NSIndexPath) {
		super.configureForData(object, viewController:viewController, tableView:tableView, indexPath:indexPath)

		let dictionary = object as! [NSObject:AnyObject]

		self.valueTimestamp      = dictionary["valueTimestamp"] as? String
		self.dateFormatter       = dictionary["formatter"] as! NSDateFormatter
		self.autoRefreshedDate   = dictionary["autorefresh"]?.boolValue ?? false

		let value = self.delegate.valueForIdentifier(self.valueIdentifier) as? NSDate
		self.textFieldProxy.text = value.flatMap { self.dateFormatter.stringFromDate($0) } ?? ""
		updateTextFieldColorForValue(value)
	}

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	func significantTimeChange(object: AnyObject) {
		if let timestamp = self.valueTimestamp {
			self.delegate.valueChanged(NSDate.distantPast(), identifier:timestamp)
		}

		refreshDatePickerInputViewWithDate(nil, forceRecreation:true)
	}

	func datePickerValueChanged(sender: UIDatePicker) {
		let selectedDate = NSDate.dateWithoutSeconds(sender.date)

		if !(self.delegate.valueForIdentifier(self.valueIdentifier)?.isEqualToDate(selectedDate) ?? false) {
			self.textFieldProxy.text = self.dateFormatter.stringFromDate(selectedDate)
			self.delegate.valueChanged(selectedDate, identifier:self.valueIdentifier)
			if let timestamp = self.valueTimestamp {
				self.delegate.valueChanged(NSDate(), identifier:timestamp)
			}
			updateTextFieldColorForValue(selectedDate)
		}
	}

	private func refreshDatePickerInputViewWithDate(date: NSDate?, forceRecreation: Bool) {
		let now = NSDate()

		// Get previous input view
		var datePicker: UIDatePicker?

		if !forceRecreation {
			datePicker = self.textField.inputView as? UIDatePicker
		}

		// If not specified get the date to be selected from the delegate
		let effectiveDate = (date ?? self.delegate.valueForIdentifier(self.valueIdentifier) as? NSDate) ?? now

		// Create new datepicker with a correct 'today' flag
		if datePicker == nil {
			datePicker = UIDatePicker()
			datePicker!.datePickerMode = .DateAndTime

			datePicker!.addTarget(self, action:"datePickerValueChanged:", forControlEvents:.ValueChanged)

			self.textField.inputView = datePicker
		}

		datePicker!.maximumDate = NSDate.dateWithoutSeconds(now)
		datePicker!.setDate(NSDate.dateWithoutSeconds(effectiveDate), animated:false)

		// Immediate update when we are the first responder and notify delegate about new value too
		datePickerValueChanged(datePicker!)
		self.textField.reloadInputViews()
	}

	//MARK: - UITextFieldDelegate

	func textFieldDidBeginEditing(textField: UITextField) {
		// Optional:update selected value to current time when no change was done in the last 5 minutes
		var selectedDate: NSDate?

		if self.autoRefreshedDate {
			let now = NSDate()
			if let timestamp = self.valueTimestamp, lastChangeDate = self.delegate.valueForIdentifier(timestamp) as? NSDate {
				let noChangeInterval = now.timeIntervalSinceDate(lastChangeDate)
				if noChangeInterval >= 300 || noChangeInterval < 0 {
					selectedDate = now
				}
			} else {
				selectedDate = now
			}
		}

		// Update the date picker with the selected time
		refreshDatePickerInputViewWithDate(selectedDate, forceRecreation:false)
	}
}
