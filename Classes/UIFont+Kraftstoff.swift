//
//  UIFont+Kraftstoff.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 13.05.15.
//
//

import UIKit

private let textStyleSize: [String:CGFloat] = [
	UIFontTextStyleFootnote: 12.0,
	UIFontTextStyleBody: 15.0,
	UIFontTextStyleCaption2: 17.0,
	UIFontTextStyleCaption1: 20.0,
	UIFontTextStyleSubheadline: 22.0,
	UIFontTextStyleHeadline: 28.0
]

private let contentSizeDelta: [String:CGFloat] = [
	UIContentSizeCategoryAccessibilityExtraExtraExtraLarge: 8,
	UIContentSizeCategoryAccessibilityExtraExtraLarge: 7,
	UIContentSizeCategoryAccessibilityExtraLarge: 6,
	UIContentSizeCategoryAccessibilityLarge: 5,
	UIContentSizeCategoryAccessibilityMedium: 4,
	UIContentSizeCategoryExtraExtraExtraLarge: 3,
	UIContentSizeCategoryExtraExtraLarge: 2,
	UIContentSizeCategoryExtraLarge: 1,
	UIContentSizeCategoryLarge: 0,
	UIContentSizeCategoryMedium: -1,
	UIContentSizeCategorySmall: -2,
	UIContentSizeCategoryExtraSmall: -3
]

extension UIFont {
	private static func applicationFontForStyle(textStyle: String, weight: CGFloat) -> UIFont {
		let baseSize = textStyleSize[textStyle] ?? 0.0
		let contentSize = UIApplication.sharedApplication().preferredContentSizeCategory
		let sizeDelta = contentSizeDelta[contentSize] ?? 0.0
		let fontSize = baseSize + sizeDelta
		return UIFont.systemFontOfSize(fontSize, weight: weight)
	}

	static func lightApplicationFontForStyle(textStyle: String) -> UIFont {
		return applicationFontForStyle(textStyle, weight: UIFontWeightLight)
	}

	static func applicationFontForStyle(textStyle: String) -> UIFont {
		return applicationFontForStyle(textStyle, weight: UIFontWeightRegular)
	}

	static func boldApplicationFontForStyle(textStyle: String) -> UIFont {
		return applicationFontForStyle(textStyle, weight: UIFontWeightBold)
	}
}
