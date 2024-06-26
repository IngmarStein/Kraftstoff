//
//  EditablePageCellTextField.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

class EditablePageCellTextField: UITextField {
  var allowCut = false
  var allowPaste = false

  // Disable cut & paste functionality to properly handle special text inputs methods for our textfields
  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == #selector(UIResponderStandardEditActions.cut(_:)), !allowCut {
      return false
    }

    if action == #selector(UIResponderStandardEditActions.paste(_:)), !allowPaste {
      return false
    }

    return super.canPerformAction(action, withSender: sender)
  }
}
