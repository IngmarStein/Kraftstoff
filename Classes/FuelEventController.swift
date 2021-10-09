//
//  FuelEventController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 06.05.15.
//
//

import CoreData
import MessageUI
import UIKit

private let fuelEventSelectedCarID = "FuelEventSelectedCarID"
private let fuelEventExportSheet = "FuelEventExportSheet"
private let fuelEventShowOpenIn = "FuelEventShowOpenIn"
private let fuelEventShowComposer = "FuelEventShowMailComposer"

final class FuelEventController: UITableViewController, UIDataSourceModelAssociation, UIViewControllerRestoration, NSFetchedResultsControllerDelegate, MFMailComposeViewControllerDelegate, UIDocumentInteractionControllerDelegate, UIDocumentPickerDelegate {
  var selectedCarId: String?
  var selectedCar: Car!

  private lazy var fetchRequest: NSFetchRequest<FuelEvent> = {
    DataManager.fetchRequestForEvents(car: self.selectedCar,
                                      afterDate: nil,
                                      dateMatches: true)
  }()

  private lazy var fetchedResultsController: NSFetchedResultsController<FuelEvent> = {
    let fetchController = NSFetchedResultsController(fetchRequest: self.fetchRequest,
                                                     managedObjectContext: DataManager.managedObjectContext,
                                                     sectionNameKeyPath: nil,
                                                     cacheName: nil)

    fetchController.delegate = self

    // Perform the data fetch
    do {
      try fetchController.performFetch()
    } catch {
      fatalError(error.localizedDescription)
    }

    return fetchController
  }()

  private var isShowingAlert = false
  private var isShowingExportSheet = false
  private var restoreExportSheet = false
  private var restoreOpenIn = false
  private var restoreMailComposer = false

  private var openInController: UIDocumentInteractionController!
  private var mailComposeController: MFMailComposeViewController!
  private var documentPickerViewController: UIDocumentPickerViewController!

  @IBOutlet var actionBarButtonItem: UIBarButtonItem!

  // MARK: - View Lifecycle

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    restorationClass = type(of: self)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    if let selectedCarId = selectedCarId, selectedCar == nil {
      selectedCar = DataManager.managedObjectForModelIdentifier(selectedCarId)
    }

    // Configure root view
    title = selectedCar.name

    // Export button in navigation bar
    actionBarButtonItem.isEnabled = false

    // Reset tint color
    navigationController?.navigationBar.tintColor = nil

    // Background image
    let backgroundView = UIView(frame: .zero)
    backgroundView.backgroundColor = tableView.backgroundColor
    let backgroundImage = UIImageView(image: #imageLiteral(resourceName: "Pumps"))
    backgroundImage.translatesAutoresizingMaskIntoConstraints = false
    backgroundView.addSubview(backgroundImage)
    NSLayoutConstraint.activate([
      backgroundView.bottomAnchor.constraint(equalTo: backgroundImage.bottomAnchor, constant: 110.0),
      backgroundView.centerXAnchor.constraint(equalTo: backgroundImage.centerXAnchor),
    ])
    tableView.backgroundView = backgroundView

    tableView.estimatedRowHeight = tableView.rowHeight
    tableView.rowHeight = UITableView.automaticDimension

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

  static func viewController(withRestorationIdentifierPath _: [String], coder: NSCoder) -> UIViewController? {
    if let storyboard = coder.decodeObject(forKey: UIApplication.stateRestorationViewControllerStoryboardKey) as? UIStoryboard,
       let controller = storyboard.instantiateViewController(withIdentifier: "FuelEventController") as? FuelEventController,
       let modelIdentifier = coder.decodeObject(of: NSString.self, forKey: fuelEventSelectedCarID) as String?
    {
      controller.selectedCar = DataManager.managedObjectForModelIdentifier(modelIdentifier)

      if controller.selectedCar == nil {
        return nil
      }

      return controller
    }
    return nil
  }

  override func encodeRestorableState(with coder: NSCoder) {
    coder.encode(DataManager.modelIdentifierForManagedObject(selectedCar) as NSString?, forKey: fuelEventSelectedCarID)
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
    tableView.reloadData()
  }

  // MARK: - Segues

  @IBSegueAction func showStatistics(_ coder: NSCoder) -> FuelStatisticsPageController? {
    let statisticsPageController = FuelStatisticsPageController(coder: coder)
    statisticsPageController?.selectedCar = selectedCar
    return statisticsPageController
  }

  @IBAction func unwindToFuelEvents(_: UIStoryboardSegue) {}

  // MARK: - Locale Handling

  @objc func localeChanged(_: AnyObject) {
    tableView.reloadData()
  }

  // MARK: - Export Support

  func validateExport() {
    actionBarButtonItem.isEnabled = ((fetchedResultsController.fetchedObjects?.count ?? 0) > 0)
  }

  private var exportFilename: String {
    let rawFilename = "\(selectedCar.ksName)__\(selectedCar.ksNumberPlate).csv"
    let illegalCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>")

    return rawFilename.components(separatedBy: illegalCharacters).joined(separator: "")
  }

  private var exportURL: URL {
    URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(exportFilename)
  }

  func exportTextData() -> Data {
    let fuelEvents = fetchedResultsController.fetchedObjects!
    let csvString = CSVExporter.exportFuelEvents(fuelEvents, forCar: selectedCar)
    return csvString.data(using: String.Encoding.utf8, allowLossyConversion: true)!
  }

  private func exportTextDescription() -> String {
    let outputFormatter = DateFormatter()

    outputFormatter.dateStyle = .medium
    outputFormatter.timeStyle = .none

    let fuelEvents = fetchedResultsController.fetchedObjects!
    let eventCount = fuelEvents.count
    let last = fuelEvents.last
    let first = fuelEvents.first

    let period: String
    switch eventCount {
    case 0: period = NSLocalizedString("", comment: "")
    case 1: period = String(format: NSLocalizedString("on %@", comment: ""), outputFormatter.string(from: last!.ksTimestamp))
    default: period = String(format: NSLocalizedString("in the period from %@ to %@", comment: ""), outputFormatter.string(from: last!.ksTimestamp), outputFormatter.string(from: first!.ksTimestamp))
    }

    let count = String(format: NSLocalizedString((eventCount == 1) ? "%d item" : "%d items", comment: ""), eventCount)

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
      isShowingAlert = true
      present(alertController, animated: true, completion: nil)
      return
    }

    // show document interaction controller
    openInController = UIDocumentInteractionController(url: exportURL)

    openInController.delegate = self
    openInController.name = exportFilename
    openInController.uti = "public.comma-separated-values-text"

    if !openInController.presentOpenInMenu(from: actionBarButtonItem, animated: true) {
      let alertController = UIAlertController(title: NSLocalizedString("Open In Failed", comment: ""),
                                              message: NSLocalizedString("Sorry, there seems to be no compatible app to open the data.", comment: ""),
                                              preferredStyle: .alert)
      let defaultAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
        self.isShowingAlert = false
      }
      alertController.addAction(defaultAction)
      isShowingAlert = true
      present(alertController, animated: true, completion: nil)

      openInController = nil
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
      isShowingAlert = true
      present(alertController, animated: true, completion: nil)
      return
    }

    documentPickerViewController = UIDocumentPickerViewController(forExporting: [exportURL])
    documentPickerViewController.delegate = self

    present(documentPickerViewController, animated: true, completion: nil)
  }

  func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
    do {
      try FileManager.default.removeItem(at: exportURL)
    } catch _ {}

    documentPickerViewController = nil
  }

  func documentPicker(_: UIDocumentPickerViewController, didPickDocumentAt _: URL) {
    do {
      try FileManager.default.removeItem(at: exportURL)
    } catch _ {}

    documentPickerViewController = nil
  }

  func documentInteractionControllerDidDismissOpenInMenu(_: UIDocumentInteractionController) {
    do {
      try FileManager.default.removeItem(at: exportURL)
    } catch _ {}

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

  func mailComposeController(_: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error _: Error?) {
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

  @IBAction func showExportSheet(_ sender: UIBarButtonItem!) {
    isShowingExportSheet = true
    restoreExportSheet = false

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
    let fuelEvent = fetchedResultsController.object(at: indexPath)

    let car = fuelEvent.car!
    let distance = fuelEvent.ksDistance
    let fuelVolume = fuelEvent.ksFuelVolume

    let odometerUnit = car.ksOdometerUnit
    let consumptionUnit = car.ksFuelConsumptionUnit

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
      let totalDistance = distance + fuelEvent.ksInheritedDistance
      let totalFuelVolume = fuelVolume + fuelEvent.ksInheritedFuelVolume

      let avg = Units.consumptionForKilometers(totalDistance, liters: totalFuelVolume, inUnit: consumptionUnit)

      consumptionDescription = Formatters.fuelVolumeFormatter.string(from: avg as NSNumber)!

      tableCell.botRightAccessibilityLabel = ", \(consumptionDescription) \(Formatters.mediumMeasurementFormatter.string(from: consumptionUnit))"

    } else {
      consumptionDescription = NSLocalizedString("-", comment: "")
      tableCell.botRightAccessibilityLabel = NSLocalizedString("fuel mileage not available", comment: "")
    }

    tableCell.botRightLabel.text = "\(consumptionDescription) \(Formatters.shortMeasurementFormatter.string(from: consumptionUnit))"
  }

  override func numberOfSections(in _: UITableView) -> Int {
    fetchedResultsController.sections?.count ?? 0
  }

  override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
    let sectionInfo = fetchedResultsController.sections?[section]
    return sectionInfo?.numberOfObjects ?? 0
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "FuelCell", for: indexPath)

    if let quadInfoCell = cell as? QuadInfoCell {
      configureCell(quadInfoCell, atIndexPath: indexPath)
    }

    return cell
  }

  override func tableView(_: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let fuelEvent = fetchedResultsController.object(at: indexPath)
      DataManager.removeEvent(fuelEvent, forceOdometerUpdate: false)
      DataManager.saveContext()
    }
  }

  // MARK: - UIDataSourceModelAssociation

  func indexPathForElement(withModelIdentifier identifier: String, in _: UIView) -> IndexPath? {
    if let fuelEvent: FuelEvent = DataManager.managedObjectForModelIdentifier(identifier) {
      return fetchedResultsController.indexPath(forObject: fuelEvent)
    }
    return nil
  }

  func modelIdentifierForElement(at idx: IndexPath, in _: UIView) -> String? {
    let object = fetchedResultsController.object(at: idx)
    return DataManager.modelIdentifierForManagedObject(object)
  }

  // MARK: - UITableViewDelegate

  override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
    if let editController = storyboard!.instantiateViewController(withIdentifier: "FuelEventEditor") as? FuelEventEditorController {
      editController.event = fetchedResultsController.object(at: indexPath)
      navigationController?.pushViewController(editController, animated: true)
    }
  }

  override func tableView(_: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt _: IndexPath) {
    guard let tableCell = cell as? QuadInfoCell else { return }

    // https://www.fadel.io/blog/posts/ios-performance-tips-you-probably-didnt-know/
    tableCell.reset()
  }

  // MARK: - NSFetchedResultsControllerDelegate

  func controllerWillChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.beginUpdates()
  }

  func controller(_: NSFetchedResultsController<NSFetchRequestResult>, didChange _: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    switch type {
    case .insert:
      tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
    case .delete:
      tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
    case .move, .update:
      tableView.reloadSections(IndexSet(integer: sectionIndex), with: .fade)
    @unknown default:
      fatalError()
    }
  }

  func controller(_: NSFetchedResultsController<NSFetchRequestResult>, didChange _: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
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
    @unknown default:
      fatalError()
    }
  }

  func controllerDidChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()

    validateExport()
  }
}
