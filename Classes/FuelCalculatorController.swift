//
//  FuelCalculatorController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import UIKit
import CoreData

private struct FuelCalculatorDataRow: RawOptionSetType {
	private var value: UInt = 0
	var rawValue: UInt { return value }
	init(nilLiteral: ()) { self.value = 0 }
	init(_ value: UInt) { self.value = value }
	init(rawValue value: UInt) { self.value = value }

	static var allZeros: FuelCalculatorDataRow { return self(0b0000) }
	static var Distance: FuelCalculatorDataRow { return self(0b0001) }
	static var Price: FuelCalculatorDataRow    { return self(0b0010) }
	static var Amount: FuelCalculatorDataRow   { return self(0b0100) }
	static var All: FuelCalculatorDataRow      { return self(0b0111) }
}

class FuelCalculatorController: PageViewController, NSFetchedResultsControllerDelegate, EditablePageCellDelegate {

	var changeIsUserDriven = false
	var isShowingConvertSheet = false

	var managedObjectContext: NSManagedObjectContext
	var fetchedResultsController: NSFetchedResultsController

	var restoredSelectionIndex: NSIndexPath?
	var car: Car?
	var date: NSDate?
	var lastChangeDate: NSDate?
	var distance: NSDecimalNumber?
	var price: NSDecimalNumber?
	var fuelVolume: NSDecimalNumber?
	var filledUp: Bool?

	var doneButton: UIBarButtonItem!
	var saveButton: UIBarButtonItem!

	required init(coder aDecoder: NSCoder) {
		// Fetch the cars
		self.managedObjectContext = AppDelegate.managedObjectContext
		self.fetchedResultsController = AppDelegate.fetchedResultsControllerForCarsInContext(self.managedObjectContext)

		super.init(coder: aDecoder)

		// Title bar
		self.doneButton = UIBarButtonItem(barButtonSystemItem:.Done, target:self, action:"endEditingMode:")
		self.saveButton = UIBarButtonItem(barButtonSystemItem:.Save, target:self, action:"saveAction:")
		self.title = NSLocalizedString("Fill-Up", comment:"")

		self.fetchedResultsController.delegate = self
	}

	//MARK: - View Lifecycle

	override func viewDidLoad() {
		super.viewDidLoad()

		// Remove tint from navigation bar
		self.navigationController?.navigationBar.tintColor = nil

		// Table contents
		self.constantRowHeight = false

		createTableContentsWithAnimation(.None)
		self.tableView.reloadData()
		updateSaveButtonState()

		NSNotificationCenter.defaultCenter().addObserver(self, selector:"localeChanged:", name:NSCurrentLocaleDidChangeNotification, object:nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector:"willEnterForeground:", name:UIApplicationWillEnterForegroundNotification, object:nil)
	}

	//MARK: - State Restoration

	private let kSRCalculatorSelectedIndex = "FuelCalculatorSelectedIndex"
	private let kSRCalculatorConvertSheet  = "FuelCalculatorConvertSheet"
	private let kSRCalculatorEditing       = "FuelCalculatorEditing"

	override func encodeRestorableStateWithCoder(coder: NSCoder) {
		if let indexPath = self.restoredSelectionIndex ?? self.tableView.indexPathForSelectedRow() {
			coder.encodeObject(indexPath, forKey: kSRCalculatorSelectedIndex)
		}

		coder.encodeBool(isShowingConvertSheet, forKey:kSRCalculatorConvertSheet)
		coder.encodeBool(self.editing, forKey:kSRCalculatorEditing)

		super.encodeRestorableStateWithCoder(coder)
	}

	override func decodeRestorableStateWithCoder(coder: NSCoder) {
		self.restoredSelectionIndex = coder.decodeObjectOfClass(NSIndexPath.self, forKey: kSRCalculatorSelectedIndex) as? NSIndexPath
		self.isShowingConvertSheet = coder.decodeBoolForKey(kSRCalculatorConvertSheet)
    
		if coder.decodeBoolForKey(kSRCalculatorEditing) {
			self.setEditing(true, animated:false)

			if isShowingConvertSheet {
				showOdometerConversionAlert()
			} else {
				selectRowAtIndexPath(self.restoredSelectionIndex)
				self.restoredSelectionIndex = nil
			}
		}

		super.decodeRestorableStateWithCoder(coder)
	}

	//MARK: - Modeswitching for Table Rows

	override func setEditing(enabled: Bool, animated: Bool) {
		if self.editing != enabled {

			let animation: UITableViewRowAnimation = animated ? .Fade : .None
        
			super.setEditing(enabled, animated:animated)
        
			if enabled {
				self.navigationItem.leftBarButtonItem = self.doneButton
				self.navigationItem.rightBarButtonItem = nil

				removeSectionAtIndex(1, withAnimation:animation)
			} else {
				self.navigationItem.leftBarButtonItem = nil
            
				if consumptionRowNeeded() {
					createConsumptionRowWithAnimation(animation)
				}

				updateSaveButtonState()
			}
        
			if !animated {
				self.tableView.reloadData()
			}
		}
	}

	//MARK: - Shake Events

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)

		NSNotificationCenter.defaultCenter().addObserver(self,
                                             selector:"handleShake:",
                                                 name:kraftstoffDeviceShakeNotification,
                                               object:nil)
	}

	override func viewDidDisappear(animated: Bool) {
		super.viewDidDisappear(animated)

		NSNotificationCenter.defaultCenter().removeObserver(self,
                                                    name:kraftstoffDeviceShakeNotification,
                                                  object:nil)
	}

	func handleShake(object: AnyObject) {
		if self.editing {
			return
		}

		let zero = NSDecimalNumber.zero()

		if (distance == nil || distance!.compare(zero) == .OrderedSame) && (fuelVolume == nil || fuelVolume!.compare(zero) == .OrderedSame) && (price == nil || price!.compare(zero) == .OrderedSame) {
			return
		}

		UIView.animateWithDuration(0.3,
                     animations: {
                         self.removeSectionAtIndex(1, withAnimation:.Fade)
                     }, completion: { finished in

                         let now = NSDate()

                         self.valueChanged(NSDate.dateWithoutSeconds(now), identifier:"date")
                         self.valueChanged(now,  identifier:"lastChangeDate")
                         self.valueChanged(zero, identifier:"distance")
                         self.valueChanged(zero, identifier:"price")
                         self.valueChanged(zero, identifier:"fuelVolume")
                         self.valueChanged(true, identifier:"filledUp")

                         self.recreateTableContentsWithAnimation(.Left)
                         self.updateSaveButtonState()
                     })
	}

	//MARK: - Creating the Table Rows

	func consumptionRowNeeded() -> Bool {

		if self.editing {
			return false
		}

		let zero = NSDecimalNumber.zero()

		if (distance != nil && distance!.compare(zero) != .OrderedDescending) || (fuelVolume != nil && fuelVolume!.compare(zero) != .OrderedDescending) {
			return false
		}

		return true
	}

	func createConsumptionRowWithAnimation(animation: UITableViewRowAnimation) {
		// Conversion units
		let odometerUnit: KSDistance
		let fuelUnit: KSVolume
		let consumptionUnit: KSFuelConsumption

		if let car = self.car {
			odometerUnit    = car.ksOdometerUnit
			fuelUnit        = car.ksFuelUnit
			consumptionUnit = car.ksFuelConsumptionUnit
		} else {
			odometerUnit    = Units.distanceUnitFromLocale
			fuelUnit        = Units.volumeUnitFromLocale
			consumptionUnit = Units.fuelConsumptionUnitFromLocale
		}

		// Compute the average consumption
		let cost = fuelVolume! * price!

		let liters      = Units.litersForVolume(fuelVolume!, withUnit:fuelUnit)
		let kilometers  = Units.kilometersForDistance(distance!, withUnit:odometerUnit)
		let consumption = Units.consumptionForKilometers(kilometers, liters:liters, inUnit:consumptionUnit)

		let consumptionString = String(format:"%@ %@ %@ %@",
                                        Formatters.sharedCurrencyFormatter.stringFromNumber(cost)!,
										NSLocalizedString("/", comment:""),
                                        Formatters.sharedFuelVolumeFormatter.stringFromNumber(consumption)!,
                                        Units.consumptionUnitString(consumptionUnit))


		// Substrings for highlighting
		let highlightStrings = [Formatters.sharedCurrencyFormatter.currencySymbol!,
								Units.consumptionUnitString(consumptionUnit)]

		addSectionAtIndex(1, withAnimation:animation)

		addRowAtIndex(rowIndex: 0,
              inSection:1,
              cellClass:ConsumptionTableCell.self,
               cellData:["label":consumptionString,
                         "highlightStrings":highlightStrings],
          withAnimation:animation)
	}

	private func createDataRows(rowMask: FuelCalculatorDataRow, withAnimation animation: UITableViewRowAnimation) {
		let odometerUnit: KSDistance
		let fuelUnit: KSVolume

		if let car = self.car {
			odometerUnit = car.ksOdometerUnit
			fuelUnit     = car.ksFuelUnit
		} else {
			odometerUnit = Units.distanceUnitFromLocale
			fuelUnit     = Units.volumeUnitFromLocale
		}

		let rowOffset = (self.fetchedResultsController.fetchedObjects!.count < 2) ? 1 : 2

		if rowMask & .Distance == .Distance {
			if self.distance == nil {
				self.distance = NSDecimalNumber(decimal: (NSUserDefaults.standardUserDefaults().objectForKey("recentDistance")! as! NSNumber).decimalValue)
			}

			addRowAtIndex(rowIndex: 0 + rowOffset,
                  inSection:0,
                  cellClass:NumberEditTableCell.self,
				   cellData:["label": NSLocalizedString("Distance", comment:""),
                             "suffix": " ".stringByAppendingString(Units.odometerUnitString(odometerUnit)),
                             "formatter": Formatters.sharedDistanceFormatter,
                             "valueIdentifier": "distance"],
              withAnimation:animation)
		}

		if rowMask & .Price == .Price {
			if self.price == nil {
				self.price = NSDecimalNumber(decimal: (NSUserDefaults.standardUserDefaults().objectForKey("recentPrice")! as! NSNumber).decimalValue)
			}

			addRowAtIndex(rowIndex: 1 + rowOffset,
                  inSection:0,
                  cellClass:NumberEditTableCell.self,
                   cellData:["label": Units.fuelPriceUnitDescription(fuelUnit),
							 "formatter": Formatters.sharedEditPreciseCurrencyFormatter,
                             "alternateFormatter": Formatters.sharedPreciseCurrencyFormatter,
                             "valueIdentifier": "price"],
              withAnimation:animation)
		}

		if rowMask & .Amount == .Amount {
			if self.fuelVolume == nil {
				self.fuelVolume = NSDecimalNumber(decimal: (NSUserDefaults.standardUserDefaults().objectForKey("recentFuelVolume")! as! NSNumber).decimalValue)
			}

			addRowAtIndex(rowIndex: 2 + rowOffset,
                  inSection:0,
                  cellClass:NumberEditTableCell.self,
                   cellData:["label": Units.fuelUnitDescription(fuelUnit, discernGallons:false, pluralization:true),
                             "suffix": " ".stringByAppendingString(Units.fuelUnitString(fuelUnit)),
                             "formatter": KSVolumeIsMetric(fuelUnit)
                                                ? Formatters.sharedFuelVolumeFormatter
                                                : Formatters.sharedPreciseFuelVolumeFormatter,
                             "valueIdentifier": "fuelVolume"],
              withAnimation:animation)
		}
	}

	private func createTableContentsWithAnimation(animation: UITableViewRowAnimation) {
		addSectionAtIndex(0, withAnimation:animation)

		// Car selector (optional)
		self.car = nil
    
		if self.fetchedResultsController.fetchedObjects?.count ?? 0 > 0 {
			self.car = AppDelegate.managedObjectForModelIdentifier(NSUserDefaults.standardUserDefaults().stringForKey("preferredCarID")!) as? Car

			if self.car == nil {
				self.car = self.fetchedResultsController.fetchedObjects!.first as? Car
			}

			if self.fetchedResultsController.fetchedObjects!.count > 1 {
				addRowAtIndex(rowIndex: 0,
                      inSection:0,
                      cellClass:CarTableCell.self,
					   cellData:["label": NSLocalizedString("Car", comment:""),
                                 "valueIdentifier": "car",
                                 "fetchedObjects": self.fetchedResultsController.fetchedObjects!],
                  withAnimation:animation)
			}
		}


		// Date selector
		if self.date == nil {
			self.date = NSDate.dateWithoutSeconds(NSDate())
		}

		if self.lastChangeDate == nil {
			self.lastChangeDate = NSDate()
		}

		addRowAtIndex(rowIndex: self.car != nil ? 1 : 0,
              inSection:0,
              cellClass:DateEditTableCell.self,
			   cellData:["label": NSLocalizedString("Date", comment:""),
                         "formatter": Formatters.sharedDateTimeFormatter,
                         "valueIdentifier": "date",
                         "valueTimestamp": "lastChangeDate",
                         "autorefresh": true],
          withAnimation:animation)

		// Data rows for distance, price, fuel amount
		createDataRows(.All, withAnimation:animation)

		// Full-fillup selector
		self.filledUp = NSUserDefaults.standardUserDefaults().boolForKey("recentFilledUp")

		if self.car != nil {
			addRowAtIndex(rowIndex: 5,
                  inSection:0,
                  cellClass:SwitchTableCell.self,
				   cellData:["label": NSLocalizedString("Full Fill-Up", comment:""),
                             "valueIdentifier": "filledUp"],
              withAnimation:animation)
		}

		// Consumption info (optional)
		if consumptionRowNeeded() {
			createConsumptionRowWithAnimation(animation)
		}
	}

	//MARK: - Updating the Table Rows

	func recreateTableContentsWithAnimation(anim: UITableViewRowAnimation) {
		// Update model contents
		let animation: UITableViewRowAnimation
		if tableSections.isEmpty {
			animation = .None
		} else {
			animation = anim
			removeAllSectionsWithAnimation(.None)
		}

		createTableContentsWithAnimation(.None)

		// Update the tableview
		if animation == .None {
			self.tableView?.reloadData()
		} else {
			self.tableView?.reloadSections(NSIndexSet(indexesInRange:NSRange (location: 0, length: self.tableView.numberOfSections())),
                      withRowAnimation:animation)
		}
	}

	private func recreateDataRowsWithPreviousCar(oldCar: Car?) {
		// Replace data rows in the internal data model
		for var row = 4; row >= 2; row-- {
			removeRowAtIndex(row, inSection:0, withAnimation:.None)
		}

		createDataRows(.All, withAnimation:.None)

		// Update the tableview
		let odoChanged = oldCar == nil || oldCar!.odometerUnit != self.car!.odometerUnit

		let fuelChanged = oldCar == nil || KSVolumeIsMetric(oldCar!.ksFuelUnit) != KSVolumeIsMetric(self.car!.ksFuelUnit)

		var count = 0

		for var row = 2; row <= 4; row++ {
			let animation: UITableViewRowAnimation
			if (row == 2 && odoChanged) || (row != 2 && fuelChanged) {
				animation = (count % 2) == 0 ? .Right : .Left
				count++
			} else {
				animation = .None
			}

			self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow:row, inSection:0)], withRowAnimation:animation)
		}

		// Reload date row too to get colors updates
		self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow:1, inSection:0)], withRowAnimation:.None)
	}

	private func recreateDistanceRowWithAnimation(animation: UITableViewRowAnimation) {
		let rowOffset = (self.fetchedResultsController.fetchedObjects!.count < 2) ? 1 : 2

		// Replace distance row in the internal data model
		removeRowAtIndex(rowOffset, inSection:0, withAnimation:.None)
		createDataRows(.Distance, withAnimation:.None)

		// Update the tableview
		if animation != .None {
			self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow:rowOffset, inSection:0)], withRowAnimation:animation)
		} else {
			self.tableView.reloadData()
		}
	}

	//MARK: - Locale Handling

	func localeChanged(object: AnyObject) {
		let previousSelection = self.tableView.indexPathForSelectedRow()
    
		dismissKeyboardWithCompletion {
			self.recreateTableContentsWithAnimation(.None)
			self.selectRowAtIndexPath(previousSelection)
		}
	}

	//MARK: - System Events

	func willEnterForeground(notification: NSNotification) {
		if tableSections.isEmpty || keyboardIsVisible {
			return
		}

		// Last update must be longer than 5 minutes ago
		let noChangeInterval: NSTimeInterval

		if let lastChangeDate = self.lastChangeDate {
			noChangeInterval = NSDate().timeIntervalSinceDate(lastChangeDate)
		} else {
			noChangeInterval = -1
		}

		if self.lastChangeDate == nil || noChangeInterval >= 300 || noChangeInterval < 0 {

			// Reset date to current time
			let now = NSDate()
			self.date = NSDate.dateWithoutSeconds(now)
			self.lastChangeDate = now

			// Update table
			let rowOffset = (self.fetchedResultsController.fetchedObjects?.count ?? 0 < 2) ? 0 : 1

			self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow:rowOffset, inSection:0)],
								withRowAnimation:.None)
		}
	}

	//MARK: - Programatically Selecting Table Rows

	func activateTextFieldAtIndexPath(indexPath: NSIndexPath) {
		let cell = self.tableView.cellForRowAtIndexPath(indexPath)!
		let field : UITextField?

		if let carCell = cell as? CarTableCell {
			field = carCell.textField
		} else if let dateCell = cell as? DateEditTableCell {
			field = dateCell.textField
		} else if let numberCell = cell as? NumberEditTableCell {
			field = numberCell.textField
		} else {
			field = nil
		}

		if let field = field {
			field.userInteractionEnabled = true
			field.becomeFirstResponder()
		}
	}

	private func selectRowAtIndexPath(indexPath: NSIndexPath?) {
		if let path = indexPath {
			self.tableView.selectRowAtIndexPath(path, animated:false, scrollPosition:.None)
			self.tableView(self.tableView, didSelectRowAtIndexPath:path)
		}
	}

	//MARK: - Storing Information in the Database

	func saveAction(sender: AnyObject) {
		self.navigationItem.rightBarButtonItem = nil
        
		UIView.animateWithDuration(0.3,
                     animations: {
                         // Remove consumption row
                         self.removeSectionAtIndex(1, withAnimation:.Fade)
                     },
                     completion: { finished in
                         // Add new event object
                         self.changeIsUserDriven = true

                         AppDelegate.addToArchiveWithCar(self.car!,
                                                     date:self.date!,
                                                 distance:self.distance!,
                                                    price:self.price!,
                                               fuelVolume:self.fuelVolume!,
                                                 filledUp:self.filledUp ?? false,
                                   inManagedObjectContext:self.managedObjectContext,
                                      forceOdometerUpdate:false)

                         // Reset calculator table
                         let zero = NSDecimalNumber.zero()

                         self.valueChanged(zero, identifier:"distance")
                         self.valueChanged(zero, identifier:"price")
                         self.valueChanged(zero, identifier:"fuelVolume")
                         self.valueChanged(true, identifier:"filledUp")

						UIApplication.kraftstoffAppDelegate.saveContext(self.managedObjectContext)
                     })
	}

	private func updateSaveButtonState() {
		var saveValid = true

		if self.car == nil {
			saveValid = false
		} else if (distance == nil || distance!.compare(NSDecimalNumber.zero()) == .OrderedSame) || (fuelVolume == nil || fuelVolume!.compare(NSDecimalNumber.zero()) == .OrderedSame) {
			saveValid = false
		} else if date == nil || AppDelegate.managedObjectContext(self.managedObjectContext, containsEventWithCar:self.car!, andDate:self.date!) {
			saveValid = false
		}

		self.navigationItem.rightBarButtonItem = saveValid ? self.saveButton : nil
	}


	//MARK: - Conversion for Odometer

	func needsOdometerConversionSheet() -> Bool {
		// A simple heuristics when to ask for distance cobversion
		if self.car == nil {
			return false
		}

		// 1.) entered "distance" must be larger than car odometer
		let odometerUnit = self.car!.ksOdometerUnit

		let rawDistance  = Units.kilometersForDistance(self.distance!, withUnit:odometerUnit)
		let convDistance = rawDistance - self.car!.odometer
    
		if NSDecimalNumber.zero().compare(convDistance) != .OrderedAscending {
			return false
		}
    
		// 2.) consumption with converted distances is more 'logical'
		let liters = Units.litersForVolume(fuelVolume!, withUnit:self.car!.ksFuelUnit)
    
		if NSDecimalNumber.zero().compare(liters) != .OrderedAscending {
			return false
		}

		let rawConsumption  = Units.consumptionForKilometers(rawDistance,
                                                                      liters:liters,
                                                                      inUnit:.LitersPer100km)

		if rawConsumption == NSDecimalNumber.notANumber() {
			return false
		}

		let convConsumption = Units.consumptionForKilometers(convDistance,
                                                                      liters:liters,
                                                                      inUnit:.LitersPer100km)
    
		if convConsumption == NSDecimalNumber.notANumber() {
			return false
		}

		let avgConsumption = Units.consumptionForKilometers(self.car!.distanceTotalSum,
                                                                     liters:self.car!.fuelVolumeTotalSum,
                                                                     inUnit:.LitersPer100km)
    
		let loBound: NSDecimalNumber
		let hiBound: NSDecimalNumber

		if avgConsumption == NSDecimalNumber.notANumber() {
			loBound = NSDecimalNumber(mantissa: 2, exponent:0, isNegative:false)
			hiBound = NSDecimalNumber(mantissa:20, exponent:0, isNegative:false)
		} else {
			loBound = avgConsumption * NSDecimalNumber(mantissa:5, exponent: -1, isNegative:false)
			hiBound = avgConsumption * NSDecimalNumber(mantissa:5, exponent:  0, isNegative:false)
		}
    
		// conversion only when rawConsumtion <= lowerBound
		if rawConsumption.compare(loBound) == .OrderedDescending {
			return false
		}

		// conversion only when lowerBound <= convConversion <= highBound
		if convConsumption.compare(loBound) == .OrderedAscending || convConsumption.compare(hiBound) == .OrderedDescending {
			return false
		}
    
		// 3.) the event must be the youngest one
		let youngerEvents = AppDelegate.objectsForFetchRequest(AppDelegate.fetchRequestForEventsForCar(self.car!,
																								afterDate:self.date!,
																							  dateMatches:false,
																				   inManagedObjectContext:self.managedObjectContext),
														inManagedObjectContext:self.managedObjectContext)
    
		if youngerEvents.count > 0 {
			return false
		}
    
		// => ask for a conversion
		return true
	}

	func showOdometerConversionAlert() {
		let odometerUnit = self.car!.ksOdometerUnit
		let rawDistance  = Units.kilometersForDistance(self.distance!, withUnit:odometerUnit)
		let convDistance = rawDistance - self.car!.odometer

		let distanceFormatter = Formatters.sharedDistanceFormatter

		let rawButton = String(format: "%@ %@",
                                distanceFormatter.stringFromNumber(Units.distanceForKilometers(rawDistance, withUnit:odometerUnit))!,
                                Units.odometerUnitString(odometerUnit))

		let convButton = String(format:"%@ %@",
                                distanceFormatter.stringFromNumber(Units.distanceForKilometers(convDistance, withUnit:odometerUnit))!,
								Units.odometerUnitString(odometerUnit))

		let alertController = UIAlertController(title:NSLocalizedString("Convert from odometer reading into distance? Please choose the distance driven:", comment:""),
																			 message:nil,
																	  preferredStyle:.ActionSheet)
		let cancelAction = UIAlertAction(title:rawButton, style:.Default) { _ in
			self.isShowingConvertSheet = false
			self.setEditing(false, animated:true)
		}

		let destructiveAction = UIAlertAction(title:convButton, style:.Destructive) { _ in
			self.isShowingConvertSheet = false

			// Replace distance in table with difference to car odometer
			let odometerUnit = self.car!.ksOdometerUnit
			let rawDistance  = Units.kilometersForDistance(self.distance!, withUnit:odometerUnit)
			let convDistance = rawDistance - self.car!.odometer

			self.distance = Units.distanceForKilometers(convDistance, withUnit:odometerUnit)
			self.valueChanged(self.distance, identifier:"distance")

			self.recreateDistanceRowWithAnimation(.Right)

			self.setEditing(false, animated:true)
		}

		alertController.addAction(cancelAction)
		alertController.addAction(destructiveAction)
		alertController.popoverPresentationController?.barButtonItem = self.navigationItem.leftBarButtonItem
		isShowingConvertSheet = true
		presentViewController(alertController, animated:true, completion:nil)
	}

	//MARK: - Leaving Editing Mode

	@IBAction func endEditingMode(sender: AnyObject) {
		dismissKeyboardWithCompletion {
			if self.needsOdometerConversionSheet() {
				self.showOdometerConversionAlert()
			} else {
				self.setEditing(false, animated:true)
			}
		}
    }

	//MARK: - EditablePageCellDelegate

	func valueForIdentifier(valueIdentifier: String) -> AnyObject? {
		switch valueIdentifier {
		case "car": return self.car
		case "date": return self.date
		case "lastChangeDate": return self.lastChangeDate
		case "distance": return self.distance
		case "price": return self.price
		case "fuelVolume": return self.fuelVolume
		case "filledUp": return self.filledUp
		default: return nil
		}
	}

	func valueChanged(newValue: AnyObject?, identifier valueIdentifier: String) {
		if let date = newValue as? NSDate {

			if valueIdentifier == "date" {
				self.date = NSDate.dateWithoutSeconds(date)
			} else if valueIdentifier == "lastChangeDate" {
				self.lastChangeDate = date
			}

		} else if let decimalNumber = newValue as? NSDecimalNumber {
			let recentKey: String?

			if valueIdentifier == "distance" {
				self.distance = decimalNumber
				recentKey = "recentDistance"
			} else if valueIdentifier == "fuelVolume" {
				self.fuelVolume = decimalNumber
				recentKey = "recentFuelVolume"
			} else if valueIdentifier == "price" {
				self.price = decimalNumber
				recentKey = "recentPrice"
			} else {
				recentKey = nil
			}

			if let recentKey = recentKey {
				let defaults = NSUserDefaults.standardUserDefaults()

				defaults.setObject(newValue, forKey:recentKey)
				defaults.synchronize()
			}

		} else if valueIdentifier == "filledUp" {
			self.filledUp = newValue!.boolValue

			let defaults = NSUserDefaults.standardUserDefaults()

			defaults.setObject(newValue, forKey:"recentFilledUp")
			defaults.synchronize()

		} else if valueIdentifier == "car" {
			if self.car == nil || !self.car!.isEqual(newValue) {
				let oldCar = self.car
				self.car = newValue as? Car
				recreateDataRowsWithPreviousCar(oldCar)
			}

			if !self.car!.objectID.temporaryID {
				let defaults = NSUserDefaults.standardUserDefaults()

				defaults.setObject(AppDelegate.modelIdentifierForManagedObject(self.car!), forKey:"preferredCarID")
				defaults.synchronize()
			}
		}
	}

	func valueValid(newValue: AnyObject?, identifier valueIdentifier: String) -> Bool {
		// Validate only when there is a car for saving
		if self.car == nil {
			return true
		}

		// Date must be collision free
		if let date = newValue as? NSDate {
			if valueIdentifier == "date" {
				if AppDelegate.managedObjectContext(self.managedObjectContext, containsEventWithCar:self.car!, andDate:date) {
					return false
				}
			}
		}

		// DecimalNumbers <= 0.0 are invalid
		if let decimalNumber = newValue as? NSDecimalNumber {
			if valueIdentifier != "price" {
				if decimalNumber.compare(NSDecimalNumber.zero()) != .OrderedDescending {
					return false
				}
			}
		}

		return true
	}

	//MARK: - NSFetchedResultsControllerDelegate

	func controllerDidChangeContent(controller: NSFetchedResultsController) {
		recreateTableContentsWithAnimation(changeIsUserDriven ? .Right : .None)
		updateSaveButtonState()

		changeIsUserDriven = false
	}

	//MARK: - UITableViewDataSource

	override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return nil
	}

	//MARK: - UITableViewDelegate

	func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
		let cell = tableView.cellForRowAtIndexPath(indexPath)

		if cell is SwitchTableCell || cell is ConsumptionTableCell {
			return nil
		}

		setEditing(true, animated:true)
		return indexPath
	}

	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		activateTextFieldAtIndexPath(indexPath)
		tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition:.Middle, animated:true)
	}

	//MARK: -

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

}
