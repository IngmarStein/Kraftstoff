//
//  PageCellDescription.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import Foundation

class PageCellDescription {
	private(set) var cellClass: PageCell.Type
	var cellData: [NSObject:AnyObject]

	init(cellClass: PageCell.Type, andData data: [NSObject:AnyObject]) {
		self.cellClass = cellClass
		self.cellData = data
	}
}