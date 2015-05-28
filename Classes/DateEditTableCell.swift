//
//  DateEditTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

class DateEditTableCell: EditableProxyPageCell {

	private var valueTimestamp: String?
	private var dateFormatter: NSDateFormatter!
	private var autoRefreshedDate = false
	private var datePicker: UIDatePicker
	private var datePickerConstraints = [NSLayoutConstraint]()

	required init() {
		datePicker = UIDatePicker()

		super.init()

		datePicker.datePickerMode = .DateAndTime
		datePicker.addTarget(self, action:"datePickerValueChanged:", forControlEvents:.ValueChanged)
		datePicker.setTranslatesAutoresizingMaskIntoConstraints(false)
		datePicker.hidden = true

		contentView.addSubview(datePicker)

		datePickerConstraints = NSLayoutConstraint.constraintsWithVisualFormat("V:[keyLabel]-[datePicker]-|", options: .allZeros, metrics: nil, views: ["keyLabel" : keyLabel, "datePicker" : datePicker]) as! [NSLayoutConstraint]

		NSNotificationCenter.defaultCenter().addObserver(self,
												selector:"significantTimeChange:",
													name:UIApplicationSignificantTimeChangeNotification,
												object:nil)
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
		self.textFieldProxy.textColor = valid ? UIColor.blackColor() : invalidTextColor
	}

	override func configureForData(dictionary: [NSObject:AnyObject], viewController: UIViewController, tableView: UITableView, indexPath: NSIndexPath) {
		super.configureForData(dictionary, viewController:viewController, tableView:tableView, indexPath:indexPath)

		self.valueTimestamp    = dictionary["valueTimestamp"] as? String
		self.dateFormatter     = dictionary["formatter"] as! NSDateFormatter
		self.autoRefreshedDate = dictionary["autorefresh"]?.boolValue ?? false

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

		refreshDatePickerWithDate(nil)
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

	private func refreshDatePickerWithDate(date: NSDate?) {
		let now = NSDate()

		// If not specified get the date to be selected from the delegate
		let effectiveDate = (date ?? self.delegate.valueForIdentifier(self.valueIdentifier) as? NSDate) ?? now

		datePicker.maximumDate = NSDate.dateWithoutSeconds(now)
		datePicker.setDate(NSDate.dateWithoutSeconds(effectiveDate), animated:false)

		// Immediate update when we are the first responder and notify delegate about new value too
		datePickerValueChanged(datePicker)
	}

	private func showDatePicker(show: Bool) {
		if show {
			contentView.addConstraints(datePickerConstraints)
			datePicker.hidden = false
		} else {
			contentView.removeConstraints(datePickerConstraints)
			datePicker.hidden = true
		}
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
		refreshDatePickerWithDate(selectedDate)

		showDatePicker(true)
	}

	override func textFieldDidEndEditing(textField: UITextField) {
		showDatePicker(false)
	}
}
