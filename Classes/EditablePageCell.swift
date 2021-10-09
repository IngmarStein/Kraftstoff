//
//  EditablePageCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

protocol EditablePageCellDelegate: AnyObject {
  func valueForIdentifier(_ valueIdentifier: String) -> Any?
  func valueChanged(_ newValue: Any?, identifier: String)
}

protocol EditablePageCellValidator {
  func valueValid(_ newValue: Any?, identifier: String) -> Bool
}

protocol EditablePageCellFocusHandler {
  func focusNextFieldForValueIdentifier(_ valueIdentifier: String)
}

class EditablePageCell: PageCell, UITextFieldDelegate {
  private let margin = CGFloat(8.0)

  var keyLabel: UILabel
  var textField: EditablePageCellTextField
  var valueIdentifier: String!

  weak var delegate: EditablePageCellDelegate!

  required init() {
    // Create textfield
    textField = EditablePageCellTextField(frame: .zero)
    keyLabel = UILabel(frame: .zero)

    super.init()

    textField.textAlignment = .right
    textField.autocapitalizationType = .none
    textField.autocorrectionType = .no
    textField.backgroundColor = .clear
    textField.clearButtonMode = .whileEditing
    textField.contentVerticalAlignment = .center
    textField.isUserInteractionEnabled = false
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
    textField.adjustsFontForContentSizeCategory = true

    contentView.addSubview(textField)

    keyLabel.textAlignment = .left
    keyLabel.highlightedTextColor = .label
    keyLabel.textColor = .label
    keyLabel.setContentHuggingPriority(UILayoutPriority(rawValue: 750), for: .horizontal)
    keyLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1000), for: .horizontal)
    keyLabel.translatesAutoresizingMaskIntoConstraints = false
    keyLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
    keyLabel.adjustsFontForContentSizeCategory = true

    contentView.addSubview(keyLabel)

    let keyLabelBottomConstraint = NSLayoutConstraint(item: keyLabel, attribute: .bottom, relatedBy: .equal, toItem: contentView, attribute: .bottomMargin, multiplier: 1.0, constant: 0.0)
    keyLabelBottomConstraint.priority = UILayoutPriority(rawValue: 500)

    let constraints = [
      NSLayoutConstraint(item: keyLabel, attribute: .top, relatedBy: .equal, toItem: contentView, attribute: .topMargin, multiplier: 1.0, constant: 0.0),
      keyLabelBottomConstraint,
      NSLayoutConstraint(item: textField, attribute: .lastBaseline, relatedBy: .equal, toItem: keyLabel, attribute: .lastBaseline, multiplier: 1.0, constant: 0.0),
    ] + NSLayoutConstraint.constraints(withVisualFormat: "|-[keyLabel]-[textField]-|", options: [], metrics: nil, views: ["keyLabel": keyLabel, "textField": textField])

    NSLayoutConstraint.activate(constraints)
  }

  @available(*, unavailable)
  required init(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var accessibilityLabel: String? {
    get {
      "\(self.keyLabel.text!) \(self.textField.text!)"
    }
    set {}
  }

  override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
    super.configureForData(dictionary, viewController: viewController, tableView: tableView, indexPath: indexPath)

    keyLabel.text = dictionary["label"] as? String
    delegate = viewController as? EditablePageCellDelegate
    valueIdentifier = dictionary["valueIdentifier"] as? String

    textField.placeholder = dictionary["placeholder"] as? String
    textField.delegate = self
  }

  var invalidTextColor: UIColor? {
    contentView.tintColor
  }

  // MARK: - UITextFieldDelegate

  func textFieldDidEndEditing(_ textField: UITextField, reason _: UITextField.DidEndEditingReason) {
    textField.isUserInteractionEnabled = false
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()

    return false
  }

  // MARK: - Responder Chain

  override var canBecomeFirstResponder: Bool {
    true
  }

  override var canResignFirstResponder: Bool {
    true
  }

  override func becomeFirstResponder() -> Bool {
    textField.isUserInteractionEnabled = true
    return textField.becomeFirstResponder()
  }

  override func resignFirstResponder() -> Bool {
    textField.resignFirstResponder()
  }

  override func reset() {
    super.reset()

    keyLabel.text = ""
  }
}
