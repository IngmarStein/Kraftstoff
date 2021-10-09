//
//  FuelCalculatorController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import Combine
import CoreData
import SwiftUI
import UIKit

private struct FuelCalculatorDataRow: OptionSet {
  let rawValue: UInt

  static let distance = FuelCalculatorDataRow(rawValue: 0b0001)
  static let price = FuelCalculatorDataRow(rawValue: 0b0010)
  static let amount = FuelCalculatorDataRow(rawValue: 0b0100)
  static let all = FuelCalculatorDataRow(rawValue: 0b0111)
}

final class FuelCalculatorController: PageViewController, NSFetchedResultsControllerDelegate, EditablePageCellDelegate, EditablePageCellValidator {
  @AppStorage(wrappedValue: true, "recentFilledUp") var recentFilledUp: Bool

  var changeIsUserDriven = false
  var isShowingConvertSheet = false
  var selectedCarId: String?

  private lazy var fetchedResultsController: NSFetchedResultsController<Car> = {
    DataManager.fetchedResultsControllerForCars(delegate: self)
  }()

  var restoredSelectionIndex: IndexPath?
  var car: Car?
  var date: Date?
  var lastChangeDate: Date?
  var distance: Decimal?
  var price: Decimal?
  var fuelVolume: Decimal?
  var filledUp: Bool?
  var comment: String?

  let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: #selector(FuelCalculatorController.endEditingMode(_:)))
  let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: nil, action: #selector(FuelCalculatorController.saveAction(_:)))

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    userActivity = NSUserActivity(activityType: "com.github.ingmarstein.kraftstoff.fillup")
    userActivity?.title = NSLocalizedString("Fill-Up", comment: "")
    userActivity?.keywords = [NSLocalizedString("Fill-Up", comment: "")]
    userActivity?.isEligibleForSearch = true
    userActivity?.isEligibleForPrediction = true

    // Title bar
    doneButton.target = self
    doneButton.accessibilityIdentifier = "done"
    saveButton.target = self
    saveButton.accessibilityIdentifier = "save"
    title = NSLocalizedString("Fill-Up", comment: "")
  }

  // MARK: - View Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    // Remove tint from navigation bar
    navigationController?.navigationBar.tintColor = nil

    // Table contents
    createTableContentsWithAnimation(.none)
    tableView.reloadData()
    updateSaveButtonState()

    NotificationCenter.default.addObserver(self, selector: #selector(FuelCalculatorController.localeChanged(_:)), name: NSLocale.currentLocaleDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(FuelCalculatorController.willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
  }

  // MARK: - State Restoration

  private let SRCalculatorSelectedIndex = "FuelCalculatorSelectedIndex"
  private let SRCalculatorConvertSheet = "FuelCalculatorConvertSheet"
  private let SRCalculatorEditing = "FuelCalculatorEditing"

  override func encodeRestorableState(with coder: NSCoder) {
    if let indexPath = restoredSelectionIndex ?? tableView.indexPathForSelectedRow {
      coder.encode(indexPath, forKey: SRCalculatorSelectedIndex)
    }

    coder.encode(isShowingConvertSheet, forKey: SRCalculatorConvertSheet)
    coder.encode(isEditing, forKey: SRCalculatorEditing)

    super.encodeRestorableState(with: coder)
  }

  override func decodeRestorableState(with coder: NSCoder) {
    restoredSelectionIndex = coder.decodeObject(of: NSIndexPath.self, forKey: SRCalculatorSelectedIndex) as IndexPath?
    isShowingConvertSheet = coder.decodeBool(forKey: SRCalculatorConvertSheet)

    if coder.decodeBool(forKey: SRCalculatorEditing) {
      setEditing(true, animated: false)

      if isShowingConvertSheet {
        showOdometerConversionAlert()
      } else {
        selectRowAtIndexPath(restoredSelectionIndex)
        restoredSelectionIndex = nil
      }
    }

    super.decodeRestorableState(with: coder)
  }

  // MARK: - Mode switching for Table Rows

  override func setEditing(_ enabled: Bool, animated: Bool) {
    if isEditing != enabled {
      let animation: UITableView.RowAnimation = animated ? .fade : .none

      super.setEditing(enabled, animated: animated)

      if enabled {
        navigationItem.leftBarButtonItem = doneButton
        navigationItem.rightBarButtonItem = nil

        removeSectionAtIndex(1, withAnimation: animation)
      } else {
        navigationItem.leftBarButtonItem = nil

        if consumptionRowNeeded() {
          createConsumptionRowWithAnimation(animation)
        }

        updateSaveButtonState()
      }

      if !animated {
        tableView.reloadData()
      }
    }
  }

  // MARK: - Shake Events

  override var canBecomeFirstResponder: Bool {
    true
  }

  override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    if motion == .motionShake {
      handleShake()
    } else {
      super.motionEnded(motion, with: event)
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    userActivity?.becomeCurrent()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)

    userActivity?.resignCurrent()
  }

  func handleShake() {
    if isEditing {
      return
    }

    if distance == nil || distance!.isZero, fuelVolume == nil || fuelVolume!.isZero, price == nil || price!.isZero {
      return
    }

    UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.3, delay: 0, options: [], animations: {
      self.removeSectionAtIndex(1, withAnimation: .fade)
    }, completion: { _ in
      let now = Date()

      self.valueChanged(Date.dateWithoutSeconds(now), identifier: "date")
      self.valueChanged(now, identifier: "lastChangeDate")
      self.valueChanged(Decimal(0), identifier: "distance")
      self.valueChanged(Decimal(0), identifier: "price")
      self.valueChanged(Decimal(0), identifier: "fuelVolume")
      self.valueChanged(true, identifier: "filledUp")
      self.valueChanged("", identifier: "comment")

      self.recreateTableContentsWithAnimation(.left)
      self.updateSaveButtonState()
    })
  }

  // MARK: - Creating the Table Rows

  func consumptionRowNeeded() -> Bool {
    if isEditing {
      return false
    }

    if let filledUp = filledUp, !filledUp {
      return false
    }

    if (distance == nil || distance! <= 0) || (fuelVolume == nil || fuelVolume! <= 0) {
      return false
    }

    return true
  }

  func createConsumptionRowWithAnimation(_ animation: UITableView.RowAnimation) {
    // Conversion units
    let odometerUnit: UnitLength
    let fuelUnit: UnitVolume
    let consumptionUnit: UnitFuelEfficiency

    if let car = car {
      odometerUnit = car.ksOdometerUnit
      fuelUnit = car.ksFuelUnit
      consumptionUnit = car.ksFuelConsumptionUnit
    } else {
      odometerUnit = Units.distanceUnitFromLocale
      fuelUnit = Units.volumeUnitFromLocale
      consumptionUnit = Units.fuelConsumptionUnitFromLocale
    }

    // Compute the average consumption
    let cost = fuelVolume! * price!

    let liters = Units.litersForVolume(fuelVolume!, withUnit: fuelUnit)
    let kilometers = Units.kilometersForDistance(distance!, withUnit: odometerUnit)
    let consumption = Units.consumptionForKilometers(kilometers, liters: liters, inUnit: consumptionUnit)
    let consumptionUnitSymbol = Formatters.shortMeasurementFormatter.string(from: consumptionUnit)

    let consumptionString = "\(Formatters.currencyFormatter.string(from: cost as NSNumber)!) \(NSLocalizedString("/", comment: "")) \(Formatters.fuelVolumeFormatter.string(from: consumption as NSNumber)!) \(consumptionUnitSymbol)"

    // Substrings for highlighting
    let highlightStrings = [Formatters.currencyFormatter.currencySymbol!,
                            consumptionUnitSymbol]

    addSectionAtIndex(1, withAnimation: animation)

    addRowAtIndex(rowIndex: 0,
                  inSection: 1,
                  cellClass: ConsumptionTableCell.self,
                  cellData: ["label": consumptionString,
                             "highlightStrings": highlightStrings],
                  withAnimation: animation)
  }

  private func createDataRows(_ rowMask: FuelCalculatorDataRow, withAnimation animation: UITableView.RowAnimation) {
    let odometerUnit: UnitLength
    let fuelUnit: UnitVolume

    if let car = car {
      odometerUnit = car.ksOdometerUnit
      fuelUnit = car.ksFuelUnit
    } else {
      odometerUnit = Units.distanceUnitFromLocale
      fuelUnit = Units.volumeUnitFromLocale
    }

    let rowOffset = (fetchedResultsController.fetchedObjects!.count < 2) ? 1 : 2

    if rowMask.contains(.distance) {
      if distance == nil {
        if let recentDistance = UserDefaults.standard.object(forKey: "recentDistance") as? NSNumber {
          distance = recentDistance.decimalValue
        }
      }

      addRowAtIndex(rowIndex: 0 + rowOffset,
                    inSection: 0,
                    cellClass: NumberEditTableCell.self,
                    cellData: ["label": NSLocalizedString("Distance", comment: ""),
                               "suffix": " ".appending(Formatters.shortMeasurementFormatter.string(from: odometerUnit)),
                               "formatter": Formatters.distanceFormatter,
                               "valueIdentifier": "distance"],
                    withAnimation: animation)
    }

    if rowMask.contains(.price) {
      if price == nil {
        if let recentPrice = UserDefaults.standard.object(forKey: "recentPrice") as? NSNumber {
          price = recentPrice.decimalValue
        }
      }

      addRowAtIndex(rowIndex: 1 + rowOffset,
                    inSection: 0,
                    cellClass: NumberEditTableCell.self,
                    cellData: ["label": Units.fuelPriceUnitDescription(fuelUnit),
                               "formatter": Formatters.editPreciseCurrencyFormatter,
                               "alternateFormatter": Formatters.preciseCurrencyFormatter,
                               "valueIdentifier": "price"],
                    withAnimation: animation)
    }

    if rowMask.contains(.amount) {
      if fuelVolume == nil {
        if let recentFuelVolume = UserDefaults.standard.object(forKey: "recentFuelVolume") as? NSNumber {
          fuelVolume = recentFuelVolume.decimalValue
        }
      }

      addRowAtIndex(rowIndex: 2 + rowOffset,
                    inSection: 0,
                    cellClass: NumberEditTableCell.self,
                    cellData: ["label": Units.fuelUnitDescription(fuelUnit, discernGallons: false, pluralization: true),
                               "suffix": " ".appending(Formatters.shortMeasurementFormatter.string(from: fuelUnit)),
                               "formatter": fuelUnit == UnitVolume.liters
                                 ? Formatters.fuelVolumeFormatter
                                 : Formatters.preciseFuelVolumeFormatter,
                               "valueIdentifier": "fuelVolume"],
                    withAnimation: animation)
    }
  }

  private func createTableContentsWithAnimation(_ animation: UITableView.RowAnimation) {
    addSectionAtIndex(0, withAnimation: animation)

    // Car selector (optional)
    car = nil

    if fetchedResultsController.fetchedObjects!.count > 0 {
      if let selectedCar = selectedCarId {
        car = DataManager.managedObjectForModelIdentifier(selectedCar)
      } else if let preferredCar = UserDefaults.standard.string(forKey: "preferredCarID"), preferredCar != "" {
        car = DataManager.managedObjectForModelIdentifier(preferredCar)
      }

      if car == nil {
        car = fetchedResultsController.fetchedObjects!.first!
      }

      if fetchedResultsController.fetchedObjects!.count > 1 {
        addRowAtIndex(rowIndex: 0,
                      inSection: 0,
                      cellClass: CarTableCell.self,
                      cellData: ["label": NSLocalizedString("Car", comment: ""),
                                 "valueIdentifier": "car",
                                 "fetchedObjects": fetchedResultsController.fetchedObjects!],
                      withAnimation: animation)
      }
    }

    // Date selector
    if date == nil {
      date = Date.dateWithoutSeconds(Date())
    }

    if lastChangeDate == nil {
      lastChangeDate = Date()
    }

    addRowAtIndex(rowIndex: car != nil ? 1 : 0,
                  inSection: 0,
                  cellClass: DateEditTableCell.self,
                  cellData: ["label": NSLocalizedString("Date", comment: ""),
                             "formatter": Formatters.dateTimeFormatter,
                             "valueIdentifier": "date",
                             "valueTimestamp": "lastChangeDate",
                             "autorefresh": true],
                  withAnimation: animation)

    // Data rows for distance, price, fuel amount
    createDataRows(.all, withAnimation: animation)

    // Full-fillup selector
    filledUp = recentFilledUp

    if car != nil {
      addRowAtIndex(rowIndex: 5,
                    inSection: 0,
                    cellClass: SwitchTableCell.self,
                    cellData: ["label": NSLocalizedString("Full Fill-Up", comment: ""),
                               "valueIdentifier": "filledUp"],
                    withAnimation: animation)

      if comment == nil {
        comment = UserDefaults.standard.string(forKey: "recentComment")!
      }

      addRowAtIndex(rowIndex: 6,
                    inSection: 0,
                    cellClass: TextEditTableCell.self,
                    cellData: ["label": NSLocalizedString("Comment", comment: ""),
                               "valueIdentifier": "comment",
                               "maximumTextFieldLength": 0],
                    withAnimation: animation)
    }

    // Consumption info (optional)
    if consumptionRowNeeded() {
      createConsumptionRowWithAnimation(animation)
    }
  }

  // MARK: - Updating the Table Rows

  func recreateTableContentsWithAnimation(_ anim: UITableView.RowAnimation) {
    // Update model contents
    let animation: UITableView.RowAnimation
    if tableSections.isEmpty {
      animation = .none
    } else {
      animation = anim
      removeAllSectionsWithAnimation(.none)
    }

    createTableContentsWithAnimation(.none)

    // Update the tableview
    if animation == .none {
      tableView?.reloadData()
    } else {
      tableView?.reloadSections(IndexSet(integersIn: 0 ..< tableView.numberOfSections),
                                with: animation)
    }
  }

  private func recreateDataRowsWithPreviousCar(_ oldCar: Car?) {
    // Replace data rows in the internal data model
    for row in 2 ... 4 {
      removeRow(at: row, inSection: 0, withAnimation: .none)
    }

    createDataRows(.all, withAnimation: .none)

    // Update the tableview
    let odoChanged = oldCar == nil || oldCar!.odometerUnit != car!.odometerUnit

    let fuelChanged = oldCar == nil || (oldCar!.ksFuelUnit == UnitVolume.liters) != (car!.ksFuelUnit == UnitVolume.liters)

    var count = 0

    for row in 2 ... 4 {
      let animation: UITableView.RowAnimation
      if (row == 2 && odoChanged) || (row != 2 && fuelChanged) {
        animation = (count % 2) == 0 ? .right : .left
        count += 1
      } else {
        animation = .none
      }

      tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: animation)
    }

    // Reload date row too to update colors
    tableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .none)
  }

  private func recreateDistanceRowWithAnimation(_ animation: UITableView.RowAnimation) {
    let rowOffset = (fetchedResultsController.fetchedObjects!.count < 2) ? 1 : 2

    // Replace distance row in the internal data model
    removeRow(at: rowOffset, inSection: 0, withAnimation: .none)
    createDataRows(.distance, withAnimation: .none)

    // Update the tableview
    if animation != .none {
      tableView.reloadRows(at: [IndexPath(row: rowOffset, section: 0)], with: animation)
    } else {
      tableView.reloadData()
    }
  }

  // MARK: - Locale Handling

  @objc func localeChanged(_: AnyObject) {
    let previousSelection = tableView.indexPathForSelectedRow

    dismissKeyboardWithCompletion {
      self.recreateTableContentsWithAnimation(.none)
      self.selectRowAtIndexPath(previousSelection)
    }
  }

  // MARK: - System Events

  @objc func willEnterForeground(_: NSNotification) {
    if tableSections.isEmpty {
      return
    }

    // Last update must be longer than 5 minutes ago
    let noChangeInterval: TimeInterval

    if let lastChangeDate = lastChangeDate {
      noChangeInterval = Date().timeIntervalSince(lastChangeDate)
    } else {
      noChangeInterval = -1
    }

    if lastChangeDate == nil || noChangeInterval >= 300 || noChangeInterval < 0 {
      // Reset date to current time
      let now = Date()
      date = Date.dateWithoutSeconds(now)
      lastChangeDate = now

      // Update table
      let rowOffset = (fetchedResultsController.fetchedObjects!.count < 2) ? 0 : 1

      tableView.reloadRows(at: [IndexPath(row: rowOffset, section: 0)], with: .none)
    }
  }

  // MARK: - Storing Information in the Database

  @objc func saveAction(_: AnyObject) {
    navigationItem.rightBarButtonItem = nil

    UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.3, delay: 0, options: [], animations: {
      // Remove consumption row
      self.removeSectionAtIndex(1, withAnimation: .fade)
    }, completion: { _ in
      // Add new event object
      self.changeIsUserDriven = true

      DataManager.addToArchive(car: self.car!,
                               date: self.date!,
                               distance: self.distance!,
                               price: self.price!,
                               fuelVolume: self.fuelVolume!,
                               filledUp: self.filledUp ?? false,
                               comment: self.comment,
                               forceOdometerUpdate: false)

      // Reset calculator table
      self.valueChanged(Decimal(0), identifier: "distance")
      self.valueChanged(Decimal(0), identifier: "price")
      self.valueChanged(Decimal(0), identifier: "fuelVolume")
      self.valueChanged(true, identifier: "filledUp")
      self.valueChanged("", identifier: "comment")

      DataManager.saveContext()
    })
  }

  private func updateSaveButtonState() {
    var saveValid = true

    if car == nil {
      saveValid = false
    } else if (distance == nil || distance!.isZero) || (fuelVolume == nil || fuelVolume!.isZero) {
      saveValid = false
    } else if date == nil || DataManager.containsEventWithCar(car!, andDate: date!) {
      saveValid = false
    }

    navigationItem.rightBarButtonItem = saveValid ? saveButton : nil
  }

  // MARK: - Conversion for Odometer

  // A simple heuristic when to ask for distance conversion
  func needsOdometerConversionSheet() -> Bool {
    guard let car = car else { return false }
    guard let distance = distance else { return false }

    guard !car.ksOdometer.isNaN else { return false }

    // 1.) entered "distance" must be larger than car odometer
    let odometerUnit = car.ksOdometerUnit

    let rawDistance = Units.kilometersForDistance(distance, withUnit: odometerUnit)
    let convDistance = rawDistance - car.ksOdometer

    if convDistance <= 0 {
      return false
    }

    // 2.) consumption with converted distances is more 'logical'
    let liters = Units.litersForVolume(fuelVolume!, withUnit: car.ksFuelUnit)

    if liters <= 0 {
      return false
    }

    let rawConsumption = Units.consumptionForKilometers(rawDistance,
                                                        liters: liters,
                                                        inUnit: .litersPer100Kilometers)

    if rawConsumption.isNaN {
      return false
    }

    let convConsumption = Units.consumptionForKilometers(convDistance,
                                                         liters: liters,
                                                         inUnit: .litersPer100Kilometers)

    if convConsumption.isNaN {
      return false
    }

    let avgConsumption = Units.consumptionForKilometers(car.ksDistanceTotalSum,
                                                        liters: car.ksFuelVolumeTotalSum,
                                                        inUnit: .litersPer100Kilometers)

    let loBound: Decimal
    let hiBound: Decimal

    if avgConsumption.isNaN {
      loBound = Decimal(2)
      hiBound = Decimal(20)
    } else {
      loBound = avgConsumption * Decimal.fromLiteral(mantissa: 5, exponent: -1, isNegative: false)
      hiBound = avgConsumption * Decimal(5)
    }

    // conversion only when rawConsumption <= lowerBound
    if rawConsumption > loBound {
      return false
    }

    // conversion only when lowerBound <= convConversion <= highBound
    if convConsumption < loBound || convConsumption > hiBound {
      return false
    }

    // 3.) the event must be the youngest one
    if car.fuelEvents(afterDate: date!, dateMatches: false).count > 0 {
      return false
    }

    // => ask for a conversion
    return true
  }

  func showOdometerConversionAlert() {
    let odometerUnit = car!.ksOdometerUnit
    let rawDistance = Units.kilometersForDistance(distance!, withUnit: odometerUnit)
    let convDistance = rawDistance - car!.ksOdometer

    let distanceFormatter = Formatters.distanceFormatter

    let rawButton = "\(distanceFormatter.string(from: Units.distanceForKilometers(rawDistance, withUnit: odometerUnit) as NSNumber)!) \(Formatters.shortMeasurementFormatter.string(from: odometerUnit))"

    let convButton = "\(distanceFormatter.string(from: Units.distanceForKilometers(convDistance, withUnit: odometerUnit) as NSNumber)!) \(Formatters.shortMeasurementFormatter.string(from: odometerUnit))"

    let alertController = UIAlertController(title: NSLocalizedString("Convert from odometer reading into distance? Please choose the distance driven:", comment: ""),
                                            message: nil,
                                            preferredStyle: .actionSheet)
    let cancelAction = UIAlertAction(title: rawButton, style: .default) { _ in
      self.isShowingConvertSheet = false
      self.setEditing(false, animated: true)
    }

    let destructiveAction = UIAlertAction(title: convButton, style: .destructive) { _ in
      self.isShowingConvertSheet = false

      // Replace distance in table with difference to car odometer
      let odometerUnit = self.car!.ksOdometerUnit
      let rawDistance = Units.kilometersForDistance(self.distance!, withUnit: odometerUnit)
      let convDistance = rawDistance - self.car!.ksOdometer

      self.distance = Units.distanceForKilometers(convDistance, withUnit: odometerUnit)
      self.valueChanged(self.distance, identifier: "distance")

      self.recreateDistanceRowWithAnimation(.right)

      self.setEditing(false, animated: true)
    }

    alertController.addAction(cancelAction)
    alertController.addAction(destructiveAction)
    alertController.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
    isShowingConvertSheet = true
    present(alertController, animated: true, completion: nil)
  }

  // MARK: - Leaving Editing Mode

  @IBAction func endEditingMode(_: AnyObject) {
    dismissKeyboardWithCompletion {
      if self.needsOdometerConversionSheet() {
        self.showOdometerConversionAlert()
      } else {
        self.setEditing(false, animated: true)
      }
    }
  }

  // MARK: - EditablePageCellDelegate

  func valueForIdentifier(_ valueIdentifier: String) -> Any? {
    switch valueIdentifier {
    case "car": return car
    case "date": return date
    case "lastChangeDate": return lastChangeDate
    case "distance": return distance
    case "price": return price
    case "fuelVolume": return fuelVolume
    case "filledUp": return filledUp
    case "comment": return comment
    default: return nil
    }
  }

  func valueChanged(_ newValue: Any?, identifier valueIdentifier: String) {
    if let date = newValue as? Date {
      if valueIdentifier == "date" {
        self.date = Date.dateWithoutSeconds(date)
      } else if valueIdentifier == "lastChangeDate" {
        lastChangeDate = date
      }

    } else if let decimalNumber = newValue as? Decimal {
      let recentKey: String?

      if valueIdentifier == "distance" {
        distance = decimalNumber
        recentKey = "recentDistance"
      } else if valueIdentifier == "fuelVolume" {
        fuelVolume = decimalNumber
        recentKey = "recentFuelVolume"
      } else if valueIdentifier == "price" {
        price = decimalNumber
        recentKey = "recentPrice"
      } else {
        recentKey = nil
      }

      if let recentKey = recentKey {
        let defaults = UserDefaults.standard

        defaults.set(newValue, forKey: recentKey)
        defaults.synchronize()
      }

    } else if valueIdentifier == "filledUp" {
      guard let value = newValue as? Bool else { return }
      filledUp = value

      recentFilledUp = value

      if !isEditing {
        if consumptionRowNeeded() {
          createConsumptionRowWithAnimation(.fade)
        } else {
          removeSectionAtIndex(1, withAnimation: .fade)
        }
      }

    } else if valueIdentifier == "comment" {
      comment = newValue as? String

      let defaults = UserDefaults.standard

      defaults.set(newValue, forKey: "recentComment")
      defaults.synchronize()

    } else if valueIdentifier == "car" {
      if car == nil || !car!.isEqual(newValue) {
        let oldCar = car
        car = newValue as? Car
        recreateDataRowsWithPreviousCar(oldCar)
      }

      if !car!.objectID.isTemporaryID {
        let defaults = UserDefaults.standard
        defaults.set(DataManager.modelIdentifierForManagedObject(car!) as NSString?, forKey: "preferredCarID")
        defaults.synchronize()
      }
    }
  }

  // MARK: - EditablePageCellValidator

  func valueValid(_ newValue: Any?, identifier valueIdentifier: String) -> Bool {
    // Validate only when there is a car for saving
    guard let car = car else { return true }

    // Date must be collision free
    if let date = newValue as? Date {
      if valueIdentifier == "date" {
        if DataManager.containsEventWithCar(car, andDate: date) {
          return false
        }
      }
    }

    // DecimalNumbers <= 0.0 are invalid
    if let decimalNumber = newValue as? Decimal {
      if valueIdentifier != "price" {
        if decimalNumber.isSignMinus || decimalNumber.isZero {
          return false
        }
      }
    }

    return true
  }

  // MARK: - NSFetchedResultsControllerDelegate

  func controllerDidChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>) {
    // FIXME: this seems to be necessary to update fetchedObjects
    do {
      try fetchedResultsController.performFetch()
    } catch {
      // ignore
    }

    recreateTableContentsWithAnimation(changeIsUserDriven ? .right : .none)
    updateSaveButtonState()

    changeIsUserDriven = false
  }

  // MARK: - UITableViewDataSource

  override func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
    nil
  }

  // MARK: - UITableViewDelegate

  override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    let cell = tableView.cellForRow(at: indexPath)

    if cell is SwitchTableCell || cell is ConsumptionTableCell {
      return nil
    }

    setEditing(true, animated: true)
    return indexPath
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    activateCellAtIndexPath(indexPath)
    tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
  }

  override func tableView(_: UITableView, didDeselectRowAt indexPath: IndexPath) {
    deactivateCellAtIndexPath(indexPath)
  }
}
