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
		textFieldProxy = UILabel(frame: CGRect.zero)

		super.init()

		textFieldProxy.textAlignment          = .right
		textFieldProxy.backgroundColor        = UIColor.clear()
		textFieldProxy.isUserInteractionEnabled = false
		textFieldProxy.isAccessibilityElement = false
		textFieldProxy.translatesAutoresizingMaskIntoConstraints = false

		self.contentView.addSubview(self.textFieldProxy)

		self.contentView.addConstraint(NSLayoutConstraint(item: textFieldProxy, attribute: .left, relatedBy: .equal, toItem: textField, attribute: .left, multiplier: 1.0, constant: 0.0))
		self.contentView.addConstraint(NSLayoutConstraint(item: textFieldProxy, attribute: .right, relatedBy: .equal, toItem: textField, attribute: .right, multiplier: 1.0, constant: 0.0))
		self.contentView.addConstraint(NSLayoutConstraint(item: textFieldProxy, attribute: .top, relatedBy: .equal, toItem: textField, attribute: .top, multiplier: 1.0, constant: 0.0))
		self.contentView.addConstraint(NSLayoutConstraint(item: textFieldProxy, attribute: .bottom, relatedBy: .equal, toItem: textField, attribute: .bottom, multiplier: 1.0, constant: 0.0))

		// Hide the textfield used for keyboard interaction
		textField.isHidden = true
		textField.inputView = UIView() // hide keyboard
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override func setupFonts() {
		super.setupFonts()

		self.textFieldProxy.font = self.textField.font
	}

	override var accessibilityLabel: String? {
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
