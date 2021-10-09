//
//  PickerTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

final class PickerTableCell: EditableProxyPageCell, UIPickerViewDataSource, UIPickerViewDelegate {
  var pickerView: UIPickerView
  var pickerLabels: [String]!
  var pickerShortLabels: [String]?

  private let pickerViewCellWidth: CGFloat = 290.0
  private let pickerViewCellHeight: CGFloat = 44.0

  required init() {
    pickerView = UIPickerView()

    super.init()

    pickerView.dataSource = self
    pickerView.delegate = self
    pickerView.translatesAutoresizingMaskIntoConstraints = false
    pickerView.isHidden = true

    let stackView = UIStackView(arrangedSubviews: [pickerView])
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .vertical
    stackView.alignment = .center

    contentView.addSubview(stackView)

    let constraints = NSLayoutConstraint.constraints(withVisualFormat: "|-[stackView]-|", options: [], metrics: nil, views: ["stackView": stackView])
      + NSLayoutConstraint.constraints(withVisualFormat: "V:[keyLabel]-[stackView]|", options: [], metrics: nil, views: ["keyLabel": keyLabel, "stackView": stackView])
    NSLayoutConstraint.activate(constraints)
  }

  @available(*, unavailable)
  required init(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func prepareForReuse() {
    super.prepareForReuse()

    showPicker(false)
  }

  override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
    super.configureForData(dictionary, viewController: viewController, tableView: tableView, indexPath: indexPath)

    // Array of picker labels
    pickerLabels = dictionary["labels"] as? [String]
    pickerShortLabels = dictionary["shortLabels"] as? [String]
    pickerView.reloadAllComponents()

    // (Re-)configure initial selected row
    let initialIndex = delegate.valueForIdentifier(valueIdentifier) as? Int ?? 0

    pickerView.selectRow(initialIndex, inComponent: 0, animated: false)
    pickerView.reloadComponent(0)

    textFieldProxy.text = (pickerShortLabels ?? pickerLabels)[initialIndex]
  }

  private func selectRow(_ row: Int) {
    textFieldProxy.text = (pickerShortLabels ?? pickerLabels)[row]

    delegate.valueChanged(row, identifier: valueIdentifier)
  }

  private func showPicker(_ show: Bool) {
    pickerView.isHidden = !show
  }

  // MARK: - UIPickerViewDataSource

  func numberOfComponents(in _: UIPickerView) -> Int {
    1
  }

  func pickerView(_: UIPickerView, numberOfRowsInComponent _: Int) -> Int {
    pickerLabels.count
  }

  func pickerView(_: UIPickerView, didSelectRow row: Int, inComponent _: Int) {
    selectRow(row)
  }

  // MARK: - UIPickerViewDelegate

  func pickerView(_: UIPickerView, rowHeightForComponent _: Int) -> CGFloat {
    pickerViewCellHeight
  }

  func pickerView(_: UIPickerView, widthForComponent _: Int) -> CGFloat {
    pickerViewCellWidth
  }

  func pickerView(_: UIPickerView, titleForRow row: Int, forComponent _: Int) -> String? {
    pickerLabels[row]
  }

  func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
    let label = (view as? UILabel) ?? UILabel()

    label.font = UIFont.preferredFont(forTextStyle: pickerShortLabels != nil ? UIFont.TextStyle.caption2 : UIFont.TextStyle.caption1)
    label.frame = CGRect(x: 0.0, y: 0.0, width: pickerViewCellWidth - 20.0, height: pickerViewCellHeight)
    label.backgroundColor = .clear

    label.text = self.pickerView(pickerView, titleForRow: row, forComponent: component)

    return label
  }

  // MARK: - UITextFieldDelegate

  func textFieldDidBeginEditing(_: UITextField) {
    showPicker(true)
  }

  override func textFieldDidEndEditing(_: UITextField, reason _: UITextField.DidEndEditingReason) {
    showPicker(false)
  }
}
