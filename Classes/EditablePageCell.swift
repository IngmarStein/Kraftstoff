//
//  EditablePageCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

protocol EditablePageCellDelegate : class {
	func valueForIdentifier(_ valueIdentifier: String) -> Any?
	func valueChanged(_ newValue: AnyObject?, identifier: String)
}

protocol EditablePageCellValidator {
	func valueValid(_ newValue: AnyObject?, identifier: String) -> Bool
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

		textField.textAlignment            = .right
		textField.autocapitalizationType   = .none
		textField.autocorrectionType       = .no
		textField.backgroundColor          = .clear()
		textField.clearButtonMode          = .whileEditing
		textField.contentVerticalAlignment = .center
		textField.isUserInteractionEnabled = false
		textField.translatesAutoresizingMaskIntoConstraints = false

		self.contentView.addSubview(textField)

		keyLabel.textAlignment        = .left
		keyLabel.highlightedTextColor = .black()
		keyLabel.textColor            = .black()
		keyLabel.setContentHuggingPriority(750, for: .horizontal)
		keyLabel.setContentCompressionResistancePriority(1000, for: .horizontal)
		keyLabel.translatesAutoresizingMaskIntoConstraints = false

		self.contentView.addSubview(keyLabel)

		let keyLabelBottomConstraint = NSLayoutConstraint(item: keyLabel, attribute: .bottom, relatedBy: .equal, toItem: contentView, attribute: .bottomMargin, multiplier: 1.0, constant: 0.0)
		keyLabelBottomConstraint.priority = 500
		self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[keyLabel]-[textField]-|", options: [], metrics: nil, views: ["keyLabel" : keyLabel, "textField" : textField]))
		self.contentView.addConstraint(NSLayoutConstraint(item: keyLabel, attribute: .top, relatedBy: .equal, toItem: contentView, attribute: .topMargin, multiplier: 1.0, constant: 0.0))
		self.contentView.addConstraint(keyLabelBottomConstraint)
		self.contentView.addConstraint(NSLayoutConstraint(item: textField, attribute: .lastBaseline, relatedBy: .equal, toItem: keyLabel, attribute: .lastBaseline, multiplier: 1.0, constant: 0.0))

		setupFonts()
		NotificationCenter.default().addObserver(self, selector: #selector(EditablePageCell.contentSizeCategoryDidChange(notification:)), name: Notification.Name.UIContentSizeCategoryDidChange, object: nil)
	}

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	deinit {
		NotificationCenter.default().removeObserver(self)
	}

	func contentSizeCategoryDidChange(notification: NSNotification!) {
		setupFonts()
	}

	func setupFonts() {
		self.textField.font = UIFont.lightApplicationFontForStyle(UIFontTextStyleCaption2)
		self.keyLabel.font = UIFont.applicationFontForStyle(UIFontTextStyleCaption2)
	}

	override var accessibilityLabel: String? {
		get {
			return "\(self.keyLabel.text!) \(self.textField.text!)"
		}
		set {

		}
	}

	override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
		super.configureForData(dictionary, viewController:viewController, tableView: tableView, indexPath: indexPath)

		self.keyLabel.text   = dictionary["label"] as? String
		self.delegate        = viewController as? EditablePageCellDelegate
		self.valueIdentifier = dictionary["valueIdentifier"] as! String

		self.textField.placeholder = dictionary["placeholder"] as? String
		self.textField.delegate    = self
	}

	var invalidTextColor: UIColor? {
		return UIApplication.shared().delegate!.window!!.tintColor
	}

	// MARK: - UITextFieldDelegate

	func textFieldDidEndEditing(_ textField: UITextField) {
		textField.isUserInteractionEnabled = false
	}
}
