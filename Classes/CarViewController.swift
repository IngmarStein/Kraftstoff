//
//  CarViewController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 05.05.15.
//
//

import UIKit
import CoreData
import CoreSpotlight

private let maxEditHelpCounter = 1
private let kSRCarViewEditedObject = "CarViewEditedObject"

final class CarViewController: UITableViewController, UIDataSourceModelAssociation, UIGestureRecognizerDelegate, NSFetchedResultsControllerDelegate, CarConfigurationControllerDelegate, UIViewControllerPreviewingDelegate {

	var editedObject: Car!

	private var _fetchedResultsController: NSFetchedResultsController?
	private var fetchedResultsController: NSFetchedResultsController {
		if _fetchedResultsController == nil {
			let fetchedResultsController = CoreDataManager.fetchedResultsControllerForCars()
			fetchedResultsController.delegate = self
			_fetchedResultsController = fetchedResultsController
		}
		return _fetchedResultsController!
	}

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

	// MARK: - View Lifecycle

	override func viewDidLoad() {
		super.viewDidLoad()

		changeIsUserDriven = false

		// Navigation Bar
		self.title = NSLocalizedString("Cars", comment: "")
		self.navigationItem.leftBarButtonItem = nil

		let rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target:self, action:#selector(CarViewController.insertNewObject(_:)))
		rightBarButtonItem.accessibilityIdentifier = "add"
		self.navigationItem.rightBarButtonItem = rightBarButtonItem

		// Gesture recognizer for touch and hold
		self.longPressRecognizer = UILongPressGestureRecognizer(target:self, action:#selector(CarViewController.handleLongPress(_:)))
		self.longPressRecognizer!.delegate = self

		// Reset tint color
		self.navigationController?.navigationBar.tintColor = nil

		// Background image
		let backgroundView = UIView(frame:CGRect.zero)
		backgroundView.backgroundColor = UIColor(red:CGFloat(0.935), green:CGFloat(0.935), blue:CGFloat(0.956), alpha:CGFloat(1.0))
		let backgroundImage = UIImageView(image:UIImage(named:"Pumps")!)
		backgroundImage.translatesAutoresizingMaskIntoConstraints = false
		backgroundView.addSubview(backgroundImage)
		backgroundView.addConstraint(NSLayoutConstraint(item:backgroundView, attribute: .bottom,  relatedBy: .equal, toItem:backgroundImage, attribute: .bottom,  multiplier: 1.0, constant: 90.0))
		backgroundView.addConstraint(NSLayoutConstraint(item:backgroundView, attribute: .centerX, relatedBy: .equal, toItem:backgroundImage, attribute: .centerX, multiplier: 1.0, constant: 0.0))
		self.tableView.backgroundView = backgroundView

		self.tableView.estimatedRowHeight = self.tableView.rowHeight
		self.tableView.rowHeight = UITableViewAutomaticDimension

		if traitCollection.forceTouchCapability == .available {
			registerForPreviewing(with: self, sourceView: view)
		}

		NSNotificationCenter.default().addObserver(self,
           selector:#selector(CarViewController.localeChanged(_:)),
               name:NSCurrentLocaleDidChangeNotification,
             object:nil)
		NSNotificationCenter.default().addObserver(self,
			selector: #selector(CarViewController.storesDidChange(_:)),
			name: NSPersistentStoreCoordinatorStoresDidChangeNotification,
			object: CoreDataManager.managedObjectContext.persistentStoreCoordinator!)
	}

	@objc func storesDidChange(_ notification: NSNotification) {
		_fetchedResultsController = nil
		NSFetchedResultsController.deleteCache(withName: nil)
		updateHelp(true)
		self.tableView.reloadData()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		updateHelp(true)
		checkEnableEditButton()
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		hideHelp(animated)
	}

	// MARK: - State Restoration

	override func encodeRestorableState(with coder: NSCoder) {
		if let editedObject = editedObject {
			coder.encode(CoreDataManager.modelIdentifierForManagedObject(editedObject), forKey:kSRCarViewEditedObject)
		}
		super.encodeRestorableState(with: coder)
	}

	override func decodeRestorableState(with coder: NSCoder) {
		super.decodeRestorableState(with: coder)

		if let modelIdentifier = coder.decodeObjectOfClass(NSString.self, forKey:kSRCarViewEditedObject) as? String {
			self.editedObject = CoreDataManager.managedObjectForModelIdentifier(modelIdentifier) as? Car
		}

		// -> openradar #13438788
		self.tableView.reloadData()
	}

	// MARK: - Locale Handling

	func localeChanged(_ object: AnyObject) {
		// Invalidate fuelEvent-controller and any precomputed statistics
		if self.navigationController!.topViewController === self {
			fuelEventController = nil
		}

		self.tableView.reloadData()
	}

	// MARK: - Help Badge

	private func updateHelp(_ animated: Bool) {
		let defaults = NSUserDefaults.standard()

		// Number of cars determines the help badge
		let helpImageName: String?
		let helpViewFrame: CGRect
		let helpViewContentMode: UIViewContentMode

		let carCount = fetchedResultsController.fetchedObjects!.count

		if !self.isEditing && carCount == 0 {
			helpImageName = "StartFlat"
			helpViewFrame = CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 70)
			helpViewContentMode = .right

			defaults.set(0, forKey:"editHelpCounter")
		} else if self.isEditing && 1 <= carCount && carCount <= 3 {
			let editCounter = defaults.integer(forKey: "editHelpCounter")

			if editCounter < maxEditHelpCounter {
				defaults.set(editCounter + 1, forKey: "editHelpCounter")
				helpImageName = "EditFlat"
				helpViewContentMode = .left
				helpViewFrame = CGRect(x: 0.0, y: CGFloat(carCount) * 91.0 - 16.0, width: self.view.bounds.size.width, height: 92.0)
			} else {
				helpImageName = nil
				helpViewContentMode = .left
				helpViewFrame = CGRect.zero
			}
		} else {
			helpImageName = nil
			helpViewContentMode = .left
			helpViewFrame = CGRect.zero
		}

		// Remove outdated help images
		var helpView = self.view.withTag(100) as? UIImageView

		if helpImageName == nil || (helpView != nil && helpView!.frame != helpViewFrame) {
			if animated {
				UIView.animate(withDuration: 0.33, delay:0.0, options: .curveEaseOut,
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
				let helpImage   = UIImage(named:NSLocalizedString(helpImageName, comment: ""))!.withRenderingMode(.alwaysTemplate)

				helpView        = UIImageView(image:helpImage)
				helpView!.tag   = 100
				helpView!.frame = helpViewFrame
				helpView!.alpha = animated ? 0.0 : 1.0
				helpView!.contentMode = helpViewContentMode

				self.view.addSubview(helpView!)

				if animated {
					UIView.animate(withDuration: 0.33,
										delay:0.8,
                                    options: .curveEaseOut,
                                 animations: { helpView!.alpha = 1.0 },
                                 completion: nil)
				}
			}
		}

		// Update the toolbar button
		self.navigationItem.leftBarButtonItem = (carCount == 0) ? nil : self.editButtonItem()
		checkEnableEditButton()
	}

	private func hideHelp(_ animated: Bool) {
		if let helpView = self.view.withTag(100) as? UIImageView {
			if animated {
				UIView.animate(withDuration: 0.33,
                                  delay: 0.0,
                                options: .curveEaseOut,
                             animations:{ helpView.alpha = 0.0 },
                             completion:{ finished in helpView.removeFromSuperview() })
			} else {
				helpView.removeFromSuperview()
			}
		}
	}

	// MARK: - CarConfigurationControllerDelegate

	func carConfigurationController(_ controller: CarConfigurationController, didFinishWithResult result: CarConfigurationResult) {
		if result == .CreateSucceeded {
			var addDemoContents = false

			// Update order of existing objects
			changeIsUserDriven = true

			for car in self.fetchedResultsController.fetchedObjects as! [Car] {
				car.order += 1
            }

            // Detect demo data request
            if controller.name!.lowercased() == "apple" && controller.plate!.lowercased() == "demo" {
                addDemoContents = true

                controller.name  = "Toyota IQ+"
                controller.plate = "SLS IOIOI"
            }

			changeIsUserDriven = false

			// Create a new instance of the entity managed by the fetched results controller.
			let newManagedObject = NSEntityDescription.insertNewObject(forEntityName: "car", into: CoreDataManager.managedObjectContext) as! Car

			newManagedObject.order = 0
			newManagedObject.timestamp = NSDate()
			newManagedObject.name = controller.name!
			newManagedObject.numberPlate = controller.plate!
			newManagedObject.odometerUnit = controller.odometerUnit!.int32Value

			newManagedObject.odometer = Units.kilometersForDistance(controller.odometer!,
														withUnit:KSDistance(rawValue: controller.odometerUnit!.int32Value)!)

			newManagedObject.fuelUnit = controller.fuelUnit!.int32Value
			newManagedObject.fuelConsumptionUnit = controller.fuelConsumptionUnit!.int32Value

			// Add demo contents
			if addDemoContents {
				DemoData.addDemoEvents(car: newManagedObject, inContext:CoreDataManager.managedObjectContext)
			}

			// Saving here is important here to get a stable objectID for the fuelEvent fetches
			CoreDataManager.saveContext()

		} else if result == .EditSucceeded {

			editedObject.name = controller.name!
			editedObject.numberPlate = controller.plate!
			editedObject.odometerUnit = controller.odometerUnit!.int32Value

			let odometer = max(Units.kilometersForDistance(controller.odometer!,
                                                              withUnit:KSDistance(rawValue: controller.odometerUnit!.int32Value)!), editedObject.distanceTotalSum)

			editedObject.odometer = odometer
			editedObject.fuelUnit = controller.fuelUnit!.int32Value
			editedObject.fuelConsumptionUnit = controller.fuelConsumptionUnit!.int32Value

			CoreDataManager.saveContext()

			// Invalidate fuelEvent-controller and any precomputed statistics
			fuelEventController = nil
		}

		self.editedObject = nil
		checkEnableEditButton()

		dismiss(animated: result != .Aborted, completion:nil)
	}

	// MARK: - Adding a new Object

	override func setEditing(_ editing: Bool, animated: Bool) {
		super.setEditing(editing, animated:animated)

		checkEnableEditButton()
		updateHelp(animated)

		// Force Core Data save after editing mode is finished
		if !editing {
			CoreDataManager.saveContext()
		}
	}

	private func checkEnableEditButton() {
		self.editButtonItem().isEnabled = fetchedResultsController.fetchedObjects!.count > 0
	}

	func insertNewObject(_ sender: AnyObject) {
		if !StoreManager.sharedInstance.checkCarCount() {
			StoreManager.sharedInstance.showBuyOptions(parent: self)
			return
		}

		setEditing(false, animated:true)

		let configurator = self.storyboard!.instantiateViewController(withIdentifier: "CarConfigurationController") as! CarConfigurationController
		configurator.delegate = self
		configurator.editingExistingObject = false

		let navController = UINavigationController(rootViewController:configurator)
		navController.restorationIdentifier = "CarConfigurationNavigationController"
		navController.navigationBar.tintColor = self.navigationController!.navigationBar.tintColor

		present(navController, animated:true, completion:nil)
	}

	// MARK: - UIGestureRecognizerDelegate

	@objc(gestureRecognizer:shouldReceiveTouch:) func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		// Editing mode must be enabled
		if self.isEditing {
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

	// MARK: - Gesture Recognizer for Editing an Existing Object

	func handleLongPress(_ sender: UILongPressGestureRecognizer) {
		if sender.state == .began {

			if let indexPath = self.tableView.indexPathForRow(at: sender.location(in: self.tableView)) {
				CoreDataManager.saveContext()
				self.editedObject = self.fetchedResultsController.object(at: indexPath) as! Car

				// Present modal car configurator
				let configurator = self.storyboard!.instantiateViewController(withIdentifier: "CarConfigurationController") as! CarConfigurationController
				configurator.delegate = self
				configurator.editingExistingObject = true

				configurator.name = editedObject.name

				if configurator.name!.characters.count > TextEditTableCell.DefaultMaximumTextFieldLength {
					configurator.name = ""
				}

				configurator.plate = editedObject.numberPlate

				if configurator.plate!.characters.count > TextEditTableCell.DefaultMaximumTextFieldLength {
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

				present(navController, animated:true, completion:nil)

				// Edit started => prevent edit help from now on
				NSUserDefaults.standard().set(maxEditHelpCounter, forKey:"editHelpCounter")

				// Quit editing mode
				setEditing(false, animated:true)
			}
		}
	}

	// MARK: - Removing an Existing Object

	func removeExistingObject(at indexPath: NSIndexPath) {
		guard let deletedObject = self.fetchedResultsController.object(at: indexPath) as? Car else {
			// catch nil objects
			return
		}

		let deletedObjectOrder = deletedObject.order

		// Invalidate preference for deleted car
		let preferredCarID = NSUserDefaults.standard().string(forKey: "preferredCarID")
		let deletedCarID = CoreDataManager.modelIdentifierForManagedObject(deletedObject)

		if deletedCarID == preferredCarID {
			NSUserDefaults.standard().set("", forKey:"preferredCarID")
		}

		// Delete the managed object for the given index path
		CoreDataManager.managedObjectContext.delete(deletedObject)
		CoreDataManager.saveContext()

		if let itemID = deletedCarID {
			CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [itemID], completionHandler: nil)
		}

		// Update order of existing objects
		changeIsUserDriven = true

		for managedObject in self.fetchedResultsController.fetchedObjects as! [Car] {
			let order = managedObject.order

			if order > deletedObjectOrder {
                managedObject.order = order-1
			}
        }

		CoreDataManager.saveContext()

		changeIsUserDriven = false

		// Exit editing mode after last object is deleted
		if self.isEditing {
			if self.fetchedResultsController.fetchedObjects!.count == 0 {
				setEditing(false, animated:true)
			}
		}
	}

	// MARK: - UITableViewDataSource

	func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {

		let tableCell = cell as! QuadInfoCell
		let managedObject = self.fetchedResultsController.object(at: indexPath) as! Car

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
			avgConsumption = Formatters.sharedFuelVolumeFormatter.string(from: Units.consumptionForKilometers(distance, liters:fuelVolume, inUnit:consumptionUnit))!
			tableCell.topRightAccessibilityLabel = avgConsumption
			tableCell.botRightAccessibilityLabel = consumptionUnit.accessibilityDescription
		} else {
			avgConsumption = NSLocalizedString("-", comment: "")
			tableCell.topRightAccessibilityLabel = NSLocalizedString("fuel mileage not available", comment: "")
			tableCell.botRightAccessibilityLabel = nil
		}

		tableCell.topRightLabel.text = avgConsumption
		tableCell.botRightLabel.text = consumptionUnit.localizedString
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		return self.fetchedResultsController.sections?.count ?? 0
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let sectionInfo = self.fetchedResultsController.sections![section]

		return sectionInfo.numberOfObjects
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: NSIndexPath) -> UITableViewCell {
		let CellIdentifier = "ShadedTableViewCell"

		var cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier) as? QuadInfoCell

		if cell == nil {
			cell = QuadInfoCell(style: .`default`, reuseIdentifier: CellIdentifier, enlargeTopRightLabel: true)
		}

		configureCell(cell!, atIndexPath:indexPath)

		return cell!
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: NSIndexPath) {
		if editingStyle == .delete {
			removeExistingObject(at: indexPath)
		}
	}

	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: NSIndexPath, to destinationIndexPath: NSIndexPath) {
		let basePath = sourceIndexPath.removingLastIndex()

		if basePath.compare(destinationIndexPath.removingLastIndex()) != .orderedSame {
			fatalError("Invalid index path for moveRow")
		}

		let cmpResult = sourceIndexPath.compare(destinationIndexPath)
		let length = sourceIndexPath.length
		let from: Int
		let to: Int

		if cmpResult == .orderedAscending {
			from = sourceIndexPath.index(atPosition: length - 1)
			to   = destinationIndexPath.index(atPosition: length - 1)
		} else if cmpResult == .orderedDescending {
			to   = sourceIndexPath.index(atPosition: length - 1)
			from = destinationIndexPath.index(atPosition: length - 1)
		} else {
			return
		}

		for i in from...to {
			let managedObject = self.fetchedResultsController.object(at: basePath.adding(i)) as! Car
			var order = Int(managedObject.order)

			if cmpResult == .orderedAscending {
				order = (i != from) ? order-1 : to
			} else {
				order = (i != to)   ? order+1 : from
			}

			managedObject.order = Int32(order)
		}

		changeIsUserDriven = true
	}

	override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: NSIndexPath) -> Bool {
		return true
	}

	// MARK: - UIDataSourceModelAssociation

	@objc(indexPathForElementWithModelIdentifier:inView:)
	func indexPathForElement(withModelIdentifier identifier: String, in view: UIView) -> NSIndexPath? {
		let object = CoreDataManager.managedObjectForModelIdentifier(identifier)!

		return self.fetchedResultsController.indexPath(for: object)
	}

	@objc(modelIdentifierForElementAtIndexPath:inView:)
	func modelIdentifierForElement(at idx: NSIndexPath, in view: UIView) -> String? {
		let object = self.fetchedResultsController.object(at: idx) as! NSManagedObject

		return CoreDataManager.modelIdentifierForManagedObject(object)
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: NSIndexPath, toProposedIndexPath proposedDestinationIndexPath: NSIndexPath) -> NSIndexPath {
		return proposedDestinationIndexPath
	}

	override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: NSIndexPath) -> NSIndexPath? {
		return self.isEditing ? nil : indexPath
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: NSIndexPath) {
		let selectedCar = self.fetchedResultsController.object(at: indexPath) as! Car

		if fuelEventController == nil || fuelEventController.selectedCar != selectedCar {
			fuelEventController = self.storyboard!.instantiateViewController(withIdentifier: "FuelEventController") as! FuelEventController
			fuelEventController.selectedCar = selectedCar
		}

		self.navigationController?.pushViewController(fuelEventController, animated:true)
	}

	override func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: NSIndexPath) {
		editButtonItem().isEnabled = false
		hideHelp(true)
	}

	override func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: NSIndexPath) {
		checkEnableEditButton()
		updateHelp(true)
	}

	// MARK: - NSFetchedResultsControllerDelegate

	@objc(controllerWillChangeContent:) func controllerWillChangeContent(_ controller: NSFetchedResultsController) {
		self.tableView.beginUpdates()
	}

	func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, at sectionIndex: Int, for type: NSFetchedResultsChangeType) {
		switch type {
        case .insert:
            self.tableView.insertSections(NSIndexSet(index:sectionIndex), with: .fade)
        case .delete:
			self.tableView.deleteSections(NSIndexSet(index:sectionIndex), with: .fade)
		case .move, .update:
			self.tableView.reloadSections(NSIndexSet(index:sectionIndex), with: .fade)
		}
	}

	// see https://forums.developer.apple.com/thread/4999 why this currently crashes on iOS 9
	@objc(controller:didChangeObject:atIndexPath:forChangeType:newIndexPath:) func controller(_ controller: NSFetchedResultsController, didChange anObject: AnyObject, at indexPath: NSIndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
		if changeIsUserDriven {
			return
		}

		switch type {
        case .insert:
			if let newIndexPath = newIndexPath {
				tableView.insertRows(at: [newIndexPath], with: .fade)
			}
        case .delete:
			if let indexPath = indexPath {
				tableView.deleteRows(at: [indexPath], with: .fade)
			}
        case .move:
			if let indexPath = indexPath, newIndexPath = newIndexPath where indexPath != newIndexPath {
				tableView.deleteRows(at: [indexPath], with: .fade)
				tableView.insertRows(at: [newIndexPath], with: .fade)
			}
        case .update:
			if let indexPath = indexPath {
				tableView.reloadRows(at: [indexPath], with: .automatic)
			}
		}
	}

	@objc(controllerDidChangeContent:) func controllerDidChangeContent(_ controller: NSFetchedResultsController) {
		self.tableView.endUpdates()

		updateHelp(true)
		checkEnableEditButton()

		changeIsUserDriven = false
	}

	// MARK: - UIViewControllerPreviewingDelegate

	@objc(previewingContext:viewControllerForLocation:)
	func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
		guard let indexPath = tableView.indexPathForRow(at: location),
			cell = tableView.cellForRow(at: indexPath),
			selectedCar = self.fetchedResultsController.object(at: indexPath) as? Car else { return nil }

		guard let fuelEventController = storyboard?.instantiateViewController(withIdentifier: "FuelEventController") as? FuelEventController else { return nil }
		fuelEventController.selectedCar = selectedCar

		previewingContext.sourceRect = cell.frame

		return fuelEventController
	}

	@objc(previewingContext:commitViewController:)
	func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
		show(viewControllerToCommit, sender: self)
	}

	// MARK: - Memory Management

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()

		if self.navigationController!.topViewController === self {
			fuelEventController = nil
		}
	}

	deinit {
		NSNotificationCenter.default().removeObserver(self)
	}
}
