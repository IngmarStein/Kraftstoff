//
//  PageCellDescription.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import Foundation

class PageCellDescription : NSObject {
	private(set) var cellClass: PageCell.Type
	var cellData: AnyObject

	init(cellClass: PageCell.Type, andData data: AnyObject) {
		self.cellClass = cellClass
		self.cellData = data
	}
}