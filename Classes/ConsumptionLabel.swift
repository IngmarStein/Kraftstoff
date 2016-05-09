//
//  ConsumptionLabel.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 30.04.15.
//
//

import UIKit

final class ConsumptionLabel: UILabel {

	var highlightStrings: [String]? {
		didSet {
			computeHighlights()
		}
	}

	override var text: String? {
		didSet {
			computeHighlights()
		}
	}

	private func computeHighlights() {
		if let text = text, highlightStrings = highlightStrings, highlightedTextColor = highlightedTextColor {
			let highlightAttributes = [ NSForegroundColorAttributeName: highlightedTextColor ]

			let attributedString = NSMutableAttributedString(string: text)
			attributedString.beginEditing()
			for subString in highlightStrings {
				let range = (text as NSString).range(of: subString)

				if range.location != NSNotFound {
					// Match in highlight colors
					attributedString.setAttributes(highlightAttributes, range: range)
				}
			}
			attributedString.endEditing()

			self.attributedText = attributedString
		}
	}

}
