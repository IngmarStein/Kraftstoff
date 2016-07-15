//
//  CarTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

final class CarTableCell: EditableProxyPageCell, UIPickerViewDataSource, UIPickerViewDelegate {

	private var carPicker: UIPickerView
	var cars: [Car]

	// Standard cell geometry
	private let pickerViewCellWidth: CGFloat  = 290.0
	private let pickerViewCellHeight: CGFloat =  44.0

	// Attributes for custom PickerViews
	private var prefixAttributes = [NSFontAttributeName: UIFont.preferredFont(forTextStyle: UIFontTextStyleHeadline),
	                                NSForegroundColorAttributeName: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)]
	private var suffixAttributes = [NSFontAttributeName: UIFont.preferredFont(forTextStyle: UIFontTextStyleSubheadline),
									NSForegroundColorAttributeName: #colorLiteral(red: 0.3300000131, green: 0.3300000131, blue: 0.3300000131, alpha: 1)]

	required init() {
		carPicker = UIPickerView()
		cars = []

		super.init()

		let carPickerHeightConstraint = NSLayoutConstraint(item: carPicker, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 162.0)
		carPickerHeightConstraint.priority = 750
		carPicker.showsSelectionIndicator = true
		carPicker.dataSource              = self
		carPicker.delegate                = self
		carPicker.translatesAutoresizingMaskIntoConstraints = false
		carPicker.isHidden = true
		carPicker.addConstraint(carPickerHeightConstraint)

		let stackView = UIStackView(arrangedSubviews: [carPicker])
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

		self.cars = []
		self.carPicker.reloadAllComponents()
	}

	override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
		super.configureForData(dictionary, viewController: viewController, tableView: tableView, indexPath: indexPath)

		// Array of possible cars
		self.cars = dictionary["fetchedObjects"] as? [Car] ?? []

		// Look for index of selected car
		guard let car = self.delegate.valueForIdentifier(self.valueIdentifier) as? Car else { return }
		let initialIndex = self.cars.index(of: car) ?? 0

		// (Re-)configure car picker and select the initial item
		self.carPicker.reloadAllComponents()
		self.carPicker.selectRow(initialIndex, inComponent: 0, animated: false)

		selectCar(self.cars[initialIndex])
	}

	private func selectCar(_ car: Car) {
		// Update textfield in cell
		self.textFieldProxy.text = "\(car.name) \(car.numberPlate)"

		// Store selected car in delegate
		self.delegate.valueChanged(car, identifier: self.valueIdentifier)
	}

	private func showPicker(_ show: Bool) {
		carPicker.isHidden = !show
	}

	// MARK: - UIPickerViewDataSource

	func numberOfComponents(in pickerView: UIPickerView) -> Int {
		return 1
	}

	func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return self.cars.count
	}

	func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		selectCar(self.cars[row])
	}

	// MARK: - UIPickerViewDelegate

	func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
		return pickerViewCellHeight
	}

	func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
		return pickerViewCellWidth
	}

	func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
		// Strings to be displayed
		let car = self.cars[row]
		let name = car.name
		let info = car.numberPlate

		var label: UILabel! = view as? UILabel
		if label == nil {
			label = UILabel(frame: .zero)
			label.lineBreakMode = .byTruncatingTail
		}

		let attributedText = NSMutableAttributedString(string: "\(name)  \(info)", attributes: suffixAttributes)
		attributedText.beginEditing()
		attributedText.setAttributes(prefixAttributes, range: NSRange(location: 0, length: name.characters.count))
		attributedText.endEditing()
		label.attributedText = attributedText

		// Description for accessibility
		label.isAccessibilityElement = true
		label.accessibilityLabel = "\(name) \(info)"

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
