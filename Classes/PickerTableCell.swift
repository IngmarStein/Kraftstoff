//
//  PickerTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

final class PickerTableCell: EditableProxyPageCell, UIPickerViewDataSource, UIPickerViewDelegate {

	var picker: UIPickerView
	var pickerLabels: [String]!
	var pickerShortLabels: [String]?
	private var pickerConstraints = [NSLayoutConstraint]()

	private let PickerViewCellWidth: CGFloat  = 290.0
	private let PickerViewCellHeight: CGFloat =  44.0

	required init() {
		picker = UIPickerView()

		super.init()

		picker.showsSelectionIndicator = true
		picker.dataSource              = self
		picker.delegate                = self
		picker.translatesAutoresizingMaskIntoConstraints = false
		picker.hidden = true
		let pickerHeightConstraint = NSLayoutConstraint(item: picker, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: 162.0)
		pickerHeightConstraint.priority = 750
		picker.addConstraint(pickerHeightConstraint)
		contentView.addSubview(picker)

		pickerConstraints = NSLayoutConstraint.constraintsWithVisualFormat("V:[keyLabel]-[picker]-|", options: [], metrics: nil, views: ["keyLabel" : keyLabel, "picker" : picker]) as [NSLayoutConstraint]
		pickerConstraints.append(NSLayoutConstraint(item: picker, attribute: .CenterX, relatedBy: .Equal, toItem: contentView, attribute: .CenterX, multiplier: 1.0, constant: 0.0))
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func configureForData(dictionary: [NSObject:AnyObject], viewController: UIViewController, tableView: UITableView, indexPath: NSIndexPath) {
		super.configureForData(dictionary, viewController:viewController, tableView:tableView, indexPath:indexPath)

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

	private func showPicker(show: Bool) {
		if show {
			contentView.addConstraints(pickerConstraints)
			picker.hidden = false
		} else {
			contentView.removeConstraints(pickerConstraints)
			picker.hidden = true
		}
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

	func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		return self.pickerLabels[row]
	}

	func pickerView(pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusingView view: UIView?) -> UIView {
		let label = (view as? UILabel) ?? UILabel()

		label.font = UIFont.applicationFontForStyle(self.pickerShortLabels != nil ? UIFontTextStyleCaption2 : UIFontTextStyleCaption1)
		label.frame = CGRect(x:0.0, y:0.0, width:PickerViewCellWidth-20.0, height:PickerViewCellHeight)
		label.backgroundColor = UIColor.clearColor()

		label.text = self.pickerView(pickerView, titleForRow:row, forComponent:component)

		return label
	}

	//MARK: - UITextFieldDelegate

	func textFieldDidBeginEditing(textField: UITextField) {
		showPicker(true)
	}

	override func textFieldDidEndEditing(textField: UITextField) {
		showPicker(false)
	}
}
