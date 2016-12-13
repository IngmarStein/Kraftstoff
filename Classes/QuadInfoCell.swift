//
//  QuadInfoCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
// TableView cells with four labels for information.

import UIKit

final class QuadInfoCell: UITableViewCell {

	private(set) var topLeftLabel: UILabel
	private(set) var botLeftLabel: UILabel
	private(set) var topRightLabel: UILabel
	private(set) var botRightLabel: UILabel

	var topLeftAccessibilityLabel: String?
	var botLeftAccessibilityLabel: String?
	var topRightAccessibilityLabel: String?
	var botRightAccessibilityLabel: String?

	private var cellState: UITableViewCellStateMask
	var large = false {
		didSet {
			topRightLabel.font = UIFont.preferredFont(forTextStyle: large ? .title1 : .title2)
		}
	}

	private func setupSubviews() {
		topLeftLabel.backgroundColor            = .clear
		topLeftLabel.textColor                  = .black
		topLeftLabel.adjustsFontSizeToFitWidth  = true
		topLeftLabel.translatesAutoresizingMaskIntoConstraints = false
		topLeftLabel.adjustsFontForContentSizeCategory = true
		topLeftLabel.font = UIFont.preferredFont(forTextStyle: .title1)
		contentView.addSubview(topLeftLabel)

		botLeftLabel.backgroundColor            = .clear
		botLeftLabel.textColor                  = #colorLiteral(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
		botLeftLabel.adjustsFontSizeToFitWidth  = true
		botLeftLabel.translatesAutoresizingMaskIntoConstraints = false
		botLeftLabel.adjustsFontForContentSizeCategory = true
		botLeftLabel.font = UIFont.preferredFont(forTextStyle: .body)
		contentView.addSubview(botLeftLabel)

		topRightLabel.backgroundColor           = .clear
		topRightLabel.textColor                 = .black
		topRightLabel.adjustsFontSizeToFitWidth = true
		topRightLabel.textAlignment             = .right
		topRightLabel.translatesAutoresizingMaskIntoConstraints = false
		topRightLabel.adjustsFontForContentSizeCategory = true
		topRightLabel.font = UIFont.preferredFont(forTextStyle: large ? .title1 : .title2)
		contentView.addSubview(topRightLabel)

		botRightLabel.backgroundColor           = .clear
		botRightLabel.textColor                 = #colorLiteral(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
		botRightLabel.adjustsFontSizeToFitWidth = true
		botRightLabel.textAlignment             = .right
		botRightLabel.translatesAutoresizingMaskIntoConstraints = false
		botRightLabel.adjustsFontForContentSizeCategory = true
		botRightLabel.font = UIFont.preferredFont(forTextStyle: .body)
		contentView.addSubview(botRightLabel)

		// setup constraints
		let views = ["topLeftLabel": topLeftLabel, "botLeftLabel": botLeftLabel, "topRightLabel": topRightLabel, "botRightLabel": botRightLabel]

		let constraints1 = [
			NSLayoutConstraint(item: topLeftLabel, attribute: .lastBaseline, relatedBy: .equal, toItem: topRightLabel, attribute: .lastBaseline, multiplier: 1.0, constant: 0.0),
			NSLayoutConstraint(item: botLeftLabel, attribute: .lastBaseline, relatedBy: .equal, toItem: botRightLabel, attribute: .lastBaseline, multiplier: 1.0, constant: 0.0),
			NSLayoutConstraint(item: topLeftLabel, attribute: .left, relatedBy: .equal, toItem: botLeftLabel, attribute: .left, multiplier: 1.0, constant: 0.0),
			NSLayoutConstraint(item: topRightLabel, attribute: .right, relatedBy: .equal, toItem: botRightLabel, attribute: .right, multiplier: 1.0, constant: 0.0)
		]
		let constraints = constraints1
			+ NSLayoutConstraint.constraints(withVisualFormat: "V:|-(20)-[topLeftLabel]-(2)-[botLeftLabel]-(20)-|", options: [], metrics: nil, views: views)
			+ NSLayoutConstraint.constraints(withVisualFormat: "H:|-(15)-[topLeftLabel]-(2)-[topRightLabel]-(15)-|", options: [], metrics: nil, views: views)
		NSLayoutConstraint.activate(constraints)

		self.accessoryType = .disclosureIndicator
	}

	override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
		cellState     = []
		botLeftLabel  = UILabel(frame: .zero)
		topLeftLabel  = UILabel(frame: .zero)
		topRightLabel = UILabel(frame: .zero)
		botRightLabel = UILabel(frame: .zero)

		super.init(style: style, reuseIdentifier: reuseIdentifier)

		setupSubviews()
    }

	required init?(coder aDecoder: NSCoder) {
		cellState     = []
		botLeftLabel  = UILabel(frame: .zero)
		topLeftLabel  = UILabel(frame: .zero)
		topRightLabel = UILabel(frame: .zero)
		botRightLabel = UILabel(frame: .zero)

		super.init(coder: aDecoder)

		setupSubviews()
	}

	override var accessibilityLabel: String? {
		get {
			var label = "\((topLeftAccessibilityLabel ?? topLeftLabel.text) ?? ""), \((botLeftAccessibilityLabel ?? botLeftLabel.text) ?? ""))"
			if cellState == [] {
				if let accessibilityLabel = topRightAccessibilityLabel {
					label = "\(label), \(accessibilityLabel)"
				}

				if let accessibilityLabel = botRightAccessibilityLabel {
					label = "\(label) \(accessibilityLabel)"
				}
			}

			return label
		}
		set {
		}
	}

	// Remember target state for transition
	override func willTransition(to state: UITableViewCellStateMask) {
		super.willTransition(to: state)
		cellState = state
	}

	// Reset to default state before reuse of cell
	override func prepareForReuse() {
		super.prepareForReuse()
		cellState = []
	}

	override func layoutSubviews() {
		super.layoutSubviews()

		// hide right labels in editing modes
		UIView.animate(withDuration: 0.5) {
			let newAlpha: CGFloat = self.cellState.contains(.showingEditControlMask) ? 0.0 : 1.0
			self.topRightLabel.alpha = newAlpha
			self.botRightLabel.alpha = newAlpha
		}
	}

}
