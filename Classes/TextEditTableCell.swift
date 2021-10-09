//
//  TextEditTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

final class TextEditTableCell: EditablePageCell {
  static let DefaultMaximumTextFieldLength = 15

  private var maximumTextFieldLength = 0

  required init() {
    super.init()

    textField.keyboardType = .default
    textField.returnKeyType = .next
    textField.allowCut = true
    textField.allowPaste = true
  }

  @available(*, unavailable)
  required init(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
    super.configureForData(dictionary, viewController: viewController, tableView: tableView, indexPath: indexPath)

    if let autocapitalizeAll = dictionary["autocapitalizeAll"] as? Bool, autocapitalizeAll {
      textField.autocapitalizationType = .allCharacters
    } else {
      textField.autocapitalizationType = .words
    }
    if let maximumTextFieldLength = dictionary["maximumTextFieldLength"] as? Int {
      self.maximumTextFieldLength = maximumTextFieldLength
    } else {
      maximumTextFieldLength = TextEditTableCell.DefaultMaximumTextFieldLength
    }

    textField.text = delegate.valueForIdentifier(valueIdentifier) as? String
    textField.accessibilityIdentifier = valueIdentifier
  }

  // MARK: - UITextFieldDelegate

  override func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    // Let the focus handler handle switching to next textfield
    if let focusHandler = delegate as? EditablePageCellFocusHandler {
      focusHandler.focusNextFieldForValueIdentifier(valueIdentifier)
    } else {
      return super.textFieldShouldReturn(textField)
    }

    return false
  }

  func textFieldShouldClear(_: UITextField) -> Bool {
    // Propagate cleared value to the delegate
    delegate.valueChanged("", identifier: valueIdentifier)

    return true
  }

  @objc(textField:shouldChangeCharactersInRange:replacementString:)
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    guard let editRange = Range(range, in: textField.text!) else { return false }
    var newValue = textField.text!.replacingCharacters(in: editRange, with: string)

    // Don't allow too large strings
    if maximumTextFieldLength > 0, newValue.count > maximumTextFieldLength {
      return false
    }

    if textField.textAlignment == .right {
      // http://stackoverflow.com/questions/19569688/right-aligned-uitextfield-spacebar-does-not-advance-cursor-in-ios-7
      newValue = newValue.replacingOccurrences(of: " ", with: "\u{00a0}")
    }

    // Do the update here and propagate the new value back to the delegate
    textField.text = newValue

    delegate.valueChanged(newValue, identifier: valueIdentifier)

    return false
  }

  override func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
    super.textFieldDidEndEditing(textField, reason: reason)

    textField.text = textField.text?.replacingOccurrences(of: "\u{00a0}", with: " ")
  }
}
