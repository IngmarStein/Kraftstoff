//
//  CarConfigurationController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import UIKit

enum CarConfigurationResult: Int {
	case Canceled
	case CreateSucceeded
	case EditSucceeded
	case Aborted
}

protocol CarConfigurationControllerDelegate: class {
	func carConfigurationController(controller: CarConfigurationController, didFinishWithResult: CarConfigurationResult)
}

private let kSRConfiguratorDelegate               = "FuelConfiguratorDelegate"
private let kSRConfiguratorEditMode               = "FuelConfiguratorEditMode"
private let kSRConfiguratorCancelSheet            = "FuelConfiguratorCancelSheet"
private let kSRConfiguratorDataChanged            = "FuelConfiguratorDataChanged"
private let kSRConfiguratorPreviousSelectionIndex = "FuelConfiguratorPreviousSelectionIndex"
private let kSRConfiguratorName                   = "FuelConfiguratorName"
private let kSRConfiguratorPlate                  = "FuelConfiguratorPlate"
private let kSRConfiguratorOdometerUnit           = "FuelConfiguratorOdometerUnit"
private let kSRConfiguratorFuelUnit               = "FuelConfiguratorFuelUnit"
private let kSRConfiguratorFuelConsumptionUnit    = "FuelConfiguratorFuelConsumptionUnit"

class CarConfigurationController: PageViewController, UIViewControllerRestoration, EditablePageCellDelegate {

	var isShowingCancelSheet = false
	var dataChanged = false
	var previousSelectionIndex: NSIndexPath?

	var name: String?
	var plate: String?
	var odometerUnit: NSNumber?
	var odometer: NSDecimalNumber?
	var fuelUnit: NSNumber?
	var fuelConsumptionUnit: NSNumber?

	var editingExistingObject = false

	weak var delegate: CarConfigurationControllerDelegate?

	//MARK: - View Lifecycle

	required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		restorationClass = self.dynamicType
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		recreateTableContents()

		// Configure the navigation bar
		self.navigationItem.leftBarButtonItem  = UIBarButtonItem(barButtonSystemItem:.Done, target:self, action:"handleSave:")
		self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem:.Cancel, target:self, action:"handleCancel:")
		self.navigationItem.title = self.editingExistingObject ? NSLocalizedString("Edit Car", comment:"") : NSLocalizedString("New Car", comment:"")

		// Remove tint from navigation bar
		self.navigationController?.navigationBar.tintColor = nil

		NSNotificationCenter.defaultCenter().addObserver(self, selector:"localeChanged:", name:NSCurrentLocaleDidChangeNotification, object:nil)
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)

		dataChanged = false

		selectRowAtIndexPath(NSIndexPath(forRow:0, inSection:0))
	}

	//MARK: - State Restoration

	static func viewControllerWithRestorationIdentifierPath(identifierComponents: [AnyObject], coder: NSCoder) -> UIViewController? {
		if let storyboard = coder.decodeObjectOfClass(UIStoryboard.self, forKey: UIStateRestorationViewControllerStoryboardKey) as? UIStoryboard {
			let controller = storyboard.instantiateViewControllerWithIdentifier("CarConfigurationController") as! CarConfigurationController
			controller.editingExistingObject = coder.decodeBoolForKey(kSRConfiguratorEditMode)

			return controller
		}

		return nil
	}

	override func encodeRestorableStateWithCoder(coder: NSCoder) {
		let indexPath = isShowingCancelSheet ? previousSelectionIndex : self.tableView.indexPathForSelectedRow()

		coder.encodeObject(self.delegate,            forKey:kSRConfiguratorDelegate)
		coder.encodeBool(self.editingExistingObject, forKey:kSRConfiguratorEditMode)
		coder.encodeBool(isShowingCancelSheet,       forKey:kSRConfiguratorCancelSheet)
		coder.encodeBool(dataChanged,                forKey:kSRConfiguratorDataChanged)
		coder.encodeObject(indexPath,                forKey:kSRConfiguratorPreviousSelectionIndex)
		coder.encodeObject(self.name,                forKey:kSRConfiguratorName)
		coder.encodeObject(self.plate,               forKey:kSRConfiguratorPlate)
		coder.encodeObject(self.fuelUnit,            forKey:kSRConfiguratorFuelUnit)
		coder.encodeObject(self.fuelConsumptionUnit, forKey:kSRConfiguratorFuelConsumptionUnit)

		super.encodeRestorableStateWithCoder(coder)
	}

	override func decodeRestorableStateWithCoder(coder: NSCoder) {
		//TODO: use decodeObjectOfClass:forKey:
		self.delegate               = coder.decodeObjectForKey(kSRConfiguratorDelegate) as? CarConfigurationControllerDelegate
		self.isShowingCancelSheet   = coder.decodeBoolForKey(kSRConfiguratorCancelSheet)
		self.dataChanged            = coder.decodeBoolForKey(kSRConfiguratorDataChanged)
		self.previousSelectionIndex = coder.decodeObjectOfClass(NSIndexPath.self, forKey:kSRConfiguratorPreviousSelectionIndex) as? NSIndexPath
		self.name                   = coder.decodeObjectOfClass(NSString.self, forKey:kSRConfiguratorName) as? String
		self.plate                  = coder.decodeObjectOfClass(NSString.self, forKey:kSRConfiguratorPlate) as? String
		self.fuelUnit               = coder.decodeObjectOfClass(NSNumber.self, forKey:kSRConfiguratorFuelUnit) as? NSNumber
		self.fuelConsumptionUnit    = coder.decodeObjectOfClass(NSNumber.self, forKey:kSRConfiguratorFuelConsumptionUnit) as? NSNumber

		self.tableView.reloadData()

		if isShowingCancelSheet {
			showCancelSheet()
		} else {
			selectRowAtIndexPath(previousSelectionIndex)
		}

		super.decodeRestorableStateWithCoder(coder)
	}

	//MARK: - Creating the Table Rows

	func createOdometerRowWithAnimation(animation: UITableViewRowAnimation) {
		let suffix = " ".stringByAppendingString(Units.odometerUnitString(KSDistance(rawValue: self.odometerUnit!.intValue)!))

		if self.odometer == nil {
			self.odometer = NSDecimalNumber.zero()
		}

		addRowAtIndex(rowIndex: 3,
              inSection:0,
              cellClass:NumberEditTableCell.self,
			   cellData:["label":           NSLocalizedString("Odometer Reading", comment:""),
                         "suffix":          suffix,
                         "formatter":       Formatters.sharedDistanceFormatter,
                         "valueIdentifier": "odometer"],
          withAnimation:animation)
	}

	private func createTableContents() {
		addSectionAtIndex(0, withAnimation:.None)

		if self.name == nil {
			self.name = ""
		}

		addRowAtIndex(rowIndex: 0,
              inSection:0,
              cellClass:TextEditTableCell.self,
			   cellData:["label":           NSLocalizedString("Name", comment:""),
                         "valueIdentifier": "name"],
          withAnimation:.None)

		if self.plate == nil {
			self.plate = ""
		}

		addRowAtIndex(rowIndex: 1,
              inSection:0,
              cellClass:TextEditTableCell.self,
			   cellData:["label":             NSLocalizedString("License Plate", comment:""),
                         "valueIdentifier":   "plate",
                         "autocapitalizeAll": true],
          withAnimation:.None)

		if self.odometerUnit == nil {
			self.odometerUnit = Int(Units.distanceUnitFromLocale.rawValue)
		}

		let odometerUnitPickerLabels = [Units.odometerUnitDescription(.Kilometer,   pluralization:true),
										Units.odometerUnitDescription(.StatuteMile, pluralization:true)]

		addRowAtIndex(rowIndex: 2,
              inSection:0,
              cellClass:PickerTableCell.self,
			   cellData:["label":           NSLocalizedString("Odometer Type", comment:""),
                         "valueIdentifier": "odometerUnit",
                         "labels":          odometerUnitPickerLabels],
          withAnimation:.None)

		createOdometerRowWithAnimation(.None)

		if self.fuelUnit == nil {
			self.fuelUnit = Int(Units.volumeUnitFromLocale.rawValue)
		}

		let fuelUnitPickerLabels = [Units.fuelUnitDescription(.Liter, discernGallons:true, pluralization:true),
									Units.fuelUnitDescription(.GalUS, discernGallons:true, pluralization:true),
									Units.fuelUnitDescription(.GalUK, discernGallons:true, pluralization:true)]

		addRowAtIndex(rowIndex: 4,
              inSection:0,
              cellClass:PickerTableCell.self,
			   cellData:["label":           NSLocalizedString("Fuel Unit", comment:""),
						 "valueIdentifier": "fuelUnit",
                         "labels":          fuelUnitPickerLabels],
          withAnimation:.None)

		if self.fuelConsumptionUnit == nil {
			self.fuelConsumptionUnit = Int(Units.fuelConsumptionUnitFromLocale.rawValue)
		}

		let fuelConsumptionUnitPickerLabels = [Units.consumptionUnitDescription(.LitersPer100km),
                    Units.consumptionUnitDescription(.KilometersPerLiter),
                    Units.consumptionUnitDescription(.MilesPerGallonUS),
                    Units.consumptionUnitDescription(.MilesPerGallonUK),
                    Units.consumptionUnitDescription(.GP10KUS),
					Units.consumptionUnitDescription(.GP10KUK)]

		let fuelConsumptionUnitPickerShortLabels = [Units.consumptionUnitShortDescription(.LitersPer100km),
                         Units.consumptionUnitShortDescription(.KilometersPerLiter),
                         Units.consumptionUnitShortDescription(.MilesPerGallonUS),
                         Units.consumptionUnitShortDescription(.MilesPerGallonUK),
                         Units.consumptionUnitShortDescription(.GP10KUS),
                         Units.consumptionUnitShortDescription(.GP10KUK)]

		addRowAtIndex(rowIndex: 5,
              inSection:0,
              cellClass:PickerTableCell.self,
			   cellData:["label":           NSLocalizedString("Mileage", comment:""),
                         "valueIdentifier": "fuelConsumptionUnit",
                         "labels":          fuelConsumptionUnitPickerLabels,
                         "shortLabels":     fuelConsumptionUnitPickerShortLabels],
			withAnimation:.None)
	}

	private func recreateTableContents() {
		removeAllSectionsWithAnimation(.None)
		createTableContents()
		self.tableView.reloadData()
	}

	func recreateOdometerRowWithAnimation(animation: UITableViewRowAnimation) {
		removeRowAtIndex(3, inSection:0, withAnimation:.None)
		createOdometerRowWithAnimation(.None)

		if animation == .None {
			self.tableView.reloadData()
		} else {
			self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow:3, inSection:0)], withRowAnimation:animation)
		}
	}

	//MARK: - Locale Handling

	func localeChanged(object: AnyObject) {
		let previousSelection = self.tableView.indexPathForSelectedRow()

		dismissKeyboardWithCompletion {
			self.recreateTableContents()
			self.selectRowAtIndexPath(previousSelection)
		}
	}

	//MARK: - Programmatically Selecting Table Rows

	func activateTextFieldAtIndexPath(indexPath: NSIndexPath) {
		let cell = tableView.cellForRowAtIndexPath(indexPath)!
		let field: UITextField?

		if let textCell = cell as? TextEditTableCell {
			field = textCell.textField
		} else if let numberCell = cell as? NumberEditTableCell {
			field = numberCell.textField
		} else if let pickerCell = cell as? PickerTableCell {
			field = pickerCell.textField
		} else {
			field = nil
		}

		if let field = field {
			field.userInteractionEnabled = true
			field.becomeFirstResponder()
		}
	}

	func selectRowAtIndexPath(indexPath: NSIndexPath?) {
		if let indexPath = indexPath {
			tableView.selectRowAtIndexPath(indexPath, animated:true, scrollPosition:.Middle)
			activateTextFieldAtIndexPath(indexPath)
		}
	}

	//MARK: - Cancel Button

	@IBAction func handleCancel(sender: AnyObject) {
		previousSelectionIndex = self.tableView.indexPathForSelectedRow()

		dismissKeyboardWithCompletion { self.handleCancelCompletion() }
	}

	private func handleCancelCompletion() {
		var showCancelSheet = true

		// In editing mode show alert panel on any change
		if self.editingExistingObject && !dataChanged {
			showCancelSheet = false
		}

		// In create mode show alert panel on textual changes
		if !self.editingExistingObject
			&& self.name == ""
			&& self.plate == ""
			&& self.odometer!.compare(NSDecimalNumber.zero()) == .OrderedSame {
			showCancelSheet = false
		}

		if showCancelSheet {
			self.showCancelSheet()
		} else {
			self.delegate?.carConfigurationController(self, didFinishWithResult:.Canceled)
		}
	}

	func showCancelSheet() {
		isShowingCancelSheet = true

		let alertController = UIAlertController(title:self.editingExistingObject ? NSLocalizedString("Revert Changes for Car?", comment:"") : NSLocalizedString("Delete the newly created car?", comment:""),
																			 message:nil,
																	  preferredStyle:.ActionSheet)
		let cancelAction = UIAlertAction(title:NSLocalizedString("Cancel", comment:""), style:.Cancel) { _ in
			self.isShowingCancelSheet = false
			self.selectRowAtIndexPath(self.previousSelectionIndex)
			self.previousSelectionIndex = nil
		}
		let destructiveAction = UIAlertAction(title:self.editingExistingObject ? NSLocalizedString("Revert", comment:"") : NSLocalizedString("Delete", comment:""), style:.Destructive) { _ in
			self.isShowingCancelSheet = false
			self.delegate?.carConfigurationController(self, didFinishWithResult:.Canceled)
			self.previousSelectionIndex = nil
		}
		alertController.addAction(cancelAction)
		alertController.addAction(destructiveAction)
		alertController.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
		presentViewController(alertController, animated:true, completion:nil)
	}

	//MARK: - Save Button

	@IBAction func handleSave(sender: AnyObject) {
		dismissKeyboardWithCompletion {
			self.delegate?.carConfigurationController(self, didFinishWithResult:self.editingExistingObject ? .EditSucceeded : .CreateSucceeded)
		}
	}

	//MARK: - EditablePageCellDelegate

	func focusNextFieldForValueIdentifier(valueIdentifier: String) {
		if valueIdentifier == "name" {
			selectRowAtIndexPath(NSIndexPath(forRow:1, inSection:0))
		} else {
			selectRowAtIndexPath(NSIndexPath(forRow:2, inSection:0))
		}
	}


	func valueForIdentifier(valueIdentifier: String) -> AnyObject? {
		switch valueIdentifier {
		case "name": return self.name
		case "plate": return self.plate
		case "odometerUnit": return self.odometerUnit
		case "odometer": return self.odometer
		case "fuelUnit": return self.fuelUnit
		case "fuelConsumptionUnit": return self.fuelConsumptionUnit
		default: return nil
		}
	}

	func valueChanged(newValue: AnyObject?, identifier valueIdentifier: String) {
		if let stringValue = newValue as? String {
			if valueIdentifier == "name" {
				self.name = stringValue
			} else if valueIdentifier == "plate" {
				self.plate = stringValue
			}
		} else if let decimalNumberValue = newValue as? NSDecimalNumber {
			if valueIdentifier == "odometer" {
				self.odometer = decimalNumberValue
			}
		} else if let numberValue = newValue as? NSNumber {
			if valueIdentifier == "odometerUnit" {
				let oldUnit = KSDistance(rawValue: self.odometerUnit!.intValue)!
				let newUnit = KSDistance(rawValue: numberValue.intValue)!

				if oldUnit != newUnit {
					self.odometerUnit = numberValue
					self.odometer     = Units.distanceForKilometers(Units.kilometersForDistance(self.odometer!, withUnit:oldUnit), withUnit:newUnit)

					recreateOdometerRowWithAnimation(newUnit == .Kilometer ? .Left : .Right)
				}
			} else if valueIdentifier == "fuelUnit" {
				self.fuelUnit = numberValue
			} else if valueIdentifier == "fuelConsumptionUnit" {
				self.fuelConsumptionUnit = numberValue
			}
		}

		dataChanged = true
	}

	//MARK: - UITableViewDelegate

	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		activateTextFieldAtIndexPath(indexPath)

		tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition:.Middle, animated:true)
	}

	//MARK: - Memory Management

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
}
