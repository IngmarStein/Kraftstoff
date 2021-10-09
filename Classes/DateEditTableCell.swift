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
                                           name: UIApplication.significantTimeChangeNotification,
                                           object: nil)
  }

  @available(*, unavailable)
  required init(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func prepareForReuse() {
    super.prepareForReuse()

    showDatePicker(false)
  }

  private func updateTextFieldColorForValue(_ value: Any?) {
    let valid: Bool
    if let validator = delegate as? EditablePageCellValidator {
      valid = validator.valueValid(value, identifier: valueIdentifier)
    } else {
      valid = true
    }
    textFieldProxy.textColor = valid ? .label : invalidTextColor
  }

  override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
    super.configureForData(dictionary, viewController: viewController, tableView: tableView, indexPath: indexPath)

    valueTimestamp = dictionary["valueTimestamp"] as? String
    dateFormatter = dictionary["formatter"] as? DateFormatter
    autoRefreshedDate = dictionary["autorefresh"] as? Bool ?? false

    let value = delegate.valueForIdentifier(valueIdentifier) as? Date
    textFieldProxy.text = value.flatMap { self.dateFormatter.string(from: $0 as Date) } ?? ""
    updateTextFieldColorForValue(value)
  }

  @objc func significantTimeChange(_: AnyObject) {
    if let timestamp = valueTimestamp {
      delegate.valueChanged(Date.distantPast, identifier: timestamp)
    }

    refreshDatePickerWithDate(nil)
  }

  @objc func datePickerValueChanged(_ sender: UIDatePicker) {
    let selectedDate = Date.dateWithoutSeconds(sender.date)

    if let dateValue = delegate.valueForIdentifier(valueIdentifier) as? Date, dateValue != selectedDate {
      textFieldProxy.text = dateFormatter.string(from: selectedDate)
      delegate.valueChanged(selectedDate, identifier: valueIdentifier)
      if let timestamp = valueTimestamp {
        delegate.valueChanged(Date(), identifier: timestamp)
      }
      updateTextFieldColorForValue(selectedDate)
    }
  }

  private func refreshDatePickerWithDate(_ date: Date?) {
    let now = Date()

    // If not specified get the date to be selected from the delegate
    let effectiveDate = (date ?? delegate.valueForIdentifier(valueIdentifier) as? Date) ?? now

    datePicker.maximumDate = Date.dateWithoutSeconds(now)
    datePicker.setDate(Date.dateWithoutSeconds(effectiveDate), animated: false)

    // Immediate update when we are the first responder and notify delegate about new value too
    datePickerValueChanged(datePicker)
  }

  private func showDatePicker(_ show: Bool) {
    datePicker.isHidden = !show
  }

  // MARK: - UITextFieldDelegate

  func textFieldDidBeginEditing(_: UITextField) {
    // Optional: update selected value to current time when no change was done in the last 5 minutes
    var selectedDate: Date?

    if autoRefreshedDate {
      let now = Date()
      if let timestamp = valueTimestamp, let lastChangeDate = delegate.valueForIdentifier(timestamp) as? Date {
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

  override func textFieldDidEndEditing(_: UITextField, reason _: UITextField.DidEndEditingReason) {
    showDatePicker(false)
  }
}
