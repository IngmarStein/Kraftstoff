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

final class CarConfigurationController: PageViewController, UIViewControllerRestoration, EditablePageCellDelegate, EditablePageCellFocusHandler {

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

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		restorationClass = self.dynamicType
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		recreateTableContents()

		// Configure the navigation bar
		let leftBarButtonItem = UIBarButtonItem(barButtonSystemItem:.done, target:self, action:#selector(CarConfigurationController.handleSave(_:)))
		leftBarButtonItem.accessibilityIdentifier = "done"
		self.navigationItem.leftBarButtonItem = leftBarButtonItem
		self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem:.cancel, target:self, action:#selector(CarConfigurationController.handleCancel(_:)))
		self.navigationItem.title = self.editingExistingObject ? NSLocalizedString("Edit Car", comment:"") : NSLocalizedString("New Car", comment:"")

		// Remove tint from navigation bar
		self.navigationController?.navigationBar.tintColor = nil

		NSNotificationCenter.defaultCenter().addObserver(self, selector:#selector(CarConfigurationController.localeChanged(_:)), name:NSCurrentLocaleDidChangeNotification, object:nil)
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)

		dataChanged = false

		selectRowAtIndexPath(NSIndexPath(forRow:0, inSection:0))
	}

	//MARK: - State Restoration

	static func viewController(withRestorationIdentifierPath identifierComponents: [AnyObject], coder: NSCoder) -> UIViewController? {
		if let storyboard = coder.decodeObject(forKey: UIStateRestorationViewControllerStoryboardKey) as? UIStoryboard {
			let controller = storyboard.instantiateViewController(withIdentifier: "CarConfigurationController") as! CarConfigurationController
			controller.editingExistingObject = coder.decodeBool(forKey: kSRConfiguratorEditMode)

			return controller
		}

		return nil
	}

	override func encodeRestorableState(with coder: NSCoder) {
		let indexPath = isShowingCancelSheet ? previousSelectionIndex : self.tableView.indexPathForSelectedRow

		coder.encode(self.delegate,            forKey:kSRConfiguratorDelegate)
		coder.encode(self.editingExistingObject, forKey:kSRConfiguratorEditMode)
		coder.encode(isShowingCancelSheet,       forKey:kSRConfiguratorCancelSheet)
		coder.encode(dataChanged,                forKey:kSRConfiguratorDataChanged)
		coder.encode(indexPath,                forKey:kSRConfiguratorPreviousSelectionIndex)
		coder.encode(self.name,                forKey:kSRConfiguratorName)
		coder.encode(self.plate,               forKey:kSRConfiguratorPlate)
		coder.encode(self.fuelUnit,            forKey:kSRConfiguratorFuelUnit)
		coder.encode(self.fuelConsumptionUnit, forKey:kSRConfiguratorFuelConsumptionUnit)

		super.encodeRestorableState(with: coder)
	}

	override func decodeRestorableState(with coder: NSCoder) {
		//TODO: use decodeObjectOfClass:forKey:
		self.delegate               = coder.decodeObject(forKey: kSRConfiguratorDelegate) as? CarConfigurationControllerDelegate
		self.isShowingCancelSheet   = coder.decodeBool(forKey: kSRConfiguratorCancelSheet)
		self.dataChanged            = coder.decodeBool(forKey: kSRConfiguratorDataChanged)
		self.previousSelectionIndex = coder.decodeObjectOfClass(NSIndexPath.self, forKey:kSRConfiguratorPreviousSelectionIndex)
		self.name                   = coder.decodeObjectOfClass(NSString.self, forKey:kSRConfiguratorName) as? String
		self.plate                  = coder.decodeObjectOfClass(NSString.self, forKey:kSRConfiguratorPlate) as? String
		self.fuelUnit               = coder.decodeObjectOfClass(NSNumber.self, forKey:kSRConfiguratorFuelUnit)
		self.fuelConsumptionUnit    = coder.decodeObjectOfClass(NSNumber.self, forKey:kSRConfiguratorFuelConsumptionUnit)

		self.tableView.reloadData()

		if isShowingCancelSheet {
			showCancelSheet()
		} else {
			selectRowAtIndexPath(previousSelectionIndex)
		}

		super.decodeRestorableState(with: coder)
	}

	//MARK: - Creating the Table Rows

	func createOdometerRowWithAnimation(animation: UITableViewRowAnimation) {
		let suffix = " ".appending(KSDistance(rawValue: self.odometerUnit!.intValue)!.description)

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
		addSectionAtIndex(0, withAnimation: .none)

		if self.name == nil {
			self.name = ""
		}

		addRowAtIndex(rowIndex: 0,
              inSection:0,
              cellClass:TextEditTableCell.self,
			   cellData:["label":           NSLocalizedString("Name", comment:""),
                         "valueIdentifier": "name"],
          withAnimation: .none)

		if self.plate == nil {
			self.plate = ""
		}

		addRowAtIndex(rowIndex: 1,
              inSection:0,
              cellClass:TextEditTableCell.self,
			   cellData:["label":             NSLocalizedString("License Plate", comment:""),
                         "valueIdentifier":   "plate",
                         "autocapitalizeAll": true],
          withAnimation: .none)

		if self.odometerUnit == nil {
			self.odometerUnit = Int(Units.distanceUnitFromLocale.rawValue)
		}

		let odometerUnitPickerLabels = [Units.odometerUnitDescription(.kilometer,   pluralization:true),
										Units.odometerUnitDescription(.statuteMile, pluralization:true)]

		addRowAtIndex(rowIndex: 2,
              inSection:0,
              cellClass:PickerTableCell.self,
			   cellData:["label":           NSLocalizedString("Odometer Type", comment:""),
                         "valueIdentifier": "odometerUnit",
                         "labels":          odometerUnitPickerLabels],
          withAnimation: .none)

		createOdometerRowWithAnimation(.none)

		if self.fuelUnit == nil {
			self.fuelUnit = Int(Units.volumeUnitFromLocale.rawValue)
		}

		let fuelUnitPickerLabels = [Units.fuelUnitDescription(.liter, discernGallons:true, pluralization:true),
									Units.fuelUnitDescription(.galUS, discernGallons:true, pluralization:true),
									Units.fuelUnitDescription(.galUK, discernGallons:true, pluralization:true)]

		addRowAtIndex(rowIndex: 4,
              inSection:0,
              cellClass:PickerTableCell.self,
			   cellData:["label":           NSLocalizedString("Fuel Unit", comment:""),
						 "valueIdentifier": "fuelUnit",
                         "labels":          fuelUnitPickerLabels],
          withAnimation: .none)

		if self.fuelConsumptionUnit == nil {
			self.fuelConsumptionUnit = Int(Units.fuelConsumptionUnitFromLocale.rawValue)
		}

		let fuelConsumptionUnitPickerLabels = [KSFuelConsumption.litersPer100km.description,
                    KSFuelConsumption.kilometersPerLiter.description,
                    KSFuelConsumption.milesPerGallonUS.description,
                    KSFuelConsumption.milesPerGallonUK.description,
                    KSFuelConsumption.gp10KUS.description,
					KSFuelConsumption.gp10KUK.description]

		let fuelConsumptionUnitPickerShortLabels = [KSFuelConsumption.litersPer100km.shortDescription,
                         KSFuelConsumption.kilometersPerLiter.shortDescription,
                         KSFuelConsumption.milesPerGallonUS.shortDescription,
                         KSFuelConsumption.milesPerGallonUK.shortDescription,
                         KSFuelConsumption.gp10KUS.shortDescription,
                         KSFuelConsumption.gp10KUK.shortDescription]

		addRowAtIndex(rowIndex: 5,
              inSection:0,
              cellClass:PickerTableCell.self,
			   cellData:["label":           NSLocalizedString("Mileage", comment:""),
                         "valueIdentifier": "fuelConsumptionUnit",
                         "labels":          fuelConsumptionUnitPickerLabels,
                         "shortLabels":     fuelConsumptionUnitPickerShortLabels],
			withAnimation: .none)
	}

	private func recreateTableContents() {
		removeAllSectionsWithAnimation(.none)
		createTableContents()
		self.tableView.reloadData()
	}

	func recreateOdometerRowWithAnimation(animation: UITableViewRowAnimation) {
		removeRowAtIndex(3, inSection:0, withAnimation: .none)
		createOdometerRowWithAnimation(.none)

		if animation == .none {
			self.tableView.reloadData()
		} else {
			self.tableView.reloadRows(at: [NSIndexPath(forRow:3, inSection:0)], with: animation)
		}
	}

	//MARK: - Locale Handling

	func localeChanged(object: AnyObject) {
		let previousSelection = self.tableView.indexPathForSelectedRow

		dismissKeyboardWithCompletion {
			self.recreateTableContents()
			self.selectRowAtIndexPath(previousSelection)
		}
	}

	//MARK: - Programmatically Selecting Table Rows

	private func textFieldAtIndexPath(indexPath: NSIndexPath) -> UITextField? {
		let cell = tableView.cellForRow(at: indexPath)!
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

		return field
	}

	private func activateTextFieldAtIndexPath(indexPath: NSIndexPath) {
		if let field = textFieldAtIndexPath(indexPath) {
			field.isUserInteractionEnabled = true
			field.becomeFirstResponder()
			dispatch_async(dispatch_get_main_queue()) {
				self.tableView.beginUpdates()
				self.tableView.endUpdates()
			}
		}
	}

	func selectRowAtIndexPath(indexPath: NSIndexPath?) {
		if let indexPath = indexPath {
			tableView.selectRow(at: indexPath, animated:true, scrollPosition: .middle)
			activateTextFieldAtIndexPath(indexPath)
		}
	}

	//MARK: - Cancel Button

	@IBAction func handleCancel(sender: AnyObject) {
		previousSelectionIndex = self.tableView.indexPathForSelectedRow

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
			&& self.odometer! == NSDecimalNumber.zero() {
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
																			 message: nil,
																	  preferredStyle: .actionSheet)
		let cancelAction = UIAlertAction(title:NSLocalizedString("Cancel", comment:""), style: .cancel) { _ in
			self.isShowingCancelSheet = false
			self.selectRowAtIndexPath(self.previousSelectionIndex)
			self.previousSelectionIndex = nil
		}
		let destructiveAction = UIAlertAction(title:self.editingExistingObject ? NSLocalizedString("Revert", comment:"") : NSLocalizedString("Delete", comment:""), style: .destructive) { _ in
			self.isShowingCancelSheet = false
			self.delegate?.carConfigurationController(self, didFinishWithResult:.Canceled)
			self.previousSelectionIndex = nil
		}
		alertController.addAction(cancelAction)
		alertController.addAction(destructiveAction)
		alertController.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
		present(alertController, animated:true, completion:nil)
	}

	//MARK: - Save Button

	@IBAction func handleSave(sender: AnyObject) {
		dismissKeyboardWithCompletion {
			self.delegate?.carConfigurationController(self, didFinishWithResult:self.editingExistingObject ? .EditSucceeded : .CreateSucceeded)
		}
	}

	//MARK: - EditablePageCellFocusHandler

	func focusNextFieldForValueIdentifier(valueIdentifier: String) {
		if valueIdentifier == "name" {
			selectRowAtIndexPath(NSIndexPath(forRow:1, inSection:0))
		} else {
			selectRowAtIndexPath(NSIndexPath(forRow:2, inSection:0))
		}
	}

	//MARK: - EditablePageCellDelegate

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

					recreateOdometerRowWithAnimation(newUnit == .kilometer ? .left : .right)
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

	override func tableView(tableView: UITableView, didSelectRowAt indexPath: NSIndexPath) {
		activateTextFieldAtIndexPath(indexPath)
		tableView.scrollToRow(at: indexPath, at: .middle, animated:true)
	}

	override func tableView(tableView: UITableView, didDeselectRowAt indexPath: NSIndexPath) {
		if let field = textFieldAtIndexPath(indexPath) {
			field.resignFirstResponder()
			dispatch_async(dispatch_get_main_queue()) {
				tableView.beginUpdates()
				tableView.endUpdates()
			}
		}
	}

	//MARK: - Memory Management

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
}
