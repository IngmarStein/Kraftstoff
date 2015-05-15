//
//  CarTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

class CarTableCell: EditableProxyPageCell, UIPickerViewDataSource, UIPickerViewDelegate {

	var carPicker: UIPickerView
	var cars: [Car]!

	// Standard cell geometry
	private let PickerViewCellWidth: CGFloat        = 290.0
	private let PickerViewCellHeight: CGFloat       =  44.0

	private let maximumDescriptionLength = 24

	// Attributes for custom PickerViews
	private var prefixAttributes = [NSObject:AnyObject]()
	private var suffixAttributes = [NSObject:AnyObject]()

	required init() {
		self.carPicker = UIPickerView()

		super.init()

		self.carPicker.showsSelectionIndicator = true
		self.carPicker.dataSource              = self
		self.carPicker.delegate                = self

		self.textField.inputView = self.carPicker
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func setupFonts() {
		super.setupFonts()

		prefixAttributes = [NSFontAttributeName : UIFont.applicationFontForStyle(UIFontTextStyleSubheadline),
			NSForegroundColorAttributeName : UIColor.blackColor()]
		suffixAttributes = [NSFontAttributeName : UIFont.applicationFontForStyle(UIFontTextStyleCaption2),
			NSForegroundColorAttributeName : UIColor.darkGrayColor()]

		self.carPicker.reloadAllComponents()
	}

	override func prepareForReuse() {
		super.prepareForReuse()

		self.cars = nil
		self.carPicker.reloadAllComponents()
	}

	override func configureForData(object: AnyObject?, viewController: UIViewController, tableView: UITableView, indexPath: NSIndexPath) {
		super.configureForData(object, viewController:viewController, tableView:tableView, indexPath:indexPath)

		let dictionary = object as! [NSObject:AnyObject]
		// Array of possible cars
		self.cars = dictionary["fetchedObjects"] as? [Car]

		// Look for index of selected car
		let car = self.delegate.valueForIdentifier(self.valueIdentifier) as! Car
		let initialIndex = find(self.cars, car) ?? 0

		// (Re-)configure car picker and select the initial item
		self.carPicker.reloadAllComponents()
		self.carPicker.selectRow(initialIndex, inComponent:0, animated:false)

		selectCar(self.cars[initialIndex])
	}

	private func selectCar(car: Car) {
		// Update textfield in cell
		var description = String(format:"%@ %@", car.name, car.numberPlate)

		if count(description) > maximumDescriptionLength {
			description = String(format:"%@…", description.substringToIndex(advance(description.startIndex, maximumDescriptionLength)))
		}

		self.textFieldProxy.text = description

		// Store selected car in delegate
		self.delegate.valueChanged(car, identifier:self.valueIdentifier)
	}

	//MARK: - UIPickerViewDataSource

	func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
		return 1
	}

	func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return self.cars?.count ?? 0
	}

	func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		selectCar(self.cars[row])
	}

	//MARK: - UIPickerViewDelegate

	func pickerView(pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
		return PickerViewCellHeight
	}

	func pickerView(pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
		return PickerViewCellWidth
	}

	func pickerView(pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusingView view: UIView!) -> UIView {
		// Strings to be displayed
		let car = self.cars[row]
		let name = car.name
		let info = car.numberPlate

		var label: UILabel! = view as? UILabel
		if label == nil {
			label = UILabel(frame: CGRectZero)
			label.lineBreakMode = .ByTruncatingTail
		}

		let attributedText = NSMutableAttributedString(string: "\(name)  \(info)", attributes: suffixAttributes)
		attributedText.beginEditing()
		attributedText.setAttributes(prefixAttributes, range:NSRange(location:0, length:count(name)))
		attributedText.endEditing()
		label.attributedText = attributedText

		// Description for accessibility
		label.isAccessibilityElement = true
		label.accessibilityLabel = "\(name) \(info)"

		return label
	}
}
