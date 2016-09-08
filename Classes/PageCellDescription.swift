//
//  PageCellDescription.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import Foundation

final class PageCellDescription {
	private(set) var cellClass: PageCell.Type
	var cellData: [String: Any]

	init(cellClass: PageCell.Type, andData data: [String: Any]) {
		self.cellClass = cellClass
		self.cellData = data
	}

}
