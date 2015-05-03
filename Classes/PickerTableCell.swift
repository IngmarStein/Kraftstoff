//
//  PickerTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

class PickerTableCell: EditableProxyPageCell, UIPickerViewDataSource, UIPickerViewDelegate {

	var picker: UIPickerView
	var pickerLabels: [String]!
	var pickerShortLabels: [String]?

	private let PickerViewCellWidth: CGFloat  = 290.0
	private let PickerViewCellHeight: CGFloat =  44.0

	override init() {
		self.picker = UIPickerView()

		super.init()

		self.picker.showsSelectionIndicator = true
		self.picker.dataSource              = self
		self.picker.delegate                = self

		self.textField.inputView = self.picker
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func configureForData(object: AnyObject!, viewController: AnyObject!, tableView: UITableView!, indexPath: NSIndexPath) {
		super.configureForData(object, viewController:viewController, tableView:tableView, indexPath:indexPath)

		let dictionary = object as! [NSObject:AnyObject]
		// Array of picker labels
		self.pickerLabels = dictionary["labels"] as? [String]
		self.pickerShortLabels = dictionary["shortLabels"] as? [String]
		self.picker.reloadAllComponents()

		// (Re-)configure initial selected row
		let initialIndex = self.delegate.valueForIdentifier(self.valueIdentifier)?.integerValue ?? 0

		self.picker.selectRow(initialIndex, inComponent:0, animated:false)
		self.picker.reloadComponent(0)

		self.textFieldProxy.text = (self.pickerShortLabels ?? self.pickerLabels)[initialIndex]
	}

	private func selectRow(row: Int) {
		self.textFieldProxy.text = (self.pickerShortLabels ?? self.pickerLabels)[row]

		self.delegate.valueChanged(row, identifier:self.valueIdentifier)
	}

	//MARK: - UIPickerViewDataSource

	func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
		return 1
	}

	func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return self.pickerLabels.count
	}

	func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		selectRow(row)
	}

	//MARK: - UIPickerViewDelegate

	func pickerView(pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
		return PickerViewCellHeight
	}

	func pickerView(pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
		return PickerViewCellWidth
	}

	func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
		return self.pickerLabels[row]
	}

	func pickerView(pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusingView view: UIView!) -> UIView {
		let label = (view as? UILabel) ?? UILabel()

		label.font = UIFont.boldSystemFontOfSize(self.pickerShortLabels != nil ? 18 : 20)
		label.frame = CGRect(x:0.0, y:0.0, width:PickerViewCellWidth-20.0, height:PickerViewCellHeight)
		label.backgroundColor = UIColor.clearColor()

		label.text = self.pickerView(pickerView, titleForRow:row, forComponent:component)

		return label
	}
}
