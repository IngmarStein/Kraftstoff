//
//  FuelEventEditorController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import UIKit
import CoreData

private let kSRFuelEventCancelSheet     = "FuelEventCancelSheet"
private let kSRFuelEventDataChanged     = "FuelEventDataChanged"
private let kSRFuelEventSelectionIndex  = "FuelEventMostSelectionIndex"
private let kSRFuelEventEventID         = "FuelEventEventID"
private let kSRFuelEventCarID           = "FuelEventCarID"
private let kSRFuelEventDate            = "FuelEventDate"
private let kSRFuelEventDistance        = "FuelEventDistance"
private let kSRFuelEventPrice           = "FuelEventPrice"
private let kSRFuelEventVolume          = "FuelEventVolume "
private let kSRFuelEventFilledUp        = "FuelEventFilledUp"
private let kSRFuelEventEditing         = "FuelEventEditing"
private let kSRFuelEventComment         = "FuelEventComment"

final class FuelEventEditorController: PageViewController, UIViewControllerRestoration, NSFetchedResultsControllerDelegate, EditablePageCellDelegate, EditablePageCellValidator {

	var event: FuelEvent! {
		didSet {
			restoreStateFromEvent()
		}
	}
	var car: Car!
	var date: Date!
	var distance: NSDecimalNumber!
	var price: NSDecimalNumber!
	var fuelVolume: NSDecimalNumber!
	var filledUp = false
	var comment: String?

	var editButton: UIBarButtonItem!
	var cancelButton: UIBarButtonItem!
	var doneButton: UIBarButtonItem!

	private var isShowingCancelSheet = false
	private var dataChanged = false
	private var restoredSelectionIndex: IndexPath?

	// MARK: - View Lifecycle

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		self.restorationClass = self.dynamicType
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		// Title bar
		self.editButton   = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(FuelEventEditorController.enterEditingMode(_:)))
		self.doneButton   = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(FuelEventEditorController.endEditingModeAndSave(_:)))
		self.cancelButton = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(FuelEventEditorController.endEditingModeAndRevert(_:)))

		self.editButton.accessibilityIdentifier = "edit"
		self.doneButton.accessibilityIdentifier = "done"
		self.cancelButton.accessibilityIdentifier = "cancel"

		self.title = Formatters.sharedDateFormatter.string(from: self.event.timestamp)
		self.navigationItem.rightBarButtonItem = self.editButton

		// Remove tint from navigation bar
		self.navigationController?.navigationBar.tintColor = nil

		// Table contents
		self.tableView.allowsSelection = false

		createTableContentsWithAnimation(.none)
		self.tableView.reloadData()
    
		NotificationCenter.default().addObserver(self, selector:#selector(FuelEventEditorController.localeChanged(_:)), name:Locale.currentLocaleDidChangeNotification, object: nil)
	}

	// MARK: - State Restoration

	static func viewController(withRestorationIdentifierPath identifierComponents: [AnyObject], coder: NSCoder) -> UIViewController? {
		if let storyboard = coder.decodeObject(forKey: UIStateRestorationViewControllerStoryboardKey) as? UIStoryboard {
			let controller = storyboard.instantiateViewController(withIdentifier: "FuelEventEditor") as! FuelEventEditorController
			let modelIdentifier = coder.decodeObjectOfClass(NSString.self, forKey:kSRFuelEventEventID) as! String
			controller.event = CoreDataManager.managedObjectForModelIdentifier(modelIdentifier) as? FuelEvent

			if controller.event == nil {
				return nil
			}

			return controller
		}

		return nil
	}

	override func encodeRestorableState(with coder: NSCoder) {
		let indexPath = isShowingCancelSheet ? restoredSelectionIndex : self.tableView.indexPathForSelectedRow

		coder.encode(isShowingCancelSheet, forKey:kSRFuelEventCancelSheet)
		coder.encode(dataChanged, forKey:kSRFuelEventDataChanged)
		coder.encode(indexPath, forKey:kSRFuelEventSelectionIndex)
		coder.encode(CoreDataManager.modelIdentifierForManagedObject(event) as NSString?, forKey:kSRFuelEventEventID)
		coder.encode(CoreDataManager.modelIdentifierForManagedObject(car) as NSString?, forKey:kSRFuelEventCarID)
		coder.encode(date, forKey:kSRFuelEventDate)
		coder.encode(distance, forKey:kSRFuelEventDistance)
		coder.encode(price, forKey:kSRFuelEventPrice)
		coder.encode(fuelVolume, forKey:kSRFuelEventVolume)
		coder.encode(filledUp, forKey:kSRFuelEventFilledUp)
		coder.encode(comment as NSString?, forKey:kSRFuelEventComment)
		coder.encode(self.isEditing, forKey:kSRFuelEventEditing)

		super.encodeRestorableState(with: coder)
	}

	override func decodeRestorableState(with coder: NSCoder) {
		isShowingCancelSheet   = coder.decodeBool(forKey: kSRFuelEventCancelSheet)
		dataChanged            = coder.decodeBool(forKey: kSRFuelEventDataChanged)
		restoredSelectionIndex = coder.decodeObjectOfClass(NSIndexPath.self, forKey: kSRFuelEventSelectionIndex) as? IndexPath
		car                    = CoreDataManager.managedObjectForModelIdentifier(coder.decodeObjectOfClass(NSString.self, forKey:kSRFuelEventCarID) as! String) as? Car
		date                   = coder.decodeObjectOfClass(NSDate.self, forKey: kSRFuelEventDate) as? Date
		distance               = coder.decodeObjectOfClass(NSDecimalNumber.self, forKey: kSRFuelEventDistance)
		price                  = coder.decodeObjectOfClass(NSDecimalNumber.self, forKey: kSRFuelEventPrice)
		fuelVolume             = coder.decodeObjectOfClass(NSDecimalNumber.self, forKey: kSRFuelEventVolume)
		filledUp               = coder.decodeBool(forKey: kSRFuelEventFilledUp)
		comment                = coder.decodeObjectOfClass(NSString.self, forKey: kSRFuelEventComment) as? String

		if coder.decodeBool(forKey: kSRFuelEventEditing) {
			setEditing(true, animated: false)
            
			if isShowingCancelSheet {
				showRevertActionSheet()
			} else {
				selectRowAtIndexPath(restoredSelectionIndex)
				restoredSelectionIndex = nil
			}
		}

		super.decodeRestorableState(with: coder)
	}

	// MARK: - Saving and Restoring the Fuel Event

	private func saveStateToEvent() {
		if dataChanged {
			dataChanged = false

			// Remove event from database
			CoreDataManager.removeEventFromArchive(event, forceOdometerUpdate: true)

			// Reinsert new version of event
			event = CoreDataManager.addToArchive(car: car,
                                                date: date,
                                            distance: distance,
                                               price: price,
                                          fuelVolume: fuelVolume,
                                            filledUp: filledUp,
									   	     comment: comment,
							     forceOdometerUpdate: true)

			CoreDataManager.saveContext()
		}
	}

	private func restoreStateFromEvent() {
		car = event.car

		let odometerUnit = car.ksOdometerUnit
		let fuelUnit     = car.ksFuelUnit
    
		self.title = Formatters.sharedDateFormatter.string(from: event.timestamp)
		date       = event.timestamp
		distance   = Units.distanceForKilometers(event.distance, withUnit:odometerUnit)
		price      = Units.pricePerUnit(event.price, withUnit: fuelUnit)
		fuelVolume = Units.volumeForLiters(event.fuelVolume, withUnit: fuelUnit)
		filledUp   = event.filledUp
		comment    = event.comment

		dataChanged = false
	}

	// MARK: - Mode Switching for Table Rows

	private func reconfigureRowAtIndexPath(_ indexPath: IndexPath) {
		if let cell = self.tableView.cellForRow(at: indexPath) as? PageCell, cellData = dataForRow(indexPath.row, inSection: 0) {
			cell.configureForData(cellData,
                viewController: self,
                     tableView: self.tableView,
                     indexPath: indexPath)
        
			cell.setNeedsDisplay()
		}
    }

	override func setEditing(_ enabled: Bool, animated: Bool) {
		if self.isEditing != enabled {
			let animation: UITableViewRowAnimation = animated ? .fade : .none

			super.setEditing(enabled, animated: animated)
        
			if enabled {
				self.navigationItem.leftBarButtonItem  = self.doneButton
				self.navigationItem.rightBarButtonItem = self.cancelButton

				removeSectionAtIndex(1, withAnimation: animation)
			} else {
				self.navigationItem.leftBarButtonItem  = nil
				self.navigationItem.rightBarButtonItem = self.editButton

				createConsumptionRowWithAnimation(animation)
			}

			if animated {
				for row in 0...4 {
					reconfigureRowAtIndexPath(IndexPath(row: row, section: 0))
				}
			} else {
				self.tableView.reloadData()
			}

			self.tableView.allowsSelection = enabled
		}
	}

	// MARK: - Entering Editing Mode

	@IBAction func enterEditingMode(_ sender: AnyObject) {
		setEditing(true, animated: true)
		selectRowAtIndexPath(IndexPath(row: 0, section: 0))
	}

	// MARK: - Saving Edited Data

	@IBAction func endEditingModeAndSave(_ sender: AnyObject) {
		dismissKeyboardWithCompletion {
			self.saveStateToEvent()
			self.setEditing(false, animated: true)
		}
	}

	// MARK: - Aborting Editing Mode

	@IBAction func endEditingModeAndRevert(_ sender: AnyObject) {
		restoredSelectionIndex = self.tableView.indexPathForSelectedRow
    
		dismissKeyboardWithCompletion {
			if self.dataChanged {
				self.showRevertActionSheet()
			} else {
				self.endEditingModeAndRevertCompletion()
			}
		}
	}

	private func showRevertActionSheet() {
		let alertController = UIAlertController(title: NSLocalizedString("Revert Changes for Event?", comment: ""),
																			 message: nil,
																	  preferredStyle: .actionSheet)
		let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
			self.isShowingCancelSheet = false
			self.selectRowAtIndexPath(self.restoredSelectionIndex)
			self.restoredSelectionIndex = nil
		}
		let destructiveAction = UIAlertAction(title: NSLocalizedString("Revert", comment: ""), style: .destructive) { _ in
			self.isShowingCancelSheet = false
			self.endEditingModeAndRevertCompletion()
			self.restoredSelectionIndex = nil
		}

		alertController.addAction(cancelAction)
		alertController.addAction(destructiveAction)
		alertController.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem

		isShowingCancelSheet = true
		present(alertController, animated: true, completion: nil)
	}

	func endEditingModeAndRevertCompletion() {
		restoreStateFromEvent()
		setEditing(false, animated: true)

		restoredSelectionIndex = nil
	}

	// MARK: - Creating the Table Rows

	private func createConsumptionRowWithAnimation(_ animation: UITableViewRowAnimation) {
		// Don't add the section when no value can be computed
		let zero = NSDecimalNumber.zero()

		if distance <= zero || fuelVolume <= zero {
			return
		}

		// Conversion units
		let odometerUnit    = car.ksOdometerUnit
		let fuelUnit        = car.ksFuelUnit
		let consumptionUnit = car.ksFuelConsumptionUnit

		// Compute the average consumption
		let cost = fuelVolume * price

		let liters      = Units.litersForVolume(fuelVolume, withUnit: fuelUnit)
		let kilometers  = Units.kilometersForDistance(distance, withUnit: odometerUnit)
		let consumption = Units.consumptionForKilometers(kilometers, liters: liters, inUnit: consumptionUnit)

		let consumptionString = "\(Formatters.sharedCurrencyFormatter.string(from: cost)!) \(NSLocalizedString("/", comment: "")) \(Formatters.sharedFuelVolumeFormatter.string(from: consumption)!) \(consumptionUnit.localizedString)"

		// Substrings for highlighting
		let highlightStrings = [Formatters.sharedCurrencyFormatter.currencySymbol!,
                                  consumptionUnit.localizedString]

		addSectionAtIndex(1, withAnimation: animation)

		addRowAtIndex(rowIndex: 0,
              inSection: 1,
              cellClass: ConsumptionTableCell.self,
               cellData: ["label":            consumptionString,
                          "highlightStrings": highlightStrings],
          withAnimation: animation)
	}

	private func createTableContentsWithAnimation(_ animation: UITableViewRowAnimation) {
		addSectionAtIndex(0, withAnimation: animation)

		addRowAtIndex(rowIndex: 0,
              inSection: 0,
              cellClass: DateEditTableCell.self,
			   cellData: ["label": NSLocalizedString("Date", comment: ""),
                          "formatter": Formatters.sharedDateTimeFormatter,
                          "valueIdentifier": "date"],
          withAnimation: animation)

		let odometerUnit = car.ksOdometerUnit

		addRowAtIndex(rowIndex: 1,
              inSection: 0,
              cellClass: NumberEditTableCell.self,
			   cellData: ["label": NSLocalizedString("Distance", comment: ""),
			              "suffix": " ".appending(Formatters.sharedShortMeasurementFormatter.string(from: odometerUnit)),
                          "formatter": Formatters.sharedDistanceFormatter,
                          "valueIdentifier": "distance"],
          withAnimation: animation)

		let fuelUnit = car.ksFuelUnit

		addRowAtIndex(rowIndex: 2,
              inSection: 0,
              cellClass: NumberEditTableCell.self,
			   cellData: ["label": Units.fuelPriceUnitDescription(fuelUnit),
                          "formatter": Formatters.sharedEditPreciseCurrencyFormatter,
                          "alternateFormatter": Formatters.sharedPreciseCurrencyFormatter,
                          "valueIdentifier": "price"],
          withAnimation: animation)

		addRowAtIndex(rowIndex: 3,
              inSection: 0,
              cellClass: NumberEditTableCell.self,
               cellData: ["label": Units.fuelUnitDescription(fuelUnit, discernGallons: false, pluralization: true),
						  "suffix": " ".appending(Formatters.sharedShortMeasurementFormatter.string(from: fuelUnit)),
                          "formatter": fuelUnit == UnitVolume.liters ? Formatters.sharedFuelVolumeFormatter : Formatters.sharedPreciseFuelVolumeFormatter,
                          "valueIdentifier": "fuelVolume"],
          withAnimation: animation)

		addRowAtIndex(rowIndex: 4,
              inSection: 0,
              cellClass: SwitchTableCell.self,
			   cellData: ["label": NSLocalizedString("Full Fill-Up", comment: ""),
                          "valueIdentifier": "filledUp"],
          withAnimation: animation)

		addRowAtIndex(rowIndex: 5,
			inSection: 0,
			cellClass: TextEditTableCell.self,
			cellData: ["label": NSLocalizedString("Comment", comment: ""),
				 "valueIdentifier": "comment"],
			withAnimation: animation)

		if !self.isEditing {
			createConsumptionRowWithAnimation(animation)
		}
	}

	// MARK: - Locale Handling

	func localeChanged(_ object: AnyObject) {
		let previousSelection = self.tableView.indexPathForSelectedRow
    
		dismissKeyboardWithCompletion {
			self.removeAllSectionsWithAnimation(.none)
			self.createTableContentsWithAnimation(.none)
			self.tableView.reloadData()

			self.selectRowAtIndexPath(previousSelection)
		}
	}

	// MARK: - Programmatically Selecting Table Rows

	private func textFieldAtIndexPath(_ indexPath: IndexPath) -> UITextField? {
		let cell = self.tableView.cellForRow(at: indexPath)!
		let field : UITextField?

		if let carCell = cell as? CarTableCell {
			field = carCell.textField
		} else if let dateCell = cell as? DateEditTableCell {
			field = dateCell.textField
		} else if let numberCell = cell as? NumberEditTableCell {
			field = numberCell.textField
		} else if let numberCell = cell as? TextEditTableCell {
			field = numberCell.textField
		} else {
			field = nil
		}
		return field
	}

	func activateTextFieldAtIndexPath(_ indexPath: IndexPath) {
		if let field = textFieldAtIndexPath(indexPath) {
			field.isUserInteractionEnabled = true
			field.becomeFirstResponder()
			DispatchQueue.main.async {
				self.tableView.beginUpdates()
				self.tableView.endUpdates()
			}
		}
	}

	private func selectRowAtIndexPath(_ path: IndexPath?) {
		if let path = path {
			self.tableView.selectRow(at: path, animated: false, scrollPosition: .none)
			self.tableView(self.tableView, didSelectRowAt:path)
		}
	}

	// MARK: - EditablePageCellDelegate

	func valueForIdentifier(_ valueIdentifier: String) -> Any? {
		switch valueIdentifier {
			case "date": return date
			case "distance": return distance
			case "price": return price
			case "fuelVolume": return fuelVolume
			case "filledUp": return filledUp
			case "comment": return comment
			case "showValueLabel": return !self.isEditing
			default: return nil
		}
	}

	func valueChanged(_ newValue: AnyObject?, identifier valueIdentifier: String) {
		if valueIdentifier == "date" {
			if let dateValue = newValue as? Date {
				let newDate = Date.dateWithoutSeconds(dateValue)

				if date != newDate {
					date = newDate
					dataChanged = true
				}
			}
		} else if let newNumber = newValue as? NSDecimalNumber {
			if valueIdentifier == "distance" {
				if distance != newNumber {
					distance = newNumber
					dataChanged = true
				}
			} else if valueIdentifier == "price" {
				if price != newNumber {
					price = newNumber
					dataChanged = true
				}
			} else if valueIdentifier == "fuelVolume" {
				if fuelVolume != newNumber {
					fuelVolume = newNumber
					dataChanged = true
				}
			}
		} else if valueIdentifier == "filledUp" {
			if let newBoolValue = newValue as? Bool {
				if filledUp != newBoolValue {
					filledUp = newBoolValue
					dataChanged = true
				}
			}
		} else if valueIdentifier == "comment" {
			if let newValue = newValue as? String {
				if comment != newValue {
					comment = newValue
					dataChanged = true
				}
			}
		}

		// Validation of Done button
		var canBeSaved = true

		let zero = NSDecimalNumber.zero()

		if !(distance > zero && fuelVolume > zero) {
			canBeSaved = false
		} else if date != event.timestamp {
			if CoreDataManager.containsEventWithCar(car, andDate:date) {
				canBeSaved = false
			}
		}

		self.doneButton.isEnabled = canBeSaved
	}

	// MARK: - EditablePageCellValidator

	func valueValid(_ newValue: AnyObject?, identifier valueIdentifier: String) -> Bool {
		// Date must be collision free
		if let date = newValue as? Date {
			if valueIdentifier == "date" {
				if date != event.timestamp {
					if CoreDataManager.containsEventWithCar(car, andDate:date) {
						return false
					}
				}
			}
		}

		// DecimalNumbers <= 0.0 are invalid
		if let decimalNumber = newValue as? NSDecimalNumber {
			if valueIdentifier != "price" {
				if decimalNumber <= .zero() {
					return false
				}
			}
		}

		return true
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return nil
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
		let cell = tableView.cellForRow(at: indexPath)

		if cell is SwitchTableCell || cell is ConsumptionTableCell {
			return nil
		} else {
			return indexPath
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		activateTextFieldAtIndexPath(indexPath)
		tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
	}

	override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
		if let field = textFieldAtIndexPath(indexPath) {
			field.resignFirstResponder()
			DispatchQueue.main.async {
				tableView.beginUpdates()
				tableView.endUpdates()
			}
		}
	}

	// MARK: - Memory Management

	deinit {
		NotificationCenter.default().removeObserver(self)
	}
}
