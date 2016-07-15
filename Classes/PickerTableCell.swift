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

	private let pickerViewCellWidth: CGFloat  = 290.0
	private let pickerViewCellHeight: CGFloat =  44.0

	required init() {
		pickerView = UIPickerView()

		super.init()

		pickerView.showsSelectionIndicator = true
		pickerView.dataSource              = self
		pickerView.delegate                = self
		pickerView.translatesAutoresizingMaskIntoConstraints = false
		pickerView.isHidden = true

		let stackView = UIStackView(arrangedSubviews: [pickerView])
		stackView.translatesAutoresizingMaskIntoConstraints = false
		stackView.axis = .vertical
		stackView.alignment = .center

		contentView.addSubview(stackView)
		contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[stackView]-|", options: [], metrics: nil, views: ["stackView": stackView]))
		contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[keyLabel]-[stackView]|", options: [], metrics: nil, views: ["keyLabel": keyLabel, "stackView": stackView]))
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func prepareForReuse() {
		super.prepareForReuse()

		showPicker(false)
	}

	override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
		super.configureForData(dictionary, viewController: viewController, tableView: tableView, indexPath: indexPath)

		// Array of picker labels
		self.pickerLabels = dictionary["labels"] as? [String]
		self.pickerShortLabels = dictionary["shortLabels"] as? [String]
		self.pickerView.reloadAllComponents()

		// (Re-)configure initial selected row
		let initialIndex = self.delegate.valueForIdentifier(self.valueIdentifier) as? Int ?? 0

		self.pickerView.selectRow(initialIndex, inComponent: 0, animated: false)
		self.pickerView.reloadComponent(0)

		self.textFieldProxy.text = (self.pickerShortLabels ?? self.pickerLabels)[initialIndex]
	}

	private func selectRow(_ row: Int) {
		self.textFieldProxy.text = (self.pickerShortLabels ?? self.pickerLabels)[row]

		self.delegate.valueChanged(row as NSNumber, identifier: self.valueIdentifier)
	}

	private func showPicker(_ show: Bool) {
		pickerView.isHidden = !show
	}

	// MARK: - UIPickerViewDataSource

	func numberOfComponents(in pickerView: UIPickerView) -> Int {
		return 1
	}

	func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return self.pickerLabels.count
	}

	func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		selectRow(row)
	}

	// MARK: - UIPickerViewDelegate

	func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
		return pickerViewCellHeight
	}

	func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
		return pickerViewCellWidth
	}

	func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		return self.pickerLabels[row]
	}

	func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
		let label = (view as? UILabel) ?? UILabel()

		label.font = UIFont.preferredFont(forTextStyle: self.pickerShortLabels != nil ? UIFontTextStyleCaption2 : UIFontTextStyleCaption1)
		label.frame = CGRect(x: 0.0, y: 0.0, width: pickerViewCellWidth-20.0, height: pickerViewCellHeight)
		label.backgroundColor = .clear()

		label.text = self.pickerView(pickerView, titleForRow: row, forComponent: component)

		return label
	}

	// MARK: - UITextFieldDelegate

	func textFieldDidBeginEditing(_ textField: UITextField) {
		showPicker(true)
	}

	override func textFieldDidEndEditing(_ textField: UITextField) {
		showPicker(false)
	}

}
