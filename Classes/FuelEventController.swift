//
//  FuelEventController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 06.05.15.
//
//

import UIKit
import RealmSwift
import MessageUI

private let fuelEventSelectedCarID = "FuelEventSelectedCarID"
private let fuelEventExportSheet   = "FuelEventExportSheet"
private let fuelEventShowOpenIn    = "FuelEventShowOpenIn"
private let fuelEventShowComposer  = "FuelEventShowMailComposer"

final class FuelEventController: UITableViewController, UIDataSourceModelAssociation, UIViewControllerRestoration, MFMailComposeViewControllerDelegate, UIDocumentInteractionControllerDelegate, UIDocumentPickerDelegate {

	var selectedCarId: String?
	var selectedCar: Car!

	// swiftlint:disable:next force_try
	private let realm = try! Realm()
	private var notificationToken: NotificationToken?

	private lazy var fuelEvents: Results<FuelEvent> = {
		let results = DataManager.fuelEventsForCar(car: self.selectedCar,
			afterDate: nil,
			dateMatches: true)
		self.notificationToken = results.observe { (changes) in
			self.tableView.applyChanges(changes: changes, with: .fade)
			self.validateExport()
			self.statisticsController.invalidateCaches()
		}
		return results
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
			selectedCar = realm.object(ofType: Car.self, forPrimaryKey: selectedCarId)
		}

		// swiftlint:disable:next force_cast
		statisticsController = self.storyboard!.instantiateViewController(withIdentifier: "FuelStatisticsPageController") as? FuelStatisticsPageController

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
		self.tableView.rowHeight = UITableView.automaticDimension

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

	static func viewController(withRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
		if let storyboard = coder.decodeObject(forKey: UIApplication.stateRestorationViewControllerStoryboardKey) as? UIStoryboard,
				let controller = storyboard.instantiateViewController(withIdentifier: "FuelEventController") as? FuelEventController,
				let modelIdentifier = coder.decodeObject(of: NSString.self, forKey: fuelEventSelectedCarID) as String? {
			// swiftlint:disable:next force_try
			let realm = try! Realm()

			controller.selectedCar = realm.object(ofType: Car.self, forPrimaryKey: modelIdentifier)

			if controller.selectedCar == nil {
				return nil
			}

			return controller
		}
		return nil
	}

	override func encodeRestorableState(with coder: NSCoder) {
		coder.encode(selectedCar.id, forKey: fuelEventSelectedCarID)
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

			if interfaceOrientation.isLandscape && self.presentedViewController == nil {
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
		self.navigationItem.rightBarButtonItem?.isEnabled = (fuelEvents.count > 0)
	}

	private var exportFilename: String {
		let rawFilename = "\(selectedCar.name)__\(selectedCar.numberPlate).csv"
		let illegalCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>")

		return rawFilename.components(separatedBy: illegalCharacters).joined(separator: "")
	}

	private var exportURL: URL {
		return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(exportFilename)
	}

	func exportTextData() -> Data {
		let csvString = CSVExporter.exportFuelEvents(Array(fuelEvents), forCar: selectedCar)
		return csvString.data(using: String.Encoding.utf8, allowLossyConversion: true)!
	}

	private func exportTextDescription() -> String {
		let outputFormatter = DateFormatter()

		outputFormatter.dateStyle = .medium
		outputFormatter.timeStyle = .none

		let eventCount = fuelEvents.count
		let last = fuelEvents.last
		let first = fuelEvents.first

		let period: String
		switch eventCount {
		case 0: period = NSLocalizedString("", comment: "")
		case 1: period = String(format: NSLocalizedString("on %@", comment: ""), outputFormatter.string(from: last!.timestamp))
		default: period = String(format: NSLocalizedString("in the period from %@ to %@", comment: ""), outputFormatter.string(from: last!.timestamp), outputFormatter.string(from: first!.timestamp))
		}

		let count = String(format: NSLocalizedString(((eventCount == 1) ? "%d item" : "%d items"), comment: ""), eventCount)

		return String(format: NSLocalizedString("Here are your exported fuel data sets for %@ (%@) %@ (%@):\n", comment: ""),
            selectedCar.name,
            selectedCar.numberPlate,
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
			mailComposeController.setSubject(String(format: NSLocalizedString("Your fuel data for %@", comment: ""), selectedCar.numberPlate))
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
		let fuelEvent = fuelEvents[indexPath.row]

		let car = fuelEvent.cars[0]
		let distance = fuelEvent.distance
		let fuelVolume = fuelEvent.fuelVolume

		let odometerUnit = car.odometerUnit
		let consumptionUnit = car.fuelConsumptionUnit

		// Timestamp
		tableCell.topLeftLabel.text = Formatters.dateFormatter.string(for: fuelEvent.timestamp)
		tableCell.topLeftAccessibilityLabel = nil

		// Distance
		let convertedDistance: Decimal

		if odometerUnit == UnitLength.kilometers {
			convertedDistance = distance
		} else {
			convertedDistance = distance / Units.kilometersPerStatuteMile
		}

		tableCell.botLeftLabel.text = "\(Formatters.distanceFormatter.string(from: convertedDistance as NSNumber)!) \(Formatters.shortMeasurementFormatter.string(from: odometerUnit))"
		tableCell.botLeftAccessibilityLabel = nil

		// Price
		tableCell.topRightLabel.text = Formatters.currencyFormatter.string(from: fuelEvent.cost as NSNumber)
		tableCell.topRightAccessibilityLabel = tableCell.topRightLabel.text

		// Consumption combined with inherited data from earlier events
		let consumptionDescription: String
		if fuelEvent.filledUp {
			let totalDistance = distance + fuelEvent.inheritedDistance
			let totalFuelVolume = fuelVolume + fuelEvent.inheritedFuelVolume

			let avg = Units.consumptionForKilometers(totalDistance, liters: totalFuelVolume, inUnit: consumptionUnit)

			consumptionDescription = Formatters.fuelVolumeFormatter.string(from: avg as NSNumber)!

			tableCell.botRightAccessibilityLabel = ", \(consumptionDescription) \(Formatters.mediumMeasurementFormatter.string(from: consumptionUnit))"

		} else {
			consumptionDescription = NSLocalizedString("-", comment: "")
			tableCell.botRightAccessibilityLabel = NSLocalizedString("fuel mileage not available", comment: "")
		}

		tableCell.botRightLabel.text = "\(consumptionDescription) \(Formatters.shortMeasurementFormatter.string(from: consumptionUnit))"
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return fuelEvents.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "FuelCell", for: indexPath)

		if let quadInfoCell = cell as? QuadInfoCell {
			configureCell(quadInfoCell, atIndexPath: indexPath)
		}

		return cell
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			let fuelEvent = fuelEvents[indexPath.row]
			DataManager.removeEvent(fuelEvent, forceOdometerUpdate: false)
		}
	}

	// MARK: - UIDataSourceModelAssociation

	func indexPathForElement(withModelIdentifier identifier: String, in view: UIView) -> IndexPath? {
		if let fuelEvent = realm.object(ofType: FuelEvent.self, forPrimaryKey: identifier), let row = fuelEvents.index(of: fuelEvent) {
			return IndexPath(row: row, section: 0)
		}
		return nil
	}

	func modelIdentifierForElement(at idx: IndexPath, in view: UIView) -> String? {
		return fuelEvents[idx.row].id
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if let editController = self.storyboard!.instantiateViewController(withIdentifier: "FuelEventEditor") as? FuelEventEditorController {
			editController.event = fuelEvents[indexPath.row]
			self.navigationController?.pushViewController(editController, animated: true)
		}
	}

	// MARK: - Memory Management

	deinit {
		notificationToken?.invalidate()
		NotificationCenter.default.removeObserver(self)
	}
}
