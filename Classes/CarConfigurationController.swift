//
//  CarConfigurationController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import UIKit

enum CarConfigurationResult: Int {
  case canceled
  case createSucceeded
  case editSucceeded
  case aborted
}

protocol CarConfigurationControllerDelegate: AnyObject {
  func carConfigurationController(_ controller: CarConfigurationController, didFinishWithResult: CarConfigurationResult)
}

private let SRConfiguratorDelegate = "FuelConfiguratorDelegate"
private let SRConfiguratorEditMode = "FuelConfiguratorEditMode"
private let SRConfiguratorCancelSheet = "FuelConfiguratorCancelSheet"
private let SRConfiguratorDataChanged = "FuelConfiguratorDataChanged"
private let SRConfiguratorPreviousSelectionIndex = "FuelConfiguratorPreviousSelectionIndex"
private let SRConfiguratorName = "FuelConfiguratorName"
private let SRConfiguratorPlate = "FuelConfiguratorPlate"
private let SRConfiguratorOdometerUnit = "FuelConfiguratorOdometerUnit"
private let SRConfiguratorFuelUnit = "FuelConfiguratorFuelUnit"
private let SRConfiguratorFuelConsumptionUnit = "FuelConfiguratorFuelConsumptionUnit"

final class CarConfigurationController: PageViewController, UIViewControllerRestoration, EditablePageCellDelegate, EditablePageCellFocusHandler {
  var isShowingCancelSheet = false
  var dataChanged = false
  var previousSelectionIndex: IndexPath?

  var name: String?
  var plate: String?
  var odometerUnit: NSNumber?
  var odometer: Decimal?
  var fuelUnit: NSNumber?
  var fuelConsumptionUnit: NSNumber?

  var editingExistingObject = false

  weak var delegate: CarConfigurationControllerDelegate?

  // MARK: - View Lifecycle

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    restorationClass = type(of: self)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    recreateTableContents()

    // Configure the navigation bar
    let leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(CarConfigurationController.handleSave(_:)))
    leftBarButtonItem.accessibilityIdentifier = "done"
    navigationItem.leftBarButtonItem = leftBarButtonItem
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(CarConfigurationController.handleCancel(_:)))
    navigationItem.title = editingExistingObject ? NSLocalizedString("Edit Car", comment: "") : NSLocalizedString("New Car", comment: "")

    // Remove tint from navigation bar
    navigationController?.navigationBar.tintColor = nil

    NotificationCenter.default.addObserver(self, selector: #selector(CarConfigurationController.localeChanged(_:)), name: NSLocale.currentLocaleDidChangeNotification, object: nil)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    dataChanged = false

    selectRowAtIndexPath(IndexPath(row: 0, section: 0))
  }

  // MARK: - State Restoration

  static func viewController(withRestorationIdentifierPath _: [String], coder: NSCoder) -> UIViewController? {
    if let storyboard = coder.decodeObject(forKey: UIApplication.stateRestorationViewControllerStoryboardKey) as? UIStoryboard {
      if let controller = storyboard.instantiateViewController(withIdentifier: "CarConfigurationController") as? CarConfigurationController {
        controller.editingExistingObject = coder.decodeBool(forKey: SRConfiguratorEditMode)

        return controller
      }
    }

    return nil
  }

  override func encodeRestorableState(with coder: NSCoder) {
    let indexPath = isShowingCancelSheet ? previousSelectionIndex : tableView.indexPathForSelectedRow

    // swiftlint:disable comma
    coder.encode(delegate, forKey: SRConfiguratorDelegate)
    coder.encode(editingExistingObject, forKey: SRConfiguratorEditMode)
    coder.encode(isShowingCancelSheet, forKey: SRConfiguratorCancelSheet)
    coder.encode(dataChanged, forKey: SRConfiguratorDataChanged)
    coder.encode(indexPath, forKey: SRConfiguratorPreviousSelectionIndex)
    coder.encode(name as NSString?, forKey: SRConfiguratorName)
    coder.encode(plate as NSString?, forKey: SRConfiguratorPlate)
    coder.encode(fuelUnit, forKey: SRConfiguratorFuelUnit)
    coder.encode(fuelConsumptionUnit, forKey: SRConfiguratorFuelConsumptionUnit)
    // swiftlint:enable comma

    super.encodeRestorableState(with: coder)
  }

  override func decodeRestorableState(with coder: NSCoder) {
    delegate = coder.decodeObject(forKey: SRConfiguratorDelegate) as? CarConfigurationControllerDelegate
    isShowingCancelSheet = coder.decodeBool(forKey: SRConfiguratorCancelSheet)
    dataChanged = coder.decodeBool(forKey: SRConfiguratorDataChanged)
    previousSelectionIndex = coder.decodeObject(of: NSIndexPath.self, forKey: SRConfiguratorPreviousSelectionIndex) as IndexPath?
    name = coder.decodeObject(of: NSString.self, forKey: SRConfiguratorName) as String?
    plate = coder.decodeObject(of: NSString.self, forKey: SRConfiguratorPlate) as String?
    fuelUnit = coder.decodeObject(of: NSNumber.self, forKey: SRConfiguratorFuelUnit)
    fuelConsumptionUnit = coder.decodeObject(of: NSNumber.self, forKey: SRConfiguratorFuelConsumptionUnit)

    tableView.reloadData()

    if isShowingCancelSheet {
      showCancelSheet()
    } else {
      selectRowAtIndexPath(previousSelectionIndex)
    }

    super.decodeRestorableState(with: coder)
  }

  // MARK: - Creating the Table Rows

  func createOdometerRowWithAnimation(_ animation: UITableView.RowAnimation) {
    let unit = UnitLength.fromPersistentId(odometerUnit!.int32Value)
    let suffix = " ".appending(Formatters.shortMeasurementFormatter.string(from: unit))

    if odometer == nil {
      odometer = 0
    }

    addRowAtIndex(rowIndex: 3,
                  inSection: 0,
                  cellClass: NumberEditTableCell.self,
                  cellData: ["label": NSLocalizedString("Odometer Reading", comment: ""),
                             "suffix": suffix,
                             "formatter": Formatters.distanceFormatter,
                             "valueIdentifier": "odometer"],
                  withAnimation: animation)
  }

  private func createTableContents() {
    addSectionAtIndex(0, withAnimation: .none)

    if name == nil {
      name = ""
    }

    addRowAtIndex(rowIndex: 0,
                  inSection: 0,
                  cellClass: TextEditTableCell.self,
                  cellData: ["label": NSLocalizedString("Name", comment: ""),
                             "valueIdentifier": "name"],
                  withAnimation: .none)

    if plate == nil {
      plate = ""
    }

    addRowAtIndex(rowIndex: 1,
                  inSection: 0,
                  cellClass: TextEditTableCell.self,
                  cellData: ["label": NSLocalizedString("License Plate", comment: ""),
                             "valueIdentifier": "plate",
                             "autocapitalizeAll": true],
                  withAnimation: .none)

    if odometerUnit == nil {
      odometerUnit = NSNumber(value: Units.distanceUnitFromLocale.persistentId)
    }

    let odometerUnitPickerLabels = [Formatters.longMeasurementFormatter.string(from: UnitLength.kilometers).capitalized,
                                    Formatters.longMeasurementFormatter.string(from: UnitLength.miles).capitalized]

    addRowAtIndex(rowIndex: 2,
                  inSection: 0,
                  cellClass: PickerTableCell.self,
                  cellData: ["label": NSLocalizedString("Odometer Type", comment: ""),
                             "valueIdentifier": "odometerUnit",
                             "labels": odometerUnitPickerLabels],
                  withAnimation: .none)

    createOdometerRowWithAnimation(.none)

    if fuelUnit == nil {
      fuelUnit = NSNumber(value: Units.volumeUnitFromLocale.persistentId)
    }

    let fuelUnitPickerLabels = [Formatters.longMeasurementFormatter.string(from: UnitVolume.liters).capitalized,
                                Formatters.longMeasurementFormatter.string(from: UnitVolume.gallons).capitalized,
                                Formatters.longMeasurementFormatter.string(from: UnitVolume.imperialGallons).capitalized]

    addRowAtIndex(rowIndex: 4,
                  inSection: 0,
                  cellClass: PickerTableCell.self,
                  cellData: ["label": NSLocalizedString("Fuel Unit", comment: ""),
                             "valueIdentifier": "fuelUnit",
                             "labels": fuelUnitPickerLabels],
                  withAnimation: .none)

    if fuelConsumptionUnit == nil {
      fuelConsumptionUnit = NSNumber(value: Units.fuelConsumptionUnitFromLocale.persistentId)
    }

    let fuelConsumptionUnitPickerLabels = [
      Formatters.longMeasurementFormatter.string(from: UnitFuelEfficiency.litersPer100Kilometers).capitalized,
      Formatters.longMeasurementFormatter.string(from: UnitFuelEfficiency.milesPerGallon).capitalized,
      Formatters.longMeasurementFormatter.string(from: UnitFuelEfficiency.milesPerImperialGallon).capitalized,
    ]

    let fuelConsumptionUnitPickerShortLabels = [
      Formatters.shortMeasurementFormatter.string(from: UnitFuelEfficiency.litersPer100Kilometers),
      Formatters.shortMeasurementFormatter.string(from: UnitFuelEfficiency.milesPerGallon),
      Formatters.shortMeasurementFormatter.string(from: UnitFuelEfficiency.milesPerImperialGallon),
    ]

    addRowAtIndex(rowIndex: 5,
                  inSection: 0,
                  cellClass: PickerTableCell.self,
                  cellData: ["label": NSLocalizedString("Mileage", comment: ""),
                             "valueIdentifier": "fuelConsumptionUnit",
                             "labels": fuelConsumptionUnitPickerLabels,
                             "shortLabels": fuelConsumptionUnitPickerShortLabels],
                  withAnimation: .none)
  }

  private func recreateTableContents() {
    removeAllSectionsWithAnimation(.none)
    createTableContents()
    tableView.reloadData()
  }

  func recreateOdometerRowWithAnimation(_ animation: UITableView.RowAnimation) {
    removeRow(at: 3, inSection: 0, withAnimation: .none)
    createOdometerRowWithAnimation(.none)

    if animation == .none {
      tableView.reloadData()
    } else {
      tableView.reloadRows(at: [IndexPath(row: 3, section: 0)], with: animation)
    }
  }

  // MARK: - Locale Handling

  @objc func localeChanged(_: AnyObject) {
    let previousSelection = tableView.indexPathForSelectedRow

    dismissKeyboardWithCompletion {
      self.recreateTableContents()
      self.selectRowAtIndexPath(previousSelection)
    }
  }

  // MARK: - Cancel Button

  @IBAction func handleCancel(_: AnyObject) {
    previousSelectionIndex = tableView.indexPathForSelectedRow

    dismissKeyboardWithCompletion { self.handleCancelCompletion() }
  }

  private func handleCancelCompletion() {
    var showCancelSheet = true

    // In editing mode show alert panel on any change
    if editingExistingObject, !dataChanged {
      showCancelSheet = false
    }

    // In create mode show alert panel on textual changes
    if !editingExistingObject,
       name == "",
       plate == "",
       odometer!.isZero
    {
      showCancelSheet = false
    }

    if showCancelSheet {
      self.showCancelSheet()
    } else {
      delegate?.carConfigurationController(self, didFinishWithResult: .canceled)
    }
  }

  func showCancelSheet() {
    isShowingCancelSheet = true

    let alertController = UIAlertController(title: editingExistingObject ? NSLocalizedString("Revert Changes for Car?", comment: "") : NSLocalizedString("Delete the newly created car?", comment: ""),
                                            message: nil,
                                            preferredStyle: .actionSheet)
    let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
      self.isShowingCancelSheet = false
      self.selectRowAtIndexPath(self.previousSelectionIndex)
      self.previousSelectionIndex = nil
    }
    let destructiveAction = UIAlertAction(title: editingExistingObject ? NSLocalizedString("Revert", comment: "") : NSLocalizedString("Delete", comment: ""), style: .destructive) { _ in
      self.isShowingCancelSheet = false
      self.delegate?.carConfigurationController(self, didFinishWithResult: .canceled)
      self.previousSelectionIndex = nil
    }
    alertController.addAction(cancelAction)
    alertController.addAction(destructiveAction)
    alertController.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
    present(alertController, animated: true, completion: nil)
  }

  // MARK: - Save Button

  @IBAction func handleSave(_: AnyObject) {
    dismissKeyboardWithCompletion {
      self.delegate?.carConfigurationController(self, didFinishWithResult: self.editingExistingObject ? .editSucceeded : .createSucceeded)
    }
  }

  // MARK: - EditablePageCellFocusHandler

  func focusNextFieldForValueIdentifier(_ valueIdentifier: String) {
    if valueIdentifier == "name" {
      selectRowAtIndexPath(IndexPath(row: 1, section: 0))
    } else {
      selectRowAtIndexPath(IndexPath(row: 2, section: 0))
    }
  }

  // MARK: - EditablePageCellDelegate

  func valueForIdentifier(_ valueIdentifier: String) -> Any? {
    switch valueIdentifier {
    case "name": return name
    case "plate": return plate
    case "odometerUnit": return odometerUnit
    case "odometer": return odometer
    case "fuelUnit": return fuelUnit
    case "fuelConsumptionUnit": return fuelConsumptionUnit
    default: return nil
    }
  }

  func valueChanged(_ newValue: Any?, identifier valueIdentifier: String) {
    if let stringValue = newValue as? String {
      if valueIdentifier == "name" {
        name = stringValue
      } else if valueIdentifier == "plate" {
        plate = stringValue
      }
    } else if let decimalNumberValue = newValue as? Decimal {
      if valueIdentifier == "odometer" {
        odometer = decimalNumberValue
      }
    } else if let numberValue = newValue as? NSNumber {
      if valueIdentifier == "odometerUnit" {
        let oldUnit = UnitLength.fromPersistentId(odometerUnit!.int32Value)
        let newUnit = UnitLength.fromPersistentId(numberValue.int32Value)

        if oldUnit != newUnit {
          odometerUnit = numberValue
          odometer = Units.distanceForKilometers(Units.kilometersForDistance(odometer!, withUnit: oldUnit), withUnit: newUnit)

          recreateOdometerRowWithAnimation(newUnit == UnitLength.kilometers ? .left : .right)
        }
      } else if valueIdentifier == "fuelUnit" {
        fuelUnit = numberValue
      } else if valueIdentifier == "fuelConsumptionUnit" {
        fuelConsumptionUnit = numberValue
      }
    }

    dataChanged = true
  }

  // MARK: - UITableViewDelegate

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    activateCellAtIndexPath(indexPath)
    tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
  }

  override func tableView(_: UITableView, didDeselectRowAt indexPath: IndexPath) {
    deactivateCellAtIndexPath(indexPath)
  }
}
