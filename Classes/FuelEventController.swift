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

private let fuelEventSelectedCarID = "FuelEventSelectedCarID"
private let fuelEventExportSheet   = "FuelEventExportSheet"
private let fuelEventShowOpenIn    = "FuelEventShowOpenIn"
private let fuelEventShowComposer  = "FuelEventShowMailComposer"

final class FuelEventController: UITableViewController, UIDataSourceModelAssociation, UIViewControllerRestoration, NSFetchedResultsControllerDelegate, MFMailComposeViewControllerDelegate, UIDocumentInteractionControllerDelegate, UIDocumentPickerDelegate {

	var selectedCarId: String?
	var selectedCar: Car!

	private lazy var fetchRequest: NSFetchRequest<FuelEvent> = {
		return CoreDataManager.fetchRequestForEvents(car: self.selectedCar,
			afterDate: nil,
			dateMatches: true)
	}()

	private lazy var fetchedResultsController: NSFetchedResultsController<FuelEvent> = {
		let fetchController = NSFetchedResultsController(fetchRequest: self.fetchRequest,
			managedObjectContext: CoreDataManager.managedObjectContext,
			sectionNameKeyPath: nil,
			cacheName: nil)

		fetchController.delegate = self

		// Perform the data fetch
		do {
			try fetchController.performFetch()
		} catch let error {
			fatalError(error.localizedDescription)
		}

		return fetchController
	}()

	private var statisticsController: FuelStatisticsPageController!

	private var isShowingAlert = false
	private var isShowingExportSheet = false
	private var restoreExportSheet = false
	private var restoreOpenIn = false
	private var restoreMailComposer = false

	private var openInController: UIDocumentInteractionController!
	private var mailComposeController: MFMailComposeViewController!
	private var documentPickerViewController: UIDocumentPickerViewController!

	// MARK: - View Lifecycle

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		self.restorationClass = type(of: self)
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		if let selectedCarId = selectedCarId, selectedCar == nil {
			selectedCar = CoreDataManager.managedObjectForModelIdentifier(selectedCarId)
		}

		// swiftlint:disable:next force_cast
		statisticsController = self.storyboard!.instantiateViewController(withIdentifier: "FuelStatisticsPageController") as! FuelStatisticsPageController

		// Configure root view
		self.title = selectedCar.name

		// Export button in navigation bar
		self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(FuelEventController.showExportSheet(_:)))

		self.navigationItem.rightBarButtonItem!.isEnabled = false

		// Reset tint color
		self.navigationController?.navigationBar.tintColor = nil

		// Background image
		let backgroundView = UIView(frame: .zero)
		backgroundView.backgroundColor = self.tableView.backgroundColor
		let backgroundImage = UIImageView(image: #imageLiteral(resourceName: "Pumps"))
		backgroundImage.translatesAutoresizingMaskIntoConstraints = false
		backgroundView.addSubview(backgroundImage)
		NSLayoutConstraint.activate([
			NSLayoutConstraint(item: backgroundView, attribute: .bottom, relatedBy: .equal, toItem: backgroundImage, attribute: .bottom, multiplier: 1.0, constant: 90.0),
			NSLayoutConstraint(item: backgroundView, attribute: .centerX, relatedBy: .equal, toItem: backgroundImage, attribute: .centerX, multiplier: 1.0, constant: 0.0)
		])
		self.tableView.backgroundView = backgroundView

		self.tableView.estimatedRowHeight = self.tableView.rowHeight
		self.tableView.rowHeight = UITableViewAutomaticDimension

		NotificationCenter.default.addObserver(self,
		                                       selector: #selector(FuelEventController.localeChanged(_:)),
		                                       name: NSLocale.currentLocaleDidChangeNotification,
		                                       object: nil)

		// Dismiss any presented view controllers
		if presentedViewController != nil {
			dismiss(animated: false, completion: nil)
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		validateExport()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		if restoreExportSheet {
			showExportSheet(nil)
		} else if restoreOpenIn {
			showOpenIn()
		} else if restoreMailComposer {
			showMailComposer()
		}
	}

	// MARK: - State Restoration

	static func viewController(withRestorationIdentifierPath identifierComponents: [Any], coder: NSCoder) -> UIViewController? {
		if let storyboard = coder.decodeObject(forKey: UIStateRestorationViewControllerStoryboardKey) as? UIStoryboard,
				let controller = storyboard.instantiateViewController(withIdentifier: "FuelEventController") as? FuelEventController,
				let modelIdentifier = coder.decodeObject(of: NSString.self, forKey: fuelEventSelectedCarID) as String? {
			controller.selectedCar = CoreDataManager.managedObjectForModelIdentifier(modelIdentifier)

			if controller.selectedCar == nil {
				return nil
			}

			return controller
		}
		return nil
	}

	override func encodeRestorableState(with coder: NSCoder) {
		coder.encode(CoreDataManager.modelIdentifierForManagedObject(selectedCar) as NSString?, forKey: fuelEventSelectedCarID)
		coder.encode(restoreExportSheet || isShowingExportSheet, forKey: fuelEventExportSheet)
		coder.encode(restoreOpenIn || (openInController != nil), forKey: fuelEventShowOpenIn)
		coder.encode(restoreMailComposer || (mailComposeController != nil), forKey: fuelEventShowComposer)

		// don't use a snapshot image for next launch when graph is currently visible
		if presentedViewController != nil {
			UIApplication.shared.ignoreSnapshotOnNextApplicationLaunch()
		}

		super.encodeRestorableState(with: coder)
	}

	override func decodeRestorableState(with coder: NSCoder) {
		restoreExportSheet = coder.decodeBool(forKey: fuelEventExportSheet)
		restoreOpenIn = coder.decodeBool(forKey: fuelEventShowOpenIn)
		restoreMailComposer = coder.decodeBool(forKey: fuelEventShowComposer)

		super.decodeRestorableState(with: coder)

		// -> openradar #13438788
		self.tableView.reloadData()
	}

	// MARK: - Device Rotation

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		// Ignore rotation when sheets or alerts are visible
		if openInController != nil || documentPickerViewController != nil || mailComposeController != nil {
			return
		}

		if isShowingExportSheet || isShowingAlert {
			return
		}

		coordinator.animate(alongsideTransition: { _ in
			// Switch view controllers according rotation state
			let interfaceOrientation = UIApplication.shared.statusBarOrientation

			if UIInterfaceOrientationIsLandscape(interfaceOrientation) && self.presentedViewController == nil {
				self.statisticsController.selectedCar = self.selectedCar
				self.present(self.statisticsController, animated: true, completion: nil)
			}
		}, completion: nil)

		super.viewWillTransition(to: size, with: coordinator)
	}

	// MARK: - Locale Handling

	@objc func localeChanged(_ object: AnyObject) {
		self.tableView.reloadData()
	}

	// MARK: - Export Support

	func validateExport() {
		self.navigationItem.rightBarButtonItem?.isEnabled = ((self.fetchedResultsController.fetchedObjects?.count ?? 0) > 0)
	}

	private var exportFilename: String {
		let rawFilename = "\(selectedCar.ksName)__\(selectedCar.ksNumberPlate).csv"
		let illegalCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>")

		return rawFilename.components(separatedBy: illegalCharacters).joined(separator: "")
	}

	private var exportURL: URL {
		return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(exportFilename)
	}

	func exportTextData() -> Data {
		let fetchedObjects = self.fetchedResultsController.fetchedObjects!
		let csvString = CSVExporter.exportFuelEvents(fetchedObjects, forCar: selectedCar)
		return csvString.data(using: String.Encoding.utf8, allowLossyConversion: true)!
	}

	private func exportTextDescription() -> String {
		let outputFormatter = DateFormatter()

		outputFormatter.dateStyle = .medium
		outputFormatter.timeStyle = .none

		let fetchedObjects = self.fetchedResultsController.fetchedObjects!
		let fetchCount = fetchedObjects.count

		let last = fetchedObjects.last
		let first = fetchedObjects.first

		let period: String
		switch fetchCount {
		case 0: period = NSLocalizedString("", comment: "")
		case 1: period = String(format: NSLocalizedString("on %@", comment: ""), outputFormatter.string(from: last!.ksTimestamp))
		default: period = String(format: NSLocalizedString("in the period from %@ to %@", comment: ""), outputFormatter.string(from: last!.ksTimestamp), outputFormatter.string(from: first!.ksTimestamp))
		}

		let count = String(format: NSLocalizedString(((fetchCount == 1) ? "%d item" : "%d items"), comment: ""), fetchCount)

		return String(format: NSLocalizedString("Here are your exported fuel data sets for %@ (%@) %@ (%@):\n", comment: ""),
            selectedCar.ksName,
            selectedCar.ksNumberPlate,
            period,
            count)
	}

	// MARK: - Export data

	func showOpenIn() {
		restoreOpenIn = false

		// write exported data
		let data = exportTextData()
		do {
			try data.write(to: exportURL, options: .completeFileProtection)
		} catch _ {
			let alertController = UIAlertController(title: NSLocalizedString("Export Failed", comment: ""),
				message: NSLocalizedString("Sorry, could not save the CSV data for export.", comment: ""),
				preferredStyle: .alert)
			let defaultAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
				self.isShowingAlert = false
			}
			alertController.addAction(defaultAction)
			self.isShowingAlert = true
			present(alertController, animated: true, completion: nil)
			return
		}

		// show document interaction controller
		openInController = UIDocumentInteractionController(url: exportURL)

		openInController.delegate = self
		openInController.name = exportFilename
		openInController.uti = "public.comma-separated-values-text"

		if !openInController.presentOpenInMenu(from: self.navigationItem.rightBarButtonItem!, animated: true) {
			let alertController = UIAlertController(title: NSLocalizedString("Open In Failed", comment: ""),
				message: NSLocalizedString("Sorry, there seems to be no compatible app to open the data.", comment: ""),
																		  preferredStyle: .alert)
			let defaultAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
				self.isShowingAlert = false
			}
			alertController.addAction(defaultAction)
			self.isShowingAlert = true
			present(alertController, animated: true, completion: nil)

			self.openInController = nil
		}
	}

	func showExportDocumentPicker() {
		restoreOpenIn = false

		// write exported data
		let data = exportTextData()
		do {
			try data.write(to: exportURL, options: .completeFileProtection)
		} catch _ {
			let alertController = UIAlertController(title: NSLocalizedString("Export Failed", comment: ""),
			                                        message: NSLocalizedString("Sorry, could not save the CSV data for export.", comment: ""),
			                                        preferredStyle: .alert)
			let defaultAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
				self.isShowingAlert = false
			}
			alertController.addAction(defaultAction)
			self.isShowingAlert = true
			present(alertController, animated: true, completion: nil)
			return
		}

		documentPickerViewController = UIDocumentPickerViewController(url: exportURL, in: .exportToService)
		documentPickerViewController.delegate = self

		present(documentPickerViewController, animated: true, completion: nil)
	}

	func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
		do {
			try FileManager.default.removeItem(at: exportURL)
		} catch _ {
		}

		documentPickerViewController = nil
	}

	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
		do {
			try FileManager.default.removeItem(at: exportURL)
		} catch _ {
		}

		documentPickerViewController = nil
	}

	func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
		do {
			try FileManager.default.removeItem(at: exportURL)
		} catch _ {
		}

		openInController = nil
	}

	// MARK: - Export Objects via email

	func showMailComposer() {
		restoreMailComposer = false

		if MFMailComposeViewController.canSendMail() {
			mailComposeController = MFMailComposeViewController()

			// Setup the message
			mailComposeController.mailComposeDelegate = self
			mailComposeController.setSubject(String(format: NSLocalizedString("Your fuel data for %@", comment: ""), selectedCar.ksNumberPlate))
			mailComposeController.setMessageBody(exportTextDescription(), isHTML: false)
			mailComposeController.addAttachmentData(exportTextData(), mimeType: "text/csv", fileName: exportFilename)

			present(mailComposeController, animated: true, completion: nil)
		}
	}

	func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
		dismiss(animated: true) {

			self.mailComposeController = nil

			if result == .failed {
				let alertController = UIAlertController(title: NSLocalizedString("Sending Failed", comment: ""),
					message: NSLocalizedString("The exported fuel data could not be sent.", comment: ""),
																			  preferredStyle: .alert)
				let defaultAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
					self.isShowingAlert = false
				}
				alertController.addAction(defaultAction)
				self.isShowingAlert = true
				self.present(alertController, animated: true, completion: nil)
			}
		}
	}

	// MARK: - Export Action Sheet

	@objc func showExportSheet(_ sender: UIBarButtonItem!) {
		isShowingExportSheet = true
		restoreExportSheet   = false

		let alertController = UIAlertController(title: NSLocalizedString("Export Fuel Data in CSV Format", comment: ""),
																			 message: nil,
																	  preferredStyle: .actionSheet)
		let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
			self.isShowingExportSheet = false
		}
		let mailAction = UIAlertAction(title: NSLocalizedString("Send as Email", comment: ""), style: .default) { _ in
			self.isShowingExportSheet = false
			DispatchQueue.main.async { self.showMailComposer() }
		}
		let openInAction = UIAlertAction(title: NSLocalizedString("Open in ...", comment: ""), style: .default) { _ in
			self.isShowingExportSheet = false
			DispatchQueue.main.async { self.showOpenIn() }
		}
		let exportAction = UIAlertAction(title: NSLocalizedString("Export", comment: ""), style: .default) { _ in
			self.isShowingExportSheet = false
			DispatchQueue.main.async { self.showExportDocumentPicker() }
		}
		if MFMailComposeViewController.canSendMail() {
			alertController.addAction(mailAction)
		}
		alertController.addAction(openInAction)
		alertController.addAction(exportAction)
		alertController.addAction(cancelAction)
		alertController.popoverPresentationController?.barButtonItem = sender

		present(alertController, animated: true, completion: nil)
	}

	// MARK: - UITableViewDataSource

	func configureCell(_ tableCell: QuadInfoCell, atIndexPath indexPath: IndexPath) {
		let fuelEvent = self.fetchedResultsController.object(at: indexPath)

		let car = fuelEvent.car!
		let distance = fuelEvent.ksDistance
		let fuelVolume = fuelEvent.ksFuelVolume

		let odometerUnit = car.ksOdometerUnit
		let consumptionUnit = car.ksFuelConsumptionUnit

		// Timestamp
		tableCell.topLeftLabel.text = Formatters.dateFormatter.string(for: fuelEvent.timestamp)
		tableCell.topLeftAccessibilityLabel = nil

		// Distance
		let convertedDistance: NSDecimalNumber

		if odometerUnit == UnitLength.kilometers {
			convertedDistance = distance
		} else {
			convertedDistance = distance / Units.kilometersPerStatuteMile
		}

		tableCell.botLeftLabel.text = "\(Formatters.distanceFormatter.string(from: convertedDistance)!) \(Formatters.shortMeasurementFormatter.string(from: odometerUnit))"
		tableCell.botLeftAccessibilityLabel = nil

		// Price
		tableCell.topRightLabel.text = Formatters.currencyFormatter.string(from: fuelEvent.cost)
		tableCell.topRightAccessibilityLabel = tableCell.topRightLabel.text

		// Consumption combined with inherited data from earlier events
		let consumptionDescription: String
		if fuelEvent.filledUp {
			let totalDistance = distance + fuelEvent.ksInheritedDistance
			let totalFuelVolume = fuelVolume + fuelEvent.ksInheritedFuelVolume

			let avg = Units.consumptionForKilometers(totalDistance, liters: totalFuelVolume, inUnit: consumptionUnit)

			consumptionDescription = Formatters.fuelVolumeFormatter.string(from: avg)!

			tableCell.botRightAccessibilityLabel = ", \(consumptionDescription) \(Formatters.mediumMeasurementFormatter.string(from: consumptionUnit))"

		} else {
			consumptionDescription = NSLocalizedString("-", comment: "")
			tableCell.botRightAccessibilityLabel = NSLocalizedString("fuel mileage not available", comment: "")
		}

		tableCell.botRightLabel.text = "\(consumptionDescription) \(Formatters.shortMeasurementFormatter.string(from: consumptionUnit))"
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		return self.fetchedResultsController.sections?.count ?? 0
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let sectionInfo = self.fetchedResultsController.sections?[section]
		return sectionInfo?.numberOfObjects ?? 0
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "FuelCell", for: indexPath)

		if let quadInfoCell = cell as? QuadInfoCell {
			configureCell(quadInfoCell, atIndexPath: indexPath)
		}

		return cell
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			let fuelEvent = self.fetchedResultsController.object(at: indexPath)
			CoreDataManager.removeEventFromArchive(fuelEvent, forceOdometerUpdate: false)
			CoreDataManager.saveContext()
		}
	}

	// MARK: - UIDataSourceModelAssociation

	func indexPathForElement(withModelIdentifier identifier: String, in view: UIView) -> IndexPath? {
		if let fuelEvent: FuelEvent = CoreDataManager.managedObjectForModelIdentifier(identifier) {
			return self.fetchedResultsController.indexPath(forObject: fuelEvent)
		}
		return nil
	}

	func modelIdentifierForElement(at idx: IndexPath, in view: UIView) -> String? {
		let object = self.fetchedResultsController.object(at: idx)

		return CoreDataManager.modelIdentifierForManagedObject(object)
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if let editController = self.storyboard!.instantiateViewController(withIdentifier: "FuelEventEditor") as? FuelEventEditorController {
			editController.event = self.fetchedResultsController.object(at: indexPath)
			self.navigationController?.pushViewController(editController, animated: true)
		}
	}

	// MARK: - NSFetchedResultsControllerDelegate

	func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		self.tableView.beginUpdates()
	}

	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
		switch type {
        case .insert:
            self.tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
		case .move, .update:
			self.tableView.reloadSections(IndexSet(integer: sectionIndex), with: .fade)
		}
	}

	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
		switch type {
        case .insert:
			tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
			tableView.deleteRows(at: [indexPath!], with: .fade)
        case .move:
            tableView.deleteRows(at: [indexPath!], with: .fade)
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .update:
            tableView.reloadRows(at: [indexPath!], with: .automatic)
		}
	}

	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		self.tableView.endUpdates()

		validateExport()
		statisticsController.invalidateCaches()
	}

	// MARK: - Memory Management

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
}
