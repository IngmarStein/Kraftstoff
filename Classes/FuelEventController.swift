//
//  FuelEventController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 06.05.15.
//
//

import UIKit
import CoreData
import MessageUI

private let kSRFuelEventSelectedCarID     = "FuelEventSelectedCarID"
private let kSRFuelEventExportSheet       = "FuelEventExportSheet"
private let kSRFuelEventShowOpenIn        = "FuelEventShowOpenIn"
private let kSRFuelEventShowComposer      = "FuelEventShowMailComposer"

class FuelEventController: UITableViewController, UIDataSourceModelAssociation, UIViewControllerRestoration, NSFetchedResultsControllerDelegate, MFMailComposeViewControllerDelegate, UIDocumentInteractionControllerDelegate {

	var selectedCar: Car!

	private lazy var fetchRequest: NSFetchRequest = {
		return CoreDataManager.fetchRequestForEventsForCar(self.selectedCar,
			afterDate:nil,
			dateMatches:true)
	}()

	private lazy var fetchedResultsController: NSFetchedResultsController = {
		let fetchController = NSFetchedResultsController(fetchRequest:self.fetchRequest,
			managedObjectContext:CoreDataManager.managedObjectContext,
			sectionNameKeyPath:nil,
			cacheName:nil)

		fetchController.delegate = self

		// Perform the data fetch
		var error: NSError?

		if !fetchController.performFetch(&error) {
			fatalError(error!.localizedDescription)
		}

		return fetchController
	}()

	private var statisticsController: FuelStatisticsPageController!

	private var isShowingAlert = false
	private var isObservingRotationEvents = false
	private var isPerformingRotation = false
	private var isShowingExportSheet = false
	private var restoreExportSheet = false
	private var restoreOpenIn = false
	private var restoreMailComposer = false

	private var openInController: UIDocumentInteractionController!
	private var mailComposeController: MFMailComposeViewController!

	//MARK: - View Lifecycle

	required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		self.restorationClass = self.dynamicType
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		statisticsController = self.storyboard!.instantiateViewControllerWithIdentifier("FuelStatisticsPageController") as! FuelStatisticsPageController

		// Configure root view
		self.title = selectedCar.name

		// Export button in navigation bar
		self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem:.Action, target:self, action:"showExportSheet:")

		self.navigationItem.rightBarButtonItem!.enabled = false

		// Reset tint color
		self.navigationController?.navigationBar.tintColor = nil

		// Background image
		let backgroundView = UIView(frame:CGRectZero)
		backgroundView.backgroundColor = UIColor(red:0.935, green:0.935, blue:0.956, alpha:1.0)
		let backgroundImage = UIImageView(image:UIImage(named:"Pumps"))
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

		// Dismiss any presented view controllers
		if presentedViewController != nil {
			dismissViewControllerAnimated(false, completion:nil)
		}
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)

		validateExport()
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)

		setObserveDeviceRotation(true)

		if restoreExportSheet {
			showExportSheet(nil)
		} else if restoreOpenIn {
			showOpenIn(nil)
		} else if restoreMailComposer {
			showMailComposer(nil)
		}
	}

	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)

		if presentedViewController == nil {
			setObserveDeviceRotation(false)
		}
	}

	//MARK: - State Restoration

	static func viewControllerWithRestorationIdentifierPath(identifierComponents: [AnyObject], coder: NSCoder) -> UIViewController? {
		if let storyboard = coder.decodeObjectOfClass(UIStoryboard.self, forKey:UIStateRestorationViewControllerStoryboardKey) as? UIStoryboard {
			let controller = storyboard.instantiateViewControllerWithIdentifier("FuelEventController") as! FuelEventController
			let modelIdentifier = coder.decodeObjectOfClass(NSString.self, forKey:kSRFuelEventSelectedCarID) as! String
			controller.selectedCar = CoreDataManager.managedObjectForModelIdentifier(modelIdentifier) as? Car

			if controller.selectedCar == nil {
				return nil
			}

			return controller
		}
		return nil
	}

	override func encodeRestorableStateWithCoder(coder: NSCoder) {
		coder.encodeObject(CoreDataManager.modelIdentifierForManagedObject(selectedCar), forKey:kSRFuelEventSelectedCarID)
		coder.encodeBool(restoreExportSheet || isShowingExportSheet, forKey:kSRFuelEventExportSheet)
		coder.encodeBool(restoreOpenIn || (openInController != nil), forKey:kSRFuelEventShowOpenIn)
		coder.encodeBool(restoreMailComposer || (mailComposeController != nil), forKey:kSRFuelEventShowComposer)

		// don't use a snapshot image for next launch when graph is currently visible
		if presentedViewController != nil {
			UIApplication.sharedApplication().ignoreSnapshotOnNextApplicationLaunch()
		}

		super.encodeRestorableStateWithCoder(coder)
	}

	override func decodeRestorableStateWithCoder(coder: NSCoder) {
		restoreExportSheet = coder.decodeBoolForKey(kSRFuelEventExportSheet)
		restoreOpenIn = coder.decodeBoolForKey(kSRFuelEventShowOpenIn)
		restoreMailComposer = coder.decodeBoolForKey(kSRFuelEventShowComposer)

		super.decodeRestorableStateWithCoder(coder)

		// -> openradar #13438788
		self.tableView.reloadData()
	}

	//MARK: - Device Rotation

	func setObserveDeviceRotation(observeRotation: Bool) {
		if observeRotation && !isObservingRotationEvents {
			UIDevice.currentDevice().beginGeneratingDeviceOrientationNotifications()

			NSNotificationCenter.defaultCenter().addObserver(self,
               selector:"orientationChanged:",
                   name:UIDeviceOrientationDidChangeNotification,
                 object:UIDevice.currentDevice())

		} else if !observeRotation && isObservingRotationEvents {
			NSNotificationCenter.defaultCenter().removeObserver(self,
                      name:UIDeviceOrientationDidChangeNotification,
                    object:UIDevice.currentDevice())

			UIDevice.currentDevice().endGeneratingDeviceOrientationNotifications()
		}

		isObservingRotationEvents = observeRotation
	}

	func orientationChanged(aNotification: NSNotification) {
		// Ignore rotation when sheets or alerts are visible
		if openInController != nil {
			return
		}

		if mailComposeController != nil {
			return
		}

		if isShowingExportSheet || isPerformingRotation || isShowingAlert || !isObservingRotationEvents {
			return
		}

		// Switch view controllers according rotation state
		let deviceOrientation = UIDevice.currentDevice().orientation

		if UIDeviceOrientationIsLandscape(deviceOrientation) && presentedViewController == nil {
			isPerformingRotation = true
			statisticsController.selectedCar = selectedCar
			presentViewController(statisticsController, animated:true, completion: { self.isPerformingRotation = false })
		} else if UIDeviceOrientationIsPortrait(deviceOrientation) && presentedViewController != nil {
			isPerformingRotation = true
			dismissViewControllerAnimated(true, completion: { self.isPerformingRotation = false })
		}
	}

	//MARK: - Locale Handling

	func localeChanged(object: AnyObject) {
		self.tableView.reloadData()
	}

	//MARK: - Export Support

	func validateExport() {
		self.navigationItem.rightBarButtonItem?.enabled = ((self.fetchedResultsController.fetchedObjects?.count ?? 0) > 0)
	}

	private var exportFilename: String {
		let rawFilename = String(format:"%@__%@.csv", selectedCar.name, selectedCar.numberPlate)
		let illegalCharacters = NSCharacterSet(charactersInString:"/\\?%*|\"<>")

		return "".join(rawFilename.componentsSeparatedByCharactersInSet(illegalCharacters))
	}

	private var exportURL: NSURL {
		return NSURL(fileURLWithPath:NSTemporaryDirectory().stringByAppendingPathComponent(exportFilename))!
	}

	func exportTextData() -> NSData {
		let fetchedObjects = self.fetchedResultsController.fetchedObjects as! [FuelEvent]
		let csvString = CSVExporter.exportFuelEvents(fetchedObjects, forCar:selectedCar)
		return csvString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!
	}

	private func exportTextDescription() -> String {
		let outputFormatter = NSDateFormatter()

		outputFormatter.dateStyle = .MediumStyle
		outputFormatter.timeStyle = .NoStyle

        let fetchedObjects = self.fetchedResultsController.fetchedObjects!
        let fetchCount = fetchedObjects.count

		let last = fetchedObjects.last as? FuelEvent
		let first = fetchedObjects.first as? FuelEvent

		let period: String
        switch fetchCount {
		case 0:  period = NSLocalizedString("", comment:"")
		case 1:  period = String(format:NSLocalizedString("on %@", comment:""), outputFormatter.stringFromDate(last!.timestamp))
		default: period = String(format:NSLocalizedString("in the period from %@ to %@", comment:""), outputFormatter.stringFromDate(last!.timestamp), outputFormatter.stringFromDate(first!.timestamp))
        }

		let count = String(format:NSLocalizedString(((fetchCount == 1) ? "%d item" : "%d items"), comment:""), fetchCount)

		return String(format:NSLocalizedString("Here are your exported fuel data sets for %@ (%@) %@ (%@):\n", comment:""),
            selectedCar.name,
            selectedCar.numberPlate,
            period,
            count)
	}

	//MARK: - Export Objects via email

	func showOpenIn(sender: AnyObject!) {
		restoreOpenIn = false

		// write exported data
		let data = exportTextData()
		var error: NSError?

		if !data.writeToURL(exportURL, options:.DataWritingFileProtectionComplete, error:&error) {
			let alertController = UIAlertController(title:NSLocalizedString("Export Failed", comment:""),
				message:NSLocalizedString("Sorry, could not save the CSV-data for export.", comment:""),
				preferredStyle:.Alert)
			let defaultAction = UIAlertAction(title:NSLocalizedString("OK", comment:""), style:.Default) { _ in
				self.isShowingAlert = false
			}
			alertController.addAction(defaultAction)
			self.isShowingAlert = true
			presentViewController(alertController, animated:true, completion:nil)
			return
		}

		// show document interaction controller
		openInController = UIDocumentInteractionController(URL:exportURL)

		openInController.delegate = self
		openInController.name = exportFilename
		openInController.UTI = "public.comma-separated-values-text"

		if !openInController.presentOpenInMenuFromBarButtonItem(self.navigationItem.rightBarButtonItem!, animated:true) {

			let alertController = UIAlertController(title:NSLocalizedString("Open In Failed", comment:""),
				message:NSLocalizedString("Sorry, there seems to be no compatible app to open the data.", comment:""),
																		  preferredStyle:.Alert)
			let defaultAction = UIAlertAction(title:NSLocalizedString("OK", comment:""), style:.Default) { _ in
				self.isShowingAlert = false
			}
			alertController.addAction(defaultAction)
			self.isShowingAlert = true
			presentViewController(alertController, animated:true, completion:nil)

			self.openInController = nil
			return
		}
	}

	func documentInteractionControllerDidDismissOpenInMenu(controller: UIDocumentInteractionController) {
		NSFileManager.defaultManager().removeItemAtURL(exportURL, error:nil)

		openInController = nil
	}

	//MARK: - Export Objects via email

	func showMailComposer(sender: AnyObject!) {
		restoreMailComposer = false

		if MFMailComposeViewController.canSendMail() {
			mailComposeController = MFMailComposeViewController()

			// Setup the message
			mailComposeController.mailComposeDelegate = self
			mailComposeController.setSubject(String(format:NSLocalizedString("Your fuel data for %@", comment:""), selectedCar.numberPlate))
			mailComposeController.setMessageBody(exportTextDescription(), isHTML:false)
			mailComposeController.addAttachmentData(exportTextData(), mimeType:"text", fileName:exportFilename)

			presentViewController(mailComposeController, animated:true, completion:nil)
		}
	}

	func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!) {
		dismissViewControllerAnimated(true) {

			self.mailComposeController = nil

			if result.value == MFMailComposeResultFailed.value {
				let alertController = UIAlertController(title:NSLocalizedString("Sending Failed", comment:""),
					message:NSLocalizedString("The exported fuel data could not be sent.", comment:""),
																			  preferredStyle:.Alert)
				let defaultAction = UIAlertAction(title:NSLocalizedString("OK", comment:""), style:.Default) { _ in
					self.isShowingAlert = false
				}
				alertController.addAction(defaultAction)
				self.isShowingAlert = true
				self.presentViewController(alertController, animated:true, completion:nil)
			}
		}
	}

	//MARK: - Export Action Sheet

	func showExportSheet(sender: UIBarButtonItem!) {
		isShowingExportSheet = true
		restoreExportSheet   = false

		let alertController = UIAlertController(title:NSLocalizedString("Export Fuel Data in CSV Format", comment:""),
																			 message:nil,
																	  preferredStyle:.ActionSheet)
		let cancelAction = UIAlertAction(title:NSLocalizedString("Cancel", comment:""), style:.Cancel) { _ in
			self.isShowingExportSheet = false
		}
		let mailAction = UIAlertAction(title:NSLocalizedString("Send as Email", comment:""), style:.Default) { _ in
			self.isShowingExportSheet = false
			dispatch_async(dispatch_get_main_queue()) { self.showMailComposer(nil) }
		}
		let openInAction = UIAlertAction(title:NSLocalizedString("Open in ...", comment:""), style:.Default) { _ in
			self.isShowingExportSheet = false
			dispatch_async(dispatch_get_main_queue()) { self.showOpenIn(nil) }
		}
		if MFMailComposeViewController.canSendMail() {
			alertController.addAction(mailAction)
		}
		alertController.addAction(openInAction)
		alertController.addAction(cancelAction)
		alertController.popoverPresentationController?.barButtonItem = sender

		presentViewController(alertController, animated:true, completion:nil)
	}

	//MARK: - UITableViewDataSource

	func configureCell(tableCell: QuadInfoCell, atIndexPath indexPath: NSIndexPath) {
		let managedObject = self.fetchedResultsController.objectAtIndexPath(indexPath) as! FuelEvent

		let car = managedObject.car
		let distance = managedObject.distance
		let fuelVolume = managedObject.fuelVolume
		let price = managedObject.price

		let odometerUnit = car.ksOdometerUnit
		let consumptionUnit = car.ksFuelConsumptionUnit

		// Timestamp
		tableCell.topLeftLabel.text = Formatters.sharedDateFormatter.stringForObjectValue(managedObject.timestamp)
		tableCell.topLeftAccessibilityLabel = nil

		// Distance
		let convertedDistance: NSDecimalNumber

		if odometerUnit == .Kilometer {
			convertedDistance = distance
		} else {
			convertedDistance = distance / Units.kilometersPerStatuteMile
		}

		tableCell.botLeftLabel.text = String(format:"%@ %@",
                    Formatters.sharedDistanceFormatter.stringFromNumber(convertedDistance)!,
                    Units.odometerUnitString(odometerUnit))
		tableCell.botLeftAccessibilityLabel = nil

		// Price
		tableCell.topRightLabel.text = Formatters.sharedCurrencyFormatter.stringFromNumber(managedObject.cost)
		tableCell.topRightAccessibilityLabel = tableCell.topRightLabel.text

		// Consumption combined with inherited data from earlier events
		let consumptionDescription: String
		if managedObject.filledUp {
			let totalDistance = distance + managedObject.inheritedDistance
			let totalFuelVolume = fuelVolume + managedObject.inheritedFuelVolume

			let avg = Units.consumptionForKilometers(totalDistance, liters:totalFuelVolume, inUnit:consumptionUnit)

			consumptionDescription = Formatters.sharedFuelVolumeFormatter.stringFromNumber(avg)!

			tableCell.botRightAccessibilityLabel = String(format:", %@ %@",
                                                    consumptionDescription,
                                                    Units.consumptionUnitAccessibilityDescription(consumptionUnit))

		} else {
			consumptionDescription = NSLocalizedString("-", comment:"")
			tableCell.botRightAccessibilityLabel = NSLocalizedString("fuel mileage not available", comment:"")
		}

		tableCell.botRightLabel.text = String(format:"%@ %@", consumptionDescription, Units.consumptionUnitString(consumptionUnit))
	}

	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return self.fetchedResultsController.sections?.count ?? 0
	}

	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let sectionInfo = self.fetchedResultsController.sections?[section] as? NSFetchedResultsSectionInfo
		return sectionInfo?.numberOfObjects ?? 0
	}

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let CellIdentifier = "FuelCell"

		var cell = tableView.dequeueReusableCellWithIdentifier(CellIdentifier) as? QuadInfoCell

		if cell == nil {
			cell = QuadInfoCell(style:.Default, reuseIdentifier:CellIdentifier, enlargeTopRightLabel:false)
		}

		configureCell(cell!, atIndexPath:indexPath)
		return cell!
	}

	override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		if editingStyle == .Delete {
			let fuelEvent = self.fetchedResultsController.objectAtIndexPath(indexPath) as! FuelEvent
			CoreDataManager.removeEventFromArchive(fuelEvent, forceOdometerUpdate:false)
			CoreDataManager.saveContext()
		}
	}

	//MARK: - UIDataSourceModelAssociation

	func indexPathForElementWithModelIdentifier(identifier: String, inView view: UIView) -> NSIndexPath? {
		let object = CoreDataManager.managedObjectForModelIdentifier(identifier)!

		return self.fetchedResultsController.indexPathForObject(object)
	}

	func modelIdentifierForElementAtIndexPath(idx: NSIndexPath, inView view: UIView) -> String {
		let object = self.fetchedResultsController.objectAtIndexPath(idx) as! NSManagedObject

		return CoreDataManager.modelIdentifierForManagedObject(object)!
	}

	//MARK: - UITableViewDelegate

	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		let editController = self.storyboard!.instantiateViewControllerWithIdentifier("FuelEventEditor") as! FuelEventEditorController

		editController.event = self.fetchedResultsController.objectAtIndexPath(indexPath) as! FuelEvent

		self.navigationController?.pushViewController(editController, animated:true)
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

		validateExport()
		statisticsController.invalidateCaches()
	}

	//MARK: - Memory Management

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
}
