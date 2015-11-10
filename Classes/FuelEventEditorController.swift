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
	var date: NSDate!
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
	private var restoredSelectionIndex: NSIndexPath?

	//MARK: - View Lifecycle

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		self.restorationClass = self.dynamicType
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		// Title bar
		self.editButton   = UIBarButtonItem(barButtonSystemItem:.Edit, target:self, action:"enterEditingMode:")
		self.doneButton   = UIBarButtonItem(barButtonSystemItem:.Done, target:self, action:"endEditingModeAndSave:")
		self.cancelButton = UIBarButtonItem(barButtonSystemItem:.Stop, target:self, action:"endEditingModeAndRevert:")

		self.title = Formatters.sharedDateFormatter.stringFromDate(self.event.timestamp)
		self.navigationItem.rightBarButtonItem = self.editButton

		// Remove tint from navigation bar
		self.navigationController?.navigationBar.tintColor = nil

		// Table contents
		self.tableView.allowsSelection = false

		createTableContentsWithAnimation(.None)
		self.tableView.reloadData()
    
		NSNotificationCenter.defaultCenter().addObserver(self, selector:"localeChanged:", name:NSCurrentLocaleDidChangeNotification, object:nil)
	}

	//MARK: - State Restoration

	static func viewControllerWithRestorationIdentifierPath(identifierComponents: [AnyObject], coder: NSCoder) -> UIViewController? {
		if let storyboard = coder.decodeObjectForKey(UIStateRestorationViewControllerStoryboardKey) as? UIStoryboard {
			let controller = storyboard.instantiateViewControllerWithIdentifier("FuelEventEditor") as! FuelEventEditorController
			let modelIdentifier = coder.decodeObjectOfClass(NSString.self, forKey:kSRFuelEventEventID) as! String
			controller.event = CoreDataManager.managedObjectForModelIdentifier(modelIdentifier) as? FuelEvent

			if controller.event == nil {
				return nil
			}

			return controller
		}

		return nil
	}

	override func encodeRestorableStateWithCoder(coder: NSCoder) {
		let indexPath = isShowingCancelSheet ? restoredSelectionIndex : self.tableView.indexPathForSelectedRow

		coder.encodeBool(isShowingCancelSheet, forKey:kSRFuelEventCancelSheet)
		coder.encodeBool(dataChanged, forKey:kSRFuelEventDataChanged)
		coder.encodeObject(indexPath, forKey:kSRFuelEventSelectionIndex)
		coder.encodeObject(CoreDataManager.modelIdentifierForManagedObject(event), forKey:kSRFuelEventEventID)
		coder.encodeObject(CoreDataManager.modelIdentifierForManagedObject(car), forKey:kSRFuelEventCarID)
		coder.encodeObject(date, forKey:kSRFuelEventDate)
		coder.encodeObject(distance, forKey:kSRFuelEventDistance)
		coder.encodeObject(price, forKey:kSRFuelEventPrice)
		coder.encodeObject(fuelVolume, forKey:kSRFuelEventVolume)
		coder.encodeBool(filledUp, forKey:kSRFuelEventFilledUp)
		coder.encodeObject(comment, forKey:kSRFuelEventComment)
		coder.encodeBool(self.editing, forKey:kSRFuelEventEditing)

		super.encodeRestorableStateWithCoder(coder)
	}

	override func decodeRestorableStateWithCoder(coder: NSCoder) {
		isShowingCancelSheet   = coder.decodeBoolForKey(kSRFuelEventCancelSheet)
		dataChanged            = coder.decodeBoolForKey(kSRFuelEventDataChanged)
		restoredSelectionIndex = coder.decodeObjectOfClass(NSIndexPath.self, forKey:kSRFuelEventSelectionIndex)
		car                    = CoreDataManager.managedObjectForModelIdentifier(coder.decodeObjectOfClass(NSString.self, forKey:kSRFuelEventCarID) as! String) as? Car
		date                   = coder.decodeObjectOfClass(NSDate.self, forKey: kSRFuelEventDate)
		distance               = coder.decodeObjectOfClass(NSDecimalNumber.self, forKey: kSRFuelEventDistance)
		price                  = coder.decodeObjectOfClass(NSDecimalNumber.self, forKey: kSRFuelEventPrice)
		fuelVolume             = coder.decodeObjectOfClass(NSDecimalNumber.self, forKey: kSRFuelEventVolume)
		filledUp               = coder.decodeBoolForKey(kSRFuelEventFilledUp)
		comment                = coder.decodeObjectOfClass(NSString.self, forKey: kSRFuelEventComment) as? String

		if coder.decodeBoolForKey(kSRFuelEventEditing) {
			setEditing(true, animated:false)
            
			if isShowingCancelSheet {
				showRevertActionSheet()
			} else {
				selectRowAtIndexPath(restoredSelectionIndex)
				restoredSelectionIndex = nil
			}
		}

		super.decodeRestorableStateWithCoder(coder)
	}

	//MARK: - Saving and Restoring the Fuel Event

	private func saveStateToEvent() {
		if dataChanged {
			dataChanged = false

			// Remove event from database
			CoreDataManager.removeEventFromArchive(event, forceOdometerUpdate:true)

			// Reinsert new version of event
			event = CoreDataManager.addToArchiveWithCar(car,
                                             date:date,
                                         distance:distance,
                                            price:price,
                                       fuelVolume:fuelVolume,
                                         filledUp:filledUp,
										  comment:comment,
                              forceOdometerUpdate:true)

			CoreDataManager.saveContext()
		}
	}

	private func restoreStateFromEvent() {
		car = event.car

		let odometerUnit = car.ksOdometerUnit
		let fuelUnit     = car.ksFuelUnit
    
		self.title = Formatters.sharedDateFormatter.stringFromDate(event.timestamp)
		date       = event.timestamp
		distance   = Units.distanceForKilometers(event.distance, withUnit:odometerUnit)
		price      = Units.pricePerUnit(event.price, withUnit:fuelUnit)
		fuelVolume = Units.volumeForLiters(event.fuelVolume, withUnit:fuelUnit)
		filledUp   = event.filledUp
		comment    = event.comment

		dataChanged = false
	}

	//MARK: - Mode Switching for Table Rows

	private func reconfigureRowAtIndexPath(indexPath: NSIndexPath) {
		if let cell = self.tableView.cellForRowAtIndexPath(indexPath) as? PageCell, cellData = dataForRow(indexPath.row, inSection: 0) {
			cell.configureForData(cellData,
                viewController:self,
                     tableView:self.tableView,
                     indexPath:indexPath)
        
			cell.setNeedsDisplay()
		}
    }

	override func setEditing(enabled: Bool, animated: Bool) {
		if self.editing != enabled {
			let animation: UITableViewRowAnimation = animated ? .Fade : .None

			super.setEditing(enabled, animated:animated)
        
			if enabled {
				self.navigationItem.leftBarButtonItem  = self.doneButton
				self.navigationItem.rightBarButtonItem = self.cancelButton

				removeSectionAtIndex(1, withAnimation:animation)
			} else {
				self.navigationItem.leftBarButtonItem  = nil
				self.navigationItem.rightBarButtonItem = self.editButton

				createConsumptionRowWithAnimation(animation)
			}

			if animated {
				for var row = 0; row <= 4; row++ {
					reconfigureRowAtIndexPath(NSIndexPath(forRow:row, inSection:0))
				}
			} else {
				self.tableView.reloadData()
			}

			self.tableView.allowsSelection = enabled
		}
	}

	//MARK: - Entering Editing Mode

	@IBAction func enterEditingMode(sender: AnyObject) {
		setEditing(true, animated:true)
		selectRowAtIndexPath(NSIndexPath(forRow:0, inSection:0))
	}

	//MARK: - Saving Edited Data

	@IBAction func endEditingModeAndSave(sender: AnyObject) {
		dismissKeyboardWithCompletion {
			self.saveStateToEvent()
			self.setEditing(false, animated:true)
		}
	}

	//MARK: - Aborting Editing Mode

	@IBAction func endEditingModeAndRevert(sender: AnyObject) {
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
		let alertController = UIAlertController(title:NSLocalizedString("Revert Changes for Event?", comment:""),
																			 message:nil,
																	  preferredStyle:.ActionSheet)
		let cancelAction = UIAlertAction(title:NSLocalizedString("Cancel", comment:""), style:.Cancel) { _ in
			self.isShowingCancelSheet = false
			self.selectRowAtIndexPath(self.restoredSelectionIndex)
			self.restoredSelectionIndex = nil
		}
		let destructiveAction = UIAlertAction(title:NSLocalizedString("Revert", comment:""), style:.Destructive) { _ in
			self.isShowingCancelSheet = false
			self.endEditingModeAndRevertCompletion()
			self.restoredSelectionIndex = nil
		}

		alertController.addAction(cancelAction)
		alertController.addAction(destructiveAction)
		alertController.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem

		isShowingCancelSheet = true
		presentViewController(alertController, animated:true, completion:nil)
	}

	func endEditingModeAndRevertCompletion() {
		restoreStateFromEvent()
		setEditing(false, animated:true)

		restoredSelectionIndex = nil
	}

	//MARK: - Creating the Table Rows

	private func createConsumptionRowWithAnimation(animation: UITableViewRowAnimation) {
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

		let liters      = Units.litersForVolume(fuelVolume, withUnit:fuelUnit)
		let kilometers  = Units.kilometersForDistance(distance, withUnit:odometerUnit)
		let consumption = Units.consumptionForKilometers(kilometers, liters:liters, inUnit:consumptionUnit)

		let consumptionString = String(format:"%@ %@ %@ %@",
                                      Formatters.sharedCurrencyFormatter.stringFromNumber(cost)!,
									  NSLocalizedString("/", comment:""),
                                      Formatters.sharedFuelVolumeFormatter.stringFromNumber(consumption)!,
                                      consumptionUnit.localizedString)

		// Substrings for highlighting
		let highlightStrings = [Formatters.sharedCurrencyFormatter.currencySymbol!,
                                  consumptionUnit.localizedString]

		addSectionAtIndex(1, withAnimation:animation)

		addRowAtIndex(rowIndex: 0,
              inSection:1,
              cellClass:ConsumptionTableCell.self,
               cellData:["label":            consumptionString,
                         "highlightStrings": highlightStrings],
          withAnimation:animation)
	}

	private func createTableContentsWithAnimation(animation: UITableViewRowAnimation) {
		addSectionAtIndex(0, withAnimation:animation)

		addRowAtIndex(rowIndex: 0,
              inSection:0,
              cellClass:DateEditTableCell.self,
			   cellData:["label": NSLocalizedString("Date", comment:""),
                         "formatter": Formatters.sharedDateTimeFormatter,
                         "valueIdentifier": "date"],
          withAnimation:animation)

		let odometerUnit = car.ksOdometerUnit

		addRowAtIndex(rowIndex: 1,
              inSection:0,
              cellClass:NumberEditTableCell.self,
			   cellData:["label": NSLocalizedString("Distance", comment:""),
                         "suffix": " ".stringByAppendingString(odometerUnit.description),
                         "formatter": Formatters.sharedDistanceFormatter,
                         "valueIdentifier": "distance"],
          withAnimation:animation)

		let fuelUnit = car.ksFuelUnit

		addRowAtIndex(rowIndex: 2,
              inSection:0,
              cellClass:NumberEditTableCell.self,
			   cellData:["label": Units.fuelPriceUnitDescription(fuelUnit),
                         "formatter": Formatters.sharedEditPreciseCurrencyFormatter,
                         "alternateFormatter": Formatters.sharedPreciseCurrencyFormatter,
                         "valueIdentifier": "price"],
          withAnimation:animation)

		addRowAtIndex(rowIndex: 3,
              inSection:0,
              cellClass:NumberEditTableCell.self,
               cellData:["label": Units.fuelUnitDescription(fuelUnit, discernGallons:false, pluralization:true),
                         "suffix": " ".stringByAppendingString(fuelUnit.description),
                         "formatter": fuelUnit.isMetric ? Formatters.sharedFuelVolumeFormatter : Formatters.sharedPreciseFuelVolumeFormatter,
                         "valueIdentifier": "fuelVolume"],
          withAnimation:animation)

		addRowAtIndex(rowIndex: 4,
              inSection:0,
              cellClass:SwitchTableCell.self,
			   cellData:["label": NSLocalizedString("Full Fill-Up", comment:""),
                         "valueIdentifier": "filledUp"],
          withAnimation:animation)

		addRowAtIndex(rowIndex: 5,
			inSection:0,
			cellClass:TextEditTableCell.self,
			cellData:["label": NSLocalizedString("Comment", comment:""),
				"valueIdentifier": "comment"],
			withAnimation:animation)

		if !self.editing {
			createConsumptionRowWithAnimation(animation)
		}
	}

	//MARK: - Locale Handling

	func localeChanged(object: AnyObject) {
		let previousSelection = self.tableView.indexPathForSelectedRow
    
		dismissKeyboardWithCompletion {
			self.removeAllSectionsWithAnimation(.None)
			self.createTableContentsWithAnimation(.None)
			self.tableView.reloadData()

			self.selectRowAtIndexPath(previousSelection)
		}
	}

	//MARK: - Programmatically Selecting Table Rows

	private func textFieldAtIndexPath(indexPath: NSIndexPath) -> UITextField? {
		let cell = self.tableView.cellForRowAtIndexPath(indexPath)!
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

	func activateTextFieldAtIndexPath(indexPath: NSIndexPath) {
		if let field = textFieldAtIndexPath(indexPath) {
			field.userInteractionEnabled = true
			field.becomeFirstResponder()
			dispatch_async(dispatch_get_main_queue()) {
				tableView.beginUpdates()
				tableView.endUpdates()
			}
		}
	}

	private func selectRowAtIndexPath(path: NSIndexPath?) {
		if let path = path {
			self.tableView.selectRowAtIndexPath(path, animated:false, scrollPosition:.None)
			self.tableView(self.tableView, didSelectRowAtIndexPath:path)
		}
	}

	//MARK: - EditablePageCellDelegate

	func valueForIdentifier(valueIdentifier: String) -> AnyObject? {
		switch valueIdentifier {
			case "date": return date
			case "distance": return distance
			case "price": return price
			case "fuelVolume": return fuelVolume
			case "filledUp": return filledUp
			case "comment": return comment
			case "showValueLabel": return !self.editing
			default: return nil
		}
	}

	func valueChanged(newValue: AnyObject?, identifier valueIdentifier: String) {
		if valueIdentifier == "date" {
			if let dateValue = newValue as? NSDate {
				let newDate = NSDate.dateWithoutSeconds(dateValue)

				if !date.isEqualToDate(newDate) {
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
		} else if !date.isEqualToDate(event.timestamp) {
			if CoreDataManager.containsEventWithCar(car, andDate:date) {
				canBeSaved = false
			}
		}

		self.doneButton.enabled = canBeSaved
	}

	//MARK: - EditablePageCellValidator

	func valueValid(newValue: AnyObject?, identifier valueIdentifier: String) -> Bool {
		// Date must be collision free
		if let date = newValue as? NSDate {
			if valueIdentifier == "date" {
				if !date.isEqualToDate(event.timestamp) {
					if CoreDataManager.containsEventWithCar(car, andDate:date) {
						return false
					}
				}
			}
		}

		// DecimalNumbers <= 0.0 are invalid
		if let decimalNumber = newValue as? NSDecimalNumber {
			if valueIdentifier != "price" {
				if decimalNumber <= NSDecimalNumber.zero() {
					return false
				}
			}
		}

		return true
	}

	//MARK: - UITableViewDataSource

	override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return nil
	}

	//MARK: - UITableViewDelegate

	override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
		let cell = tableView.cellForRowAtIndexPath(indexPath)

		if cell is SwitchTableCell || cell is ConsumptionTableCell {
			return nil
		} else {
			return indexPath
		}
	}

	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		activateTextFieldAtIndexPath(indexPath)
		tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition:.Middle, animated:true)
	}

	override func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
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
