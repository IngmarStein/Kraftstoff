//
//  CarViewController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 05.05.15.
//
//

import UIKit
import CoreData

private let maxEditHelpCounter = 1
private let kSRCarViewEditedObject = "CarViewEditedObject"

class CarViewController: UITableViewController, UIDataSourceModelAssociation, UIGestureRecognizerDelegate, NSFetchedResultsControllerDelegate, CarConfigurationControllerDelegate {

	private let managedObjectContext: NSManagedObjectContext = AppDelegate.managedObjectContext

	var editedObject: Car!

	private lazy var fetchedResultsController: NSFetchedResultsController = {
		let fetchedResultsController = AppDelegate.fetchedResultsControllerForCarsInContext(self.managedObjectContext)
		fetchedResultsController.delegate = self
		return fetchedResultsController
	}()

	private var longPressRecognizer: UILongPressGestureRecognizer? {
		didSet {
			if let old = oldValue {
				tableView.removeGestureRecognizer(old)
			}
			if let new = longPressRecognizer {
				tableView.addGestureRecognizer(new)
			}
		}
	}

	var fuelEventController: FuelEventController!

	private var changeIsUserDriven = false

	//MARK: - View Lifecycle

	override func viewDidLoad() {
		super.viewDidLoad()

		changeIsUserDriven = false

		// Navigation Bar
		self.title = NSLocalizedString("Cars", comment:"")
		self.navigationItem.leftBarButtonItem = nil
		self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem:.Add, target:self, action:"insertNewObject:")

		// Gesture recognizer for touch and hold
		self.longPressRecognizer = UILongPressGestureRecognizer(target:self, action:"handleLongPress:")
		self.longPressRecognizer!.delegate = self

		// Reset tint color
		self.navigationController?.navigationBar.tintColor = nil

		// Background image
		let backgroundView = UIView(frame:CGRectZero)
		backgroundView.backgroundColor = UIColor(red:0.935, green:0.935, blue:0.956, alpha:1.0)
		let backgroundImage = UIImageView(image:UIImage(named:"Pumps")!)
		backgroundImage.setTranslatesAutoresizingMaskIntoConstraints(false)
		backgroundView.addSubview(backgroundImage)
		backgroundView.addConstraint(NSLayoutConstraint(item:backgroundView, attribute:.Bottom,  relatedBy:.Equal, toItem:backgroundImage, attribute:.Bottom,  multiplier:1.0, constant:90.0))
		backgroundView.addConstraint(NSLayoutConstraint(item:backgroundView, attribute:.CenterX, relatedBy:.Equal, toItem:backgroundImage, attribute:.CenterX, multiplier:1.0, constant:0.0))
		self.tableView.backgroundView = backgroundView

		self.tableView.estimatedRowHeight = self.tableView.rowHeight
		self.tableView.rowHeight = UITableViewAutomaticDimension

		NSNotificationCenter.defaultCenter().addObserver(self,
           selector:"localeChanged:",
               name:NSCurrentLocaleDidChangeNotification,
             object:nil)
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)

		updateHelp(true)
		checkEnableEditButton()
	}

	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)

		hideHelp(animated)
	}

	//MARK: - State Restoration

	override func encodeRestorableStateWithCoder(coder: NSCoder) {
		if let editedObject = editedObject {
			coder.encodeObject(AppDelegate.modelIdentifierForManagedObject(editedObject), forKey:kSRCarViewEditedObject)
		}
		super.encodeRestorableStateWithCoder(coder)
	}

	override func decodeRestorableStateWithCoder(coder: NSCoder) {
		super.decodeRestorableStateWithCoder(coder)

		if let modelIdentifier = coder.decodeObjectOfClass(NSString.self, forKey:kSRCarViewEditedObject) as? String {
			self.editedObject = AppDelegate.managedObjectForModelIdentifier(modelIdentifier) as? Car
		}

		// -> openradar #13438788
		self.tableView.reloadData()
	}

	//MARK: - Locale Handling

	func localeChanged(object: AnyObject) {
		// Invalidate fuelEvent-controller and any precomputed statistics
		if self.navigationController!.topViewController === self {
			fuelEventController = nil
		}

		self.tableView.reloadData()
	}

	//MARK: - Help Badge

	private func updateHelp(animated: Bool) {
		let defaults = NSUserDefaults.standardUserDefaults()

		// Number of cars determins the help badge
		let helpImageName: String?
		let helpViewFrame: CGRect
		let helpViewContentMode: UIViewContentMode

		let carCount = fetchedResultsController.fetchedObjects!.count

		if !self.editing && carCount == 0 {
			helpImageName = "StartFlat"
			helpViewFrame = CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 70)
			helpViewContentMode = .Right

			defaults.setInteger(0, forKey:"editHelpCounter")
		} else if self.editing && 1 <= carCount && carCount <= 3 {
			let editCounter = defaults.integerForKey("editHelpCounter")

			if editCounter < maxEditHelpCounter {
				defaults.setInteger(editCounter + 1, forKey: "editHelpCounter")
				helpImageName = "EditFlat"
				helpViewContentMode = .Left
				helpViewFrame = CGRect(x: 0.0, y: CGFloat(carCount) * 91.0 - 16.0, width: self.view.bounds.size.width, height: 92.0)
			} else {
				helpImageName = nil
				helpViewContentMode = .Left
				helpViewFrame = CGRectZero
			}
		} else {
			helpImageName = nil
			helpViewContentMode = .Left
			helpViewFrame = CGRectZero
		}

		// Remove outdated help images
		var helpView = self.view.viewWithTag(100) as? UIImageView

		if helpImageName == nil || (helpView != nil && !CGRectEqualToRect(helpView!.frame, helpViewFrame)) {
			if animated {
				UIView.animateWithDuration(0.33, delay:0.0, options:.CurveEaseOut,
                             animations: { helpView?.alpha = 0.0 },
                             completion: { finished in helpView?.removeFromSuperview() })
			} else {
				helpView?.removeFromSuperview()
			}
		}

		// Add or update existing help image
		if let helpImageName = helpImageName {
			if let helpView = helpView {
				helpView.image = UIImage(named:helpImageName)
				helpView.frame = helpViewFrame
			} else {
				let helpImage  = UIImage(named:NSLocalizedString(helpImageName, comment:""))!.imageWithRenderingMode(.AlwaysTemplate)

				helpView       = UIImageView(image:helpImage)
				helpView!.tag   = 100
				helpView!.frame = helpViewFrame
				helpView!.alpha = animated ? 0.0 : 1.0
				helpView!.contentMode = helpViewContentMode

				self.view.addSubview(helpView!)

				if animated {
					UIView.animateWithDuration(0.33,
										delay:0.8,
                                    options:.CurveEaseOut,
                                 animations: { helpView!.alpha = 1.0 },
                                 completion: nil)
				}
			}
		}

		// Update the toolbar button
		self.navigationItem.leftBarButtonItem = (carCount == 0) ? nil : self.editButtonItem()
	}

	private func hideHelp(animated: Bool) {
		if let helpView = self.view.viewWithTag(100) as? UIImageView {
			if animated {
				UIView.animateWithDuration(0.33,
                                  delay:0.0,
                                options:.CurveEaseOut,
                             animations:{ helpView.alpha = 0.0 },
                             completion:{ finished in helpView.removeFromSuperview() })
			} else {
				helpView.removeFromSuperview()
			}
		}
	}

	//MARK: - CarConfigurationControllerDelegate

	func carConfigurationController(controller: CarConfigurationController, didFinishWithResult result: CarConfigurationResult) {
		if result == .CreateSucceeded {
			var addDemoContents = false

			// Update order of existing objects
			changeIsUserDriven = true

			for car in self.fetchedResultsController.fetchedObjects as! [Car] {
				car.order = car.order + 1
            }

            // Detect demo data request
            if controller.name!.lowercaseString == "apple" && controller.plate!.lowercaseString == "demo" {
                addDemoContents = true

                controller.name  = "Toyota IQ+"
                controller.plate = "SLS IOIOI"
            }

			changeIsUserDriven = false

			// Create a new instance of the entity managed by the fetched results controller.
			let newManagedObject = NSEntityDescription.insertNewObjectForEntityForName("car", inManagedObjectContext:managedObjectContext) as! Car

			newManagedObject.order = 0
			newManagedObject.timestamp = NSDate()
			newManagedObject.name = controller.name!
			newManagedObject.numberPlate = controller.plate!
			newManagedObject.odometerUnit = controller.odometerUnit!.intValue

			newManagedObject.odometer = Units.kilometersForDistance(controller.odometer!,
														withUnit:KSDistance(rawValue: controller.odometerUnit!.intValue)!)

			newManagedObject.fuelUnit = controller.fuelUnit!.intValue
			newManagedObject.fuelConsumptionUnit = controller.fuelConsumptionUnit!.intValue

			// Add demo contents
			if addDemoContents {
				DemoData.addDemoEventsForCar(newManagedObject, inContext:managedObjectContext)
			}

			// Saving here is important here to get a stable objectID for the fuelEvent fetches
			UIApplication.kraftstoffAppDelegate.saveContext(managedObjectContext)

		} else if result == .EditSucceeded {

			editedObject.name = controller.name!
			editedObject.numberPlate = controller.plate!
			editedObject.odometerUnit = controller.odometerUnit!.intValue

			let odometer = max(Units.kilometersForDistance(controller.odometer!,
                                                              withUnit:KSDistance(rawValue: controller.odometerUnit!.intValue)!), editedObject.distanceTotalSum)

			editedObject.odometer = odometer
			editedObject.fuelUnit = controller.fuelUnit!.intValue
			editedObject.fuelConsumptionUnit = controller.fuelConsumptionUnit!.intValue

			UIApplication.kraftstoffAppDelegate.saveContext(managedObjectContext)

			// Invalidate fuelEvent-controller and any precomputed statistics
			fuelEventController = nil
		}

		self.editedObject = nil
		checkEnableEditButton()

		dismissViewControllerAnimated(result != .Aborted, completion:nil)
	}

	//MARK: - Adding a new Object

	override func setEditing(editing: Bool, animated: Bool) {
		super.setEditing(editing, animated:animated)

		checkEnableEditButton()
		updateHelp(animated)

		// Force Core Data save after editing mode is finished
		if !editing {
			UIApplication.kraftstoffAppDelegate.saveContext(managedObjectContext)
		}
	}

	private func checkEnableEditButton() {
		self.editButtonItem().enabled = fetchedResultsController.fetchedObjects!.count > 0
	}

	func insertNewObject(sender: AnyObject) {
		setEditing(false, animated:true)

		let configurator = self.storyboard!.instantiateViewControllerWithIdentifier("CarConfigurationController") as! CarConfigurationController
		configurator.delegate = self
		configurator.editingExistingObject = false

		let navController = UINavigationController(rootViewController:configurator)
		navController.restorationIdentifier = "CarConfigurationNavigationController"
		navController.navigationBar.tintColor = self.navigationController!.navigationBar.tintColor

		presentViewController(navController, animated:true, completion:nil)
	}

	//MARK: - UIGestureRecognizerDelegate

	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
		// Editing mode must be enabled
		if self.editing {
			var view: UIView? = touch.view

			// Touch must hit the contentview of a tableview cell
			while view != nil {
				if let tableViewCell = view as? UITableViewCell {
					return tableViewCell.contentView === touch.view
				}

				view = view!.superview
			}
		}

		return false
	}

	//MARK: - Gesture Recognizer for Editing an Existing Object

	func handleLongPress(sender: UILongPressGestureRecognizer) {
		if sender.state == .Began {

			if let indexPath = self.tableView.indexPathForRowAtPoint(sender.locationInView(self.tableView)) {
				UIApplication.kraftstoffAppDelegate.saveContext(managedObjectContext)
				self.editedObject = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Car

				// Present modal car configurator
				let configurator = self.storyboard!.instantiateViewControllerWithIdentifier("CarConfigurationController") as! CarConfigurationController
				configurator.delegate = self
				configurator.editingExistingObject = true

				configurator.name = editedObject.name

				if count(configurator.name!) > TextEditTableCell.maximumTextFieldLength {
					configurator.name = ""
				}

				configurator.plate = editedObject.numberPlate

				if count(configurator.plate!) > TextEditTableCell.maximumTextFieldLength {
					configurator.plate = ""
				}

				configurator.odometerUnit = Int(editedObject.odometerUnit)
				configurator.odometer     = Units.distanceForKilometers(editedObject.odometer,
                                                                  withUnit:editedObject.ksOdometerUnit)

				configurator.fuelUnit            = Int(editedObject.fuelUnit)
				configurator.fuelConsumptionUnit = Int(editedObject.fuelConsumptionUnit)

				let navController = UINavigationController(rootViewController:configurator)
				navController.restorationIdentifier = "CarConfigurationNavigationController"
				navController.navigationBar.tintColor = self.navigationController!.navigationBar.tintColor

				presentViewController(navController, animated:true, completion:nil)

				// Edit started => prevent edit help from now on
				NSUserDefaults.standardUserDefaults().setInteger(maxEditHelpCounter, forKey:"editHelpCounter")

				// Quit editing mode
				setEditing(false, animated:true)
			}
		}
	}

	//MARK: - Removing an Existing Object

	func removeExistingObjectAtPath(indexPath: NSIndexPath) {
		let appDelegate = UIApplication.kraftstoffAppDelegate

		let deletedObject = self.fetchedResultsController.objectAtIndexPath(indexPath) as? Car

		// catch nil objects
		if deletedObject == nil {
			return
		}

		let deletedObjectOrder = deletedObject!.order

		// Invalidate preference for deleted car
		let preferredCarID = NSUserDefaults.standardUserDefaults().stringForKey("preferredCarID")
		let deletedCarID = AppDelegate.modelIdentifierForManagedObject(deletedObject!)

		if deletedCarID == preferredCarID {
			NSUserDefaults.standardUserDefaults().setObject("", forKey:"preferredCarID")
		}

		// Delete the managed object for the given index path
		managedObjectContext.deleteObject(deletedObject!)
		appDelegate.saveContext(managedObjectContext)

		// Update order of existing objects
		changeIsUserDriven = true

		for managedObject in self.fetchedResultsController.fetchedObjects as! [Car] {
			let order = managedObject.order

			if order > deletedObjectOrder {
                managedObject.order = order-1
			}
        }

		appDelegate.saveContext(managedObjectContext)

		changeIsUserDriven = false

		// Exit editing mode after last object is deleted
		if self.editing {
			if self.fetchedResultsController.fetchedObjects!.count == 0 {
				setEditing(false, animated:true)
			}
		}
	}

	//MARK: - UITableViewDataSource

	func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {

		let tableCell = cell as! QuadInfoCell
		let managedObject = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Car

		// Car and Numberplate
		tableCell.topLeftLabel.text = managedObject.name
		tableCell.topLeftAccessibilityLabel = nil

		tableCell.botLeftLabel.text = managedObject.numberPlate
		tableCell.topRightAccessibilityLabel = nil

		// Average consumption
		let avgConsumption: String
		let consumptionUnit = managedObject.ksFuelConsumptionUnit

		let distance   = managedObject.distanceTotalSum
		let fuelVolume = managedObject.fuelVolumeTotalSum

		if distance > NSDecimalNumber.zero() && fuelVolume > NSDecimalNumber.zero() {
			avgConsumption = Formatters.sharedFuelVolumeFormatter.stringFromNumber(Units.consumptionForKilometers(distance, liters:fuelVolume, inUnit:consumptionUnit))!
			tableCell.topRightAccessibilityLabel = avgConsumption
			tableCell.botRightAccessibilityLabel = Units.consumptionUnitAccessibilityDescription(consumptionUnit)
		} else {
			avgConsumption = NSLocalizedString("-", comment:"")
			tableCell.topRightAccessibilityLabel = NSLocalizedString("fuel mileage not available", comment:"")
			tableCell.botRightAccessibilityLabel = nil
		}

		tableCell.topRightLabel.text = avgConsumption
		tableCell.botRightLabel.text = Units.consumptionUnitString(consumptionUnit)
	}

	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return self.fetchedResultsController.sections?.count ?? 0
	}

	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo

		return sectionInfo.numberOfObjects
	}

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let CellIdentifier = "ShadedTableViewCell"

		var cell = tableView.dequeueReusableCellWithIdentifier(CellIdentifier) as? QuadInfoCell

		if cell == nil {
			cell = QuadInfoCell(style:.Default, reuseIdentifier:CellIdentifier, enlargeTopRightLabel:true)
		}

		configureCell(cell!, atIndexPath:indexPath)

		return cell!
	}

	override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		if editingStyle == .Delete {
			removeExistingObjectAtPath(indexPath)
		}
	}

	override func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
		let basePath = sourceIndexPath.indexPathByRemovingLastIndex()

		if basePath.compare(destinationIndexPath.indexPathByRemovingLastIndex()) != .OrderedSame {
			fatalError("Invalid index path for moveRow")
		}

		let cmpResult = sourceIndexPath.compare(destinationIndexPath)
		let length = sourceIndexPath.length
		let from: Int
		let to: Int

		if cmpResult == .OrderedAscending {
			from = sourceIndexPath.indexAtPosition(length - 1)
			to   = destinationIndexPath.indexAtPosition(length - 1)
		} else if cmpResult == .OrderedDescending {
			to   = sourceIndexPath.indexAtPosition(length - 1)
			from = destinationIndexPath.indexAtPosition(length - 1)
		} else {
			return
		}

		for var i = from; i <= to; i++ {
			let managedObject = self.fetchedResultsController.objectAtIndexPath(basePath.indexPathByAddingIndex(i)) as! Car
			var order = Int(managedObject.order)

			if cmpResult == .OrderedAscending {
				order = (i != from) ? order-1 : to
			} else {
				order = (i != to)   ? order+1 : from
			}

			managedObject.order = Int32(order)
		}

		changeIsUserDriven = true
	}

	override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		return true
	}

	//MARK: - UIDataSourceModelAssociation

	func indexPathForElementWithModelIdentifier(identifier: String, inView view: UIView) -> NSIndexPath? {
		let object = AppDelegate.managedObjectForModelIdentifier(identifier)!

		return self.fetchedResultsController.indexPathForObject(object)
	}

	func modelIdentifierForElementAtIndexPath(idx: NSIndexPath, inView view: UIView) -> String {
		let object = self.fetchedResultsController.objectAtIndexPath(idx) as! NSManagedObject

		return AppDelegate.modelIdentifierForManagedObject(object)!
	}

	//MARK: - UITableViewDelegate

	override func tableView(tableView: UITableView, targetIndexPathForMoveFromRowAtIndexPath sourceIndexPath: NSIndexPath, toProposedIndexPath proposedDestinationIndexPath: NSIndexPath) -> NSIndexPath {
		return proposedDestinationIndexPath
	}

	override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
		return self.editing ? nil : indexPath
	}

	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		let selectedCar = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Car

		if fuelEventController == nil || fuelEventController.selectedCar != selectedCar {
			fuelEventController = self.storyboard!.instantiateViewControllerWithIdentifier("FuelEventController") as! FuelEventController
			fuelEventController.managedObjectContext = managedObjectContext
			fuelEventController.selectedCar          = selectedCar
		}

		self.navigationController?.pushViewController(fuelEventController, animated:true)
	}

	override func tableView(tableView: UITableView, willBeginEditingRowAtIndexPath indexPath: NSIndexPath) {
		editButtonItem().enabled = false
		hideHelp(true)
	}

	override func tableView(tableView: UITableView, didEndEditingRowAtIndexPath indexPath: NSIndexPath) {
		checkEnableEditButton()
		updateHelp(true)
	}

	//MARK: - NSFetchedResultsControllerDelegate

	func controllerWillChangeContent(controller: NSFetchedResultsController) {
		self.tableView.beginUpdates()
	}

	func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
		switch type {
        case .Insert:
            self.tableView.insertSections(NSIndexSet(index:sectionIndex), withRowAnimation:.Fade)
        case .Delete:
			self.tableView.deleteSections(NSIndexSet(index:sectionIndex), withRowAnimation:.Fade)
		case .Move, .Update:
			self.tableView.reloadSections(NSIndexSet(index:sectionIndex), withRowAnimation:.Fade)
		}
	}

	func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
		if changeIsUserDriven {
			return
		}

		switch type {
        case .Insert:
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation:.Fade)
        case .Delete:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation:.Fade)
        case .Move:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation:.Fade)

            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation:.Fade)
        case .Update:
            tableView.reloadRowsAtIndexPaths([indexPath!], withRowAnimation:.Automatic)
		}
	}

	func controllerDidChangeContent(controller: NSFetchedResultsController) {
		self.tableView.endUpdates()

		updateHelp(true)
		checkEnableEditButton()

		changeIsUserDriven = false
	}

	//MARK: - Memory Management

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()

		if self.navigationController!.topViewController === self {
			fuelEventController = nil
		}
	}

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
}
