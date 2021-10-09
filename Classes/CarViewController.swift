//
//  CarViewController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 05.05.15.
//
//

import CoreData
import CoreSpotlight
import UIKit

private let maxEditHelpCounter = 1
private let carViewEditedObject = "CarViewEditedObject"

final class CarViewController: UITableViewController, UIDataSourceModelAssociation, UIGestureRecognizerDelegate, NSFetchedResultsControllerDelegate, CarConfigurationControllerDelegate, UIDocumentPickerDelegate {
  var editedObject: Car!

  private lazy var fetchedResultsController: NSFetchedResultsController<Car> = {
    DataManager.fetchedResultsControllerForCars(delegate: self)
  }()

  private var documentPickerViewController: UIDocumentPickerViewController!

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
    title = NSLocalizedString("Cars", comment: "")
    navigationItem.leftBarButtonItem = nil

    let rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(CarViewController.insertNewObject(_:)))
    rightBarButtonItem.accessibilityIdentifier = "add"
    navigationItem.rightBarButtonItem = rightBarButtonItem

    // Gesture recognizer for touch and hold
    longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(CarViewController.handleLongPress(_:)))
    longPressRecognizer!.delegate = self

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
                                           selector: #selector(CarViewController.localeChanged(_:)),
                                           name: NSLocale.currentLocaleDidChangeNotification,
                                           object: nil)
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
      coder.encode(DataManager.modelIdentifierForManagedObject(editedObject) as NSString?, forKey: carViewEditedObject)
    }
    super.encodeRestorableState(with: coder)
  }

  override func decodeRestorableState(with coder: NSCoder) {
    super.decodeRestorableState(with: coder)

    if let modelIdentifier = coder.decodeObject(of: NSString.self, forKey: carViewEditedObject) as String? {
      editedObject = DataManager.managedObjectForModelIdentifier(modelIdentifier)
    }

    // -> openradar #13438788
    tableView.reloadData()
  }

  // MARK: - Locale Handling

  @objc func localeChanged(_: AnyObject) {
    // Invalidate fuelEvent-controller and any precomputed statistics
    if navigationController!.topViewController === self {
      fuelEventController = nil
    }

    tableView.reloadData()
  }

  // MARK: - Help Badge

  private func updateHelp(_ animated: Bool) {
    let defaults = UserDefaults.standard

    // Number of cars determines the help badge
    let helpViewFrame: CGRect
    let helpViewContentMode: UIView.ContentMode
    let helpImage: UIImage?

    let carCount = fetchedResultsController.fetchedObjects!.count

    if !isEditing && carCount == 0 {
      helpImage = StyleKit.imageOfStartHelpCanvas(text: NSLocalizedString("StartHelp", comment: "")).withRenderingMode(.alwaysTemplate)
      helpViewFrame = CGRect(x: 0, y: 0, width: view.bounds.size.width, height: 70)
      helpViewContentMode = .right

      defaults.set(0, forKey: "editHelpCounter")
    } else if isEditing && carCount >= 1 && carCount <= 3 {
      let editCounter = defaults.integer(forKey: "editHelpCounter")

      if editCounter < maxEditHelpCounter {
        defaults.set(editCounter + 1, forKey: "editHelpCounter")
        helpImage = StyleKit.imageOfEditHelpCanvas(line1: NSLocalizedString("EditHelp1", comment: ""), line2: NSLocalizedString("EditHelp2", comment: "")).withRenderingMode(.alwaysTemplate)
        helpViewContentMode = .left
        helpViewFrame = CGRect(x: 0.0, y: CGFloat(carCount) * 91.0 - 16.0, width: view.bounds.size.width, height: 92.0)
      } else {
        helpImage = nil
        helpViewContentMode = .left
        helpViewFrame = .zero
      }
    } else {
      helpImage = nil
      helpViewContentMode = .left
      helpViewFrame = .zero
    }

    // Remove outdated help images
    var helpView = view.viewWithTag(100) as? UIImageView

    if helpImage == nil || (helpView != nil && helpView!.frame != helpViewFrame) {
      if animated {
        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.33, delay: 0, options: [UIView.AnimationOptions.curveEaseOut], animations: {
          helpView?.alpha = 0.0
        }, completion: { _ in
          helpView?.removeFromSuperview()
        })
      } else {
        helpView?.removeFromSuperview()
      }
    }

    // Add or update existing help image
    if let helpImage = helpImage {
      if let helpView = helpView {
        helpView.image = helpImage
        helpView.frame = helpViewFrame
      } else {
        helpView = UIImageView(image: helpImage)
        helpView!.tag = 100
        helpView!.frame = helpViewFrame
        helpView!.alpha = animated ? 0.0 : 1.0
        helpView!.contentMode = helpViewContentMode

        view.addSubview(helpView!)

        if animated {
          UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.33, delay: 0.8, options: [UIView.AnimationOptions.curveEaseOut], animations: {
            helpView?.alpha = 1.0
          })
        }
      }
    }

    // Update the toolbar button
    navigationItem.leftBarButtonItem = (carCount == 0) ? nil : editButtonItem
    checkEnableEditButton()
  }

  private func hideHelp(_ animated: Bool) {
    if let helpView = view.viewWithTag(100) as? UIImageView {
      if animated {
        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.33, delay: 0.8, options: [UIView.AnimationOptions.curveEaseOut], animations: {
          helpView.alpha = 0.0
        }, completion: { _ in
          helpView.removeFromSuperview()
        })
      } else {
        helpView.removeFromSuperview()
      }
    }
  }

  // MARK: - CarConfigurationControllerDelegate

  func carConfigurationController(_ controller: CarConfigurationController, didFinishWithResult result: CarConfigurationResult) {
    if result == .createSucceeded {
      changeIsUserDriven = false
      // Create new car
      let newCar = Car(context: DataManager.managedObjectContext)
      newCar.order = 0
      newCar.timestamp = Date()
      newCar.ksOdometerUnit = .fromPersistentId(controller.odometerUnit!.int32Value)

      newCar.ksOdometer = Units.kilometersForDistance(controller.odometer!,
                                                      withUnit: .fromPersistentId(controller.odometerUnit!.int32Value))

      newCar.ksFuelUnit = .fromPersistentId(controller.fuelUnit!.int32Value)
      newCar.ksFuelConsumptionUnit = .fromPersistentId(controller.fuelConsumptionUnit!.int32Value)

      let addDemoEvents: Bool
      let enteredName = controller.name!
      let enteredPlate = controller.plate!
      if enteredName.lowercased() == "apple", enteredPlate.lowercased() == "demo" {
        addDemoEvents = true
        newCar.name = "Toyota IQ+"
        newCar.numberPlate = "SLS IO 101"
      } else {
        addDemoEvents = false
        newCar.name = enteredName
        newCar.numberPlate = enteredPlate
      }

      // Update order of existing cars
      for car in fetchedResultsController.fetchedObjects! {
        car.order += 1
      }

      if addDemoEvents {
        // add demo data
        newCar.addDemoEvents(inContext: DataManager.managedObjectContext)
      }

      // Saving here is important here to get a stable objectID for the fuelEvent fetches
      DataManager.saveContext()
    } else if result == .editSucceeded {
      editedObject.name = controller.name!
      editedObject.numberPlate = controller.plate!
      editedObject.ksOdometerUnit = .fromPersistentId(controller.odometerUnit!.int32Value)

      let odometer = max(Units.kilometersForDistance(controller.odometer!,
                                                     withUnit: .fromPersistentId(controller.odometerUnit!.int32Value)), editedObject.ksDistanceTotalSum)

      editedObject.ksOdometer = odometer
      editedObject.ksFuelUnit = .fromPersistentId(controller.fuelUnit!.int32Value)
      editedObject.ksFuelConsumptionUnit = .fromPersistentId(controller.fuelConsumptionUnit!.int32Value)

      DataManager.saveContext()

      // Invalidate fuelEvent-controller and any precomputed statistics
      fuelEventController = nil
    }

    editedObject = nil
    checkEnableEditButton()

    dismiss(animated: result != .aborted, completion: nil)
  }

  // MARK: - Adding a new object

  override func setEditing(_ editing: Bool, animated: Bool) {
    super.setEditing(editing, animated: animated)

    checkEnableEditButton()
    updateHelp(animated)

    // Force Core Data save after editing mode is finished
    /*
     if !editing {
       DataManager.saveContext()
     }
     */
  }

  private func checkEnableEditButton() {
    editButtonItem.isEnabled = fetchedResultsController.fetchedObjects!.count > 0
  }

  @objc func insertNewObject(_ sender: UIBarButtonItem) {
    if !StoreManager.sharedInstance.checkCarCount() {
      StoreManager.sharedInstance.showBuyOptions(self)
      return
    }

    setEditing(false, animated: true)

    let alertController = UIAlertController(title: NSLocalizedString("New Car", comment: ""),
                                            message: nil,
                                            preferredStyle: .actionSheet)
    let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
    }
    let newAction = UIAlertAction(title: NSLocalizedString("New Car", comment: ""), style: .default) { [unowned self] _ in
      if let configurator = self.storyboard!.instantiateViewController(withIdentifier: "CarConfigurationController") as? CarConfigurationController {
        configurator.delegate = self
        configurator.editingExistingObject = false

        let navController = UINavigationController(rootViewController: configurator)
        navController.restorationIdentifier = "CarConfigurationNavigationController"
        navController.navigationBar.tintColor = self.navigationController!.navigationBar.tintColor

        self.present(navController, animated: true, completion: nil)
      }
    }
    let importAction = UIAlertAction(title: NSLocalizedString("Import", comment: ""), style: .default) { [unowned self] _ in
      guard let csvType = UTType("public.comma-separated-values-text") else { return }
      self.documentPickerViewController = UIDocumentPickerViewController(forOpeningContentTypes: [csvType])
      self.documentPickerViewController.delegate = self

      self.present(self.documentPickerViewController, animated: true, completion: nil)
    }
    alertController.addAction(cancelAction)
    alertController.addAction(newAction)
    alertController.addAction(importAction)
    alertController.popoverPresentationController?.barButtonItem = sender

    present(alertController, animated: true, completion: nil)
  }

  // MARK: - UIDocumentPickerDelegate

  func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
    documentPickerViewController = nil
  }

  func documentPicker(_: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
    UIApplication.kraftstoffAppDelegate.importCSV(at: url, parentViewController: self)

    documentPickerViewController = nil
  }

  // MARK: - UIGestureRecognizerDelegate

  func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    // Editing mode must be enabled
    if isEditing {
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

  @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
    if sender.state == .began {
      if let indexPath = tableView.indexPathForRow(at: sender.location(in: self.tableView)) {
        DataManager.saveContext()
        editedObject = fetchedResultsController.object(at: indexPath)

        // Present modal car configurator
        guard let configurator = storyboard!.instantiateViewController(withIdentifier: "CarConfigurationController") as? CarConfigurationController else { return }
        configurator.delegate = self
        configurator.editingExistingObject = true

        configurator.name = editedObject.name

        if configurator.name!.count > TextEditTableCell.DefaultMaximumTextFieldLength {
          configurator.name = ""
        }

        configurator.plate = editedObject.numberPlate

        if configurator.plate!.count > TextEditTableCell.DefaultMaximumTextFieldLength {
          configurator.plate = ""
        }

        configurator.odometerUnit = NSNumber(value: editedObject.odometerUnit)
        configurator.odometer = Units.distanceForKilometers(editedObject.ksOdometer,
                                                            withUnit: editedObject.ksOdometerUnit)

        configurator.fuelUnit = NSNumber(value: editedObject.fuelUnit)
        configurator.fuelConsumptionUnit = NSNumber(value: editedObject.fuelConsumptionUnit)

        let navController = UINavigationController(rootViewController: configurator)
        navController.restorationIdentifier = "CarConfigurationNavigationController"
        navController.navigationBar.tintColor = navigationController!.navigationBar.tintColor

        present(navController, animated: true, completion: nil)

        // Edit started => prevent edit help from now on
        UserDefaults.standard.set(maxEditHelpCounter, forKey: "editHelpCounter")

        // Quit editing mode
        setEditing(false, animated: true)
      }
    }
  }

  // MARK: - Removing an Existing Object

  func removeExistingObject(at indexPath: IndexPath) {
    let deletedCar = fetchedResultsController.object(at: indexPath)
    let deletedCarOrder = deletedCar.order

    // Invalidate preference for deleted car
    let preferredCarID = UserDefaults.standard.string(forKey: "preferredCarID")
    let deletedCarID = DataManager.modelIdentifierForManagedObject(deletedCar)

    if deletedCarID == preferredCarID {
      UserDefaults.standard.set("", forKey: "preferredCarID")
    }

    if let itemID = deletedCarID {
      CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [itemID], completionHandler: nil)
    }

    // Delete the managed object for the given index path
    DataManager.managedObjectContext.delete(deletedCar)
    DataManager.saveContext()

    // Update order of existing objects
    changeIsUserDriven = true

    for car in fetchedResultsController.fetchedObjects! where car.order > deletedCarOrder {
      car.order -= 1
    }

    DataManager.saveContext()

    changeIsUserDriven = false

    // Exit editing mode after last object is deleted
    if isEditing {
      if fetchedResultsController.fetchedObjects!.count == 0 {
        setEditing(false, animated: true)
      }
    }
  }

  // MARK: - UITableViewDataSource

  func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath) {
    guard let tableCell = cell as? QuadInfoCell else { return }
    let car = fetchedResultsController.object(at: indexPath)

    tableCell.large = true

    // name and number plate
    tableCell.topLeftLabel.text = car.name
    tableCell.topLeftAccessibilityLabel = nil

    tableCell.botLeftLabel.text = car.numberPlate
    tableCell.topRightAccessibilityLabel = nil

    // Average consumption
    let avgConsumption: String
    let consumptionUnit = car.ksFuelConsumptionUnit

    let distance = car.ksDistanceTotalSum
    let fuelVolume = car.ksFuelVolumeTotalSum

    if distance > 0, fuelVolume > 0 {
      avgConsumption = Formatters.fuelVolumeFormatter.string(from: Units.consumptionForKilometers(distance, liters: fuelVolume, inUnit: consumptionUnit) as NSNumber)!
      tableCell.topRightAccessibilityLabel = avgConsumption
      tableCell.botRightAccessibilityLabel = Formatters.mediumMeasurementFormatter.string(from: consumptionUnit)
    } else {
      avgConsumption = NSLocalizedString("-", comment: "")
      tableCell.topRightAccessibilityLabel = NSLocalizedString("fuel mileage not available", comment: "")
      tableCell.botRightAccessibilityLabel = nil
    }

    tableCell.topRightLabel.text = avgConsumption
    tableCell.botRightLabel.text = Formatters.shortMeasurementFormatter.string(from: consumptionUnit)
  }

  override func numberOfSections(in _: UITableView) -> Int {
    fetchedResultsController.sections?.count ?? 0
  }

  override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
    let sectionInfo = fetchedResultsController.sections![section]
    return sectionInfo.numberOfObjects
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "QuadInfoCell", for: indexPath)

    configureCell(cell, atIndexPath: indexPath)

    return cell
  }

  override func tableView(_: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      removeExistingObject(at: indexPath)
    }
  }

  override func tableView(_: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    let basePath = sourceIndexPath.dropLast()

    if basePath.compare(destinationIndexPath.dropLast()) != .orderedSame {
      fatalError("Invalid index path for moveRow")
    }

    let cmpResult = sourceIndexPath.compare(destinationIndexPath)
    let length = sourceIndexPath.count
    let from: Int
    let to: Int

    if cmpResult == .orderedAscending {
      from = sourceIndexPath[length - 1]
      to = destinationIndexPath[length - 1]
    } else if cmpResult == .orderedDescending {
      to = sourceIndexPath[length - 1]
      from = destinationIndexPath[length - 1]
    } else {
      return
    }

    for i in from ... to {
      let car = fetchedResultsController.object(at: basePath.appending(i))
      var order = Int(car.order)

      if cmpResult == .orderedAscending {
        order = (i != from) ? order - 1 : to
      } else {
        order = (i != to) ? order + 1 : from
      }

      car.order = Int32(order)
    }
  }

  override func tableView(_: UITableView, canMoveRowAt _: IndexPath) -> Bool {
    true
  }

  override func tableView(_: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt _: IndexPath) {
    guard let tableCell = cell as? QuadInfoCell else { return }

    // https://www.fadel.io/blog/posts/ios-performance-tips-you-probably-didnt-know/
    tableCell.reset()
  }

  // MARK: - UIDataSourceModelAssociation

  func indexPathForElement(withModelIdentifier identifier: String, in _: UIView) -> IndexPath? {
    guard let car: Car = DataManager.managedObjectForModelIdentifier(identifier) else { return nil }

    return fetchedResultsController.indexPath(forObject: car)
  }

  func modelIdentifierForElement(at idx: IndexPath, in _: UIView) -> String? {
    let object = fetchedResultsController.object(at: idx)
    return DataManager.modelIdentifierForManagedObject(object)
  }

  // MARK: - UITableViewDelegate

  override func tableView(_: UITableView, targetIndexPathForMoveFromRowAt _: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
    proposedDestinationIndexPath
  }

  override func tableView(_: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    isEditing ? nil : indexPath
  }

  override func tableView(_: UITableView, willBeginEditingRowAt _: IndexPath) {
    editButtonItem.isEnabled = false
    hideHelp(true)
  }

  override func tableView(_: UITableView, didEndEditingRowAt _: IndexPath?) {
    checkEnableEditButton()
    updateHelp(true)
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
    guard !changeIsUserDriven else { return }

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
      if let indexPath = indexPath, let newIndexPath = newIndexPath, indexPath != newIndexPath {
        tableView.deleteRows(at: [indexPath], with: .fade)
        tableView.insertRows(at: [newIndexPath], with: .fade)
      }
    case .update:
      if let indexPath = indexPath {
        tableView.reloadRows(at: [indexPath], with: .automatic)
      }
    @unknown default:
      fatalError()
    }
  }

  func controllerDidChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>) {
    // FIXME: this seems to be necessary to update fetchedObjects
    do {
      try fetchedResultsController.performFetch()
    } catch {
      // ignore
    }

    tableView.endUpdates()

    updateHelp(true)
    checkEnableEditButton()

    changeIsUserDriven = false
  }

  @IBSegueAction func showFuelEvents(_ coder: NSCoder, sender: Any?) -> FuelEventController? {
    let selection: IndexPath?
    if let cell = sender as? UITableViewCell {
      selection = tableView.indexPath(for: cell)
    } else {
      selection = tableView.indexPathForSelectedRow
    }

    let fuelEventController = FuelEventController(coder: coder)
    if let selection = selection {
      let selectedCar = fetchedResultsController.object(at: selection)
      fuelEventController?.selectedCar = selectedCar
    }

    return fuelEventController
  }

  // MARK: - Memory Management

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()

    if navigationController!.topViewController === self {
      fuelEventController = nil
    }
  }
}
