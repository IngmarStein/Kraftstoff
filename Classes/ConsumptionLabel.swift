//
//  ConsumptionLabel.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 30.04.15.
//
//

import UIKit

final class ConsumptionLabel: UILabel {

  // Can't use UILabel.textColor because that property is linked to the attributed text.
  var baseColor = UIColor.black

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
    if let text = text, let highlightStrings = highlightStrings, let highlightedTextColor = highlightedTextColor {
      let highlightAttributes = [ NSAttributedString.Key.foregroundColor: highlightedTextColor ]

      let attributedString = NSMutableAttributedString(string: text)
      attributedString.beginEditing()
      attributedString.addAttribute(.foregroundColor, value: baseColor, range: NSRange(location: 0, length: text.count))
      for subString in highlightStrings {
        let range = (text as NSString).range(of: subString)

        if range.location != NSNotFound {
          // Match in highlight colors
          attributedString.setAttributes(highlightAttributes, range: range)
        }
      }
      attributedString.endEditing()

      self.attributedText = attributedString // setting this changes textColor
    }
  }

}
