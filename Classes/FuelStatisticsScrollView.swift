//
//  FuelStatisticsScrollView.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//  Scrollview that allows infinite circular scrolling through 3 or more pages

import UIKit

final class FuelStatisticsScrollView: UIScrollView {

    // Offset between logical and currently visible pages
	private var pageOffset = 0

	// Returns the logical page that is displayed in the currently visible actual page
	func pageForVisiblePage(visiblePage: Int) -> Int {
		let numberOfPages = Int(rint(self.contentSize.width / self.bounds.size.width))

		if numberOfPages > 0 {
			return (visiblePage + pageOffset + numberOfPages) % numberOfPages
		} else {
			return visiblePage
		}
	}

	// Returns the visible page that displays a given logical page
	func visiblePageForPage(page: Int) -> Int {
		let numberOfPages = Int(rint(self.contentSize.width / self.bounds.size.width))

		if numberOfPages > 0 {
			return (page - pageOffset + numberOfPages) % numberOfPages
		} else {
			return page
		}
	}

	// Updates the internal pageOffset between logical and visible pages such that such that the actual offset of the scrollview can be kept at the second page.
	private func recenterIfNecessary() {
		let currentOffset = self.contentOffset
		let contentWidth = self.contentSize.width
		let pageWidth = self.bounds.size.width
		let centerOffsetX = pageWidth
		let numOfPages = Int(rint(contentWidth / pageWidth))

		// Distance from center is large enough for recentering
		if fabs (currentOffset.x - centerOffsetX) >= pageWidth {

			// Constrain shifts to full page width
			let shiftDelta: CGFloat

			if currentOffset.x - centerOffsetX > 0 {
				shiftDelta = -pageWidth
				pageOffset += 1
			} else {
				shiftDelta = pageWidth
				pageOffset -= 1
			}

			// Keep pageOffset in sane region
			if pageOffset < 0 {
				pageOffset += numOfPages
			} else if pageOffset >= numOfPages {
				pageOffset %= numOfPages
			}

			// Recenter scrollview
			self.contentOffset = CGPoint(x:currentOffset.x + shiftDelta, y:currentOffset.y)

			// Move content by the same amount so it appears to stay still
			for view in self.subviews {
				var center = view.center

				center.x += shiftDelta

				// Wrap content around to get a circular scrolling
				if center.x < 0 {
					center.x += contentWidth
				} else if center.x > contentWidth {
					center.x -= contentWidth
				}

				view.center = center
			}
		}
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		recenterIfNecessary()
	}

}
