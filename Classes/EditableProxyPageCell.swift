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
		self.textFieldProxy = UILabel(frame:CGRectZero)

		super.init()

		self.textFieldProxy.textAlignment          = .Right
		self.textFieldProxy.backgroundColor        = UIColor.clearColor()
		self.textFieldProxy.userInteractionEnabled = false
		self.textFieldProxy.isAccessibilityElement = false
		self.textFieldProxy.setTranslatesAutoresizingMaskIntoConstraints(false)

		self.contentView.addSubview(self.textFieldProxy)

		self.contentView.addConstraint(NSLayoutConstraint(item: textFieldProxy, attribute: .Left, relatedBy: .Equal, toItem: textField, attribute: .Left, multiplier: 1.0, constant: 0.0))
		self.contentView.addConstraint(NSLayoutConstraint(item: textFieldProxy, attribute: .Right, relatedBy: .Equal, toItem: textField, attribute: .Right, multiplier: 1.0, constant: 0.0))
		self.contentView.addConstraint(NSLayoutConstraint(item: textFieldProxy, attribute: .Top, relatedBy: .Equal, toItem: textField, attribute: .Top, multiplier: 1.0, constant: 0.0))
		self.contentView.addConstraint(NSLayoutConstraint(item: textFieldProxy, attribute: .Bottom, relatedBy: .Equal, toItem: textField, attribute: .Bottom, multiplier: 1.0, constant: 0.0))

		// Hide the textfield used for keyboard interaction
		self.textField.hidden = true
		self.textField.inputView = UIView() // hide keyboard
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func setupFonts() {
		super.setupFonts()

		self.textFieldProxy.font = self.textField.font
	}

	override var accessibilityLabel: String! {
		get {
			if let text1 = self.keyLabel.text, text2 = self.textFieldProxy.text {
				return "\(text1) \(text2)"
			}
			return nil
		}
		set {
		}
	}
}
