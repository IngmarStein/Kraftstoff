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
	var fetchedObjects: [NSManagedObject]!

	// Standard cell geometry
	private let PickerViewCellWidth: CGFloat        = 290.0
	private let PickerViewCellHeight: CGFloat       =  44.0
	private let PickerViewCellMargin: CGFloat       =  10.0
	private let PickerViewCellTextPosition: CGFloat =  13.0

	private let maximumDescriptionLength = 24

	// Attributes for custom PickerViews
	private let prefixAttributesDict : [NSObject:AnyObject] = {
		let font = "HelveticaNeue" as CFString
		let helvetica24 = CTFontCreateWithName(font, 24, nil)

		return [kCTFontAttributeName as String : helvetica24,
				kCTForegroundColorAttributeName as String : UIColor.blackColor().CGColor]
	}()

	private let suffixAttributesDict : [NSObject:AnyObject] = {
		let font = "HelveticaNeue" as CFString
		let helvetica18 = CTFontCreateWithName(font, 18, nil)

		return [kCTFontAttributeName as String : helvetica18,
				kCTForegroundColorAttributeName as String : UIColor.darkGrayColor().CGColor]
	}()

	override init() {
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

	override func prepareForReuse() {
		super.prepareForReuse()

		self.fetchedObjects = nil
		self.carPicker.reloadAllComponents()
	}

	override func configureForData(object: AnyObject!, viewController: AnyObject!, tableView: UITableView!, indexPath: NSIndexPath!) {
		super.configureForData(object, viewController:viewController, tableView:tableView, indexPath:indexPath)

		let dictionary = object as! [NSObject:AnyObject]
		// Array of possible cars
		self.fetchedObjects = dictionary["fetchedObjects"] as? [NSManagedObject]

		// Look for index of selected car
		let managedObject = self.delegate.valueForIdentifier(self.valueIdentifier) as! NSManagedObject
		let initialIndex = find(self.fetchedObjects, managedObject) ?? 0

		// (Re-)configure car picker and select the initial item
		self.carPicker.reloadAllComponents()
		self.carPicker.selectRow(initialIndex, inComponent:0, animated:false)

		selectCar(self.fetchedObjects[initialIndex])
	}

	private func selectCar(managedObject: NSManagedObject) {
		// Update textfield in cell
		var description = String(format:"%@ %@",
                                 managedObject.valueForKey("name") as! String,
                                 managedObject.valueForKey("numberPlate") as! String)

		if count(description) > maximumDescriptionLength {
			description = String(format:"%@…", description.substringToIndex(advance(description.startIndex, maximumDescriptionLength)))
		}

		self.textFieldProxy.text = description

		// Store selected car in delegate
		self.delegate.valueChanged(managedObject, identifier:self.valueIdentifier)
	}

	//MARK: - UIPickerViewDataSource

	func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
		return 1
	}

	func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return self.fetchedObjects.count
	}

	func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		selectCar(self.fetchedObjects[row])
	}

	//MARK: - UIPickerViewDelegate

	func pickerView(pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
		return PickerViewCellHeight
	}

	func pickerView(pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
		return PickerViewCellWidth
	}

	private func truncatedLineForName(name: String, info: String) -> CTLineRef {
		let truncationString = NSAttributedString(string:"…", attributes:suffixAttributesDict)

		var attributedString = NSMutableAttributedString(string:String(format:"%@  %@", name, info), attributes:suffixAttributesDict)

		attributedString.setAttributes(prefixAttributesDict, range:NSRange(location:0, length:count(name)))

		let line            = CTLineCreateWithAttributedString(attributedString)
		let truncationToken = CTLineCreateWithAttributedString(truncationString)
		let truncatedLine   = CTLineCreateTruncatedLine (line, Double(PickerViewCellWidth - 2*PickerViewCellMargin), CTLineTruncationType.End, truncationToken)

		return truncatedLine
	}

	func pickerView(pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusingView view: UIView!) -> UIView {
		// Strings to be displayed
		let managedObject = self.fetchedObjects[row]
		let name = managedObject.valueForKey("name") as! String
		let info = managedObject.valueForKey("numberPlate") as! String

		// Draw strings with attributes into image
		UIGraphicsBeginImageContextWithOptions (CGSize(width:PickerViewCellWidth, height:PickerViewCellHeight), false, 0.0)

		let context = UIGraphicsGetCurrentContext()

        CGContextTranslateCTM(context, 1, PickerViewCellHeight)
        CGContextScaleCTM(context, 1, -1)

		let truncatedLine = truncatedLineForName(name, info:info)
		CGContextSetTextPosition(context, PickerViewCellMargin, PickerViewCellTextPosition)
		CTLineDraw(truncatedLine, context)

		let image = UIGraphicsGetImageFromCurrentImageContext()

		UIGraphicsEndImageContext()

		// Wrap with imageview
		var imageView = view as? PickerImageView
		if imageView == nil {
			imageView = PickerImageView(image:image)
		} else {
			imageView!.image = image
		}

		imageView!.userInteractionEnabled = true
		imageView!.pickerView = pickerView
		imageView!.rowIndex   = row

		// Description for accessibility
		imageView!.isAccessibilityElement = true
		imageView!.accessibilityLabel = String(format:"%@ %@", name, info)

		return imageView!
	}
}
