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

	// Disable Cut&Paste functionality to properly handle special text inputs methods for our textfields
	override func canPerformAction(action: Selector, withSender sender: AnyObject?) -> Bool {
		if action == "cut:" && !self.allowCut {
			return false
		}

		if action == "paste:" && !self.allowPaste {
			return false
		}

		return super.canPerformAction(action, withSender:sender)
	}
}
