//
//  DateEditTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

final class DateEditTableCell: EditableProxyPageCell {

	private var valueTimestamp: String?
	private var dateFormatter: DateFormatter!
	private var autoRefreshedDate = false
	private var datePicker: UIDatePicker

	required init() {
		datePicker = UIDatePicker()

		super.init()

		datePicker.datePickerMode = .dateAndTime
		datePicker.addTarget(self, action: #selector(DateEditTableCell.datePickerValueChanged(_:)), for: .valueChanged)
		datePicker.translatesAutoresizingMaskIntoConstraints = false
		datePicker.isHidden = true

		let stackView = UIStackView(arrangedSubviews: [datePicker])
		stackView.translatesAutoresizingMaskIntoConstraints = false
		stackView.axis = .vertical
		stackView.alignment = .center

		contentView.addSubview(stackView)

		let constraints = NSLayoutConstraint.constraints(withVisualFormat: "|-[stackView]-|", options: [], metrics: nil, views: ["stackView": stackView])
			+ NSLayoutConstraint.constraints(withVisualFormat: "V:[keyLabel]-[stackView]|", options: [], metrics: nil, views: ["keyLabel": keyLabel, "stackView": stackView])
		NSLayoutConstraint.activate(constraints)

		NotificationCenter.default.addObserver(self,
												selector: #selector(DateEditTableCell.significantTimeChange(_:)),
													name: Notification.Name.UIApplicationSignificantTimeChange,
												object: nil)
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func prepareForReuse() {
		super.prepareForReuse()

		showDatePicker(false)
	}

	private func updateTextFieldColorForValue(_ value: Any?) {
		let valid: Bool
		if let validator = self.delegate as? EditablePageCellValidator {
			valid = validator.valueValid(value, identifier: self.valueIdentifier)
		} else {
			valid = true
		}
		self.textFieldProxy.textColor = valid ? .black : invalidTextColor
	}

	override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
		super.configureForData(dictionary, viewController: viewController, tableView: tableView, indexPath: indexPath)

		self.valueTimestamp    = dictionary["valueTimestamp"] as? String
		self.dateFormatter     = dictionary["formatter"] as? DateFormatter
		self.autoRefreshedDate = dictionary["autorefresh"] as? Bool ?? false

		let value = self.delegate.valueForIdentifier(self.valueIdentifier) as? Date
		self.textFieldProxy.text = value.flatMap { self.dateFormatter.string(from: $0 as Date) } ?? ""
		updateTextFieldColorForValue(value)
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	func significantTimeChange(_ object: AnyObject) {
		if let timestamp = self.valueTimestamp {
			self.delegate.valueChanged(Date.distantPast, identifier: timestamp)
		}

		refreshDatePickerWithDate(nil)
	}

	func datePickerValueChanged(_ sender: UIDatePicker) {
		let selectedDate = Date.dateWithoutSeconds(sender.date)

		if let dateValue = self.delegate.valueForIdentifier(self.valueIdentifier) as? Date, dateValue != selectedDate {
			self.textFieldProxy.text = self.dateFormatter.string(from: selectedDate)
			self.delegate.valueChanged(selectedDate, identifier: self.valueIdentifier)
			if let timestamp = self.valueTimestamp {
				self.delegate.valueChanged(Date(), identifier: timestamp)
			}
			updateTextFieldColorForValue(selectedDate)
		}
	}

	private func refreshDatePickerWithDate(_ date: Date?) {
		let now = Date()

		// If not specified get the date to be selected from the delegate
		let effectiveDate = (date ?? self.delegate.valueForIdentifier(self.valueIdentifier) as? Date) ?? now

		datePicker.maximumDate = Date.dateWithoutSeconds(now)
		datePicker.setDate(Date.dateWithoutSeconds(effectiveDate), animated: false)

		// Immediate update when we are the first responder and notify delegate about new value too
		datePickerValueChanged(datePicker)
	}

	private func showDatePicker(_ show: Bool) {
		datePicker.isHidden = !show
	}

	// MARK: - UITextFieldDelegate

	func textFieldDidBeginEditing(_ textField: UITextField) {
		// Optional: update selected value to current time when no change was done in the last 5 minutes
		var selectedDate: Date?

		if self.autoRefreshedDate {
			let now = Date()
			if let timestamp = self.valueTimestamp, let lastChangeDate = self.delegate.valueForIdentifier(timestamp) as? Date {
				let noChangeInterval = now.timeIntervalSince(lastChangeDate)
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

	override func textFieldDidEndEditing(_ textField: UITextField) {
		showDatePicker(false)
	}

}
