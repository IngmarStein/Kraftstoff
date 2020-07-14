//
//  EditableProxyPageCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

class EditableProxyPageCell: EditablePageCell {

  var textFieldProxy: UILabel

  required init() {
    // Create a proxy overlay for the textfield that is used to display the textField contents
    // without a flashing cursor and no cut & paste possibilities
    textFieldProxy = UILabel(frame: .zero)

    super.init()

    textFieldProxy.textAlignment            = .right
    textFieldProxy.backgroundColor          = .clear
    textFieldProxy.isUserInteractionEnabled = false
    textFieldProxy.isAccessibilityElement   = false
    textFieldProxy.translatesAutoresizingMaskIntoConstraints = false
    textFieldProxy.adjustsFontForContentSizeCategory = true
    textFieldProxy.font = self.textField.font

    self.contentView.addSubview(self.textFieldProxy)

    let constraints = [
      NSLayoutConstraint(item: textFieldProxy, attribute: .left, relatedBy: .equal, toItem: textField, attribute: .left, multiplier: 1.0, constant: 0.0),
      NSLayoutConstraint(item: textFieldProxy, attribute: .right, relatedBy: .equal, toItem: textField, attribute: .right, multiplier: 1.0, constant: 0.0),
      NSLayoutConstraint(item: textFieldProxy, attribute: .top, relatedBy: .equal, toItem: textField, attribute: .top, multiplier: 1.0, constant: 0.0),
      NSLayoutConstraint(item: textFieldProxy, attribute: .bottom, relatedBy: .equal, toItem: textField, attribute: .bottom, multiplier: 1.0, constant: 0.0)
    ]
    NSLayoutConstraint.activate(constraints)

    // Hide the textfield used for keyboard interaction
    textField.isHidden = true
    textField.inputView = UIView() // hide keyboard
  }

  required init(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
  }

  override var accessibilityLabel: String? {
    get {
      if let text1 = self.keyLabel.text, let text2 = self.textFieldProxy.text {
        return "\(text1) \(text2)"
      }
      return nil
    }
    set {
    }
  }

  override func reset() {
    super.reset()

    textFieldProxy.text = ""
  }

}
