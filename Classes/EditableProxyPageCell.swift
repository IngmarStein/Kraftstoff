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

	override init() {
		// Create a proxy overlay for the textfield that is used to display the textField contents
		// without a flashing cursor and no Cut&Paste possibilities
		self.textFieldProxy = UILabel(frame:CGRectZero)

		super.init()

		self.textFieldProxy.font                   = self.textField.font
		self.textFieldProxy.textAlignment          = .Right
		self.textFieldProxy.backgroundColor        = UIColor.clearColor()
		self.textFieldProxy.autoresizingMask       = .FlexibleWidth
		self.textFieldProxy.userInteractionEnabled = false
		self.textFieldProxy.isAccessibilityElement = false

		self.contentView.addSubview(self.textFieldProxy)

		// Hide the textfield used for keyboard interaction
		self.textField.hidden = true
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func layoutSubviews() {
		super.layoutSubviews()

		self.textFieldProxy.frame = self.textField.frame
	}

	override var accessibilityLabel: String! {
		get {
			if let text1 = self.textLabel?.text, text2 = self.textFieldProxy.text {
				return String(format:"%@ %@", text1, text2)
			}
			return nil
		}
		set {
		}
	}
}
