//
//  PageViewController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

class PageViewController: UITableViewController {

	var tableSections: [[PageCellDescription]] = []

	override func viewDidLoad() {
		super.viewDidLoad()

		tableView.allowsSelectionDuringEditing = true
		tableView.estimatedRowHeight = 44.0
		tableView.rowHeight = UITableViewAutomaticDimension
	}

	override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)

		// this fixes a layout issue: the UITextFieldLabels contained in UITextFields are not correctly resized
		self.tableView.reloadData()
	}

	//MARK: - Dismissing the Keyboard

	func dismissKeyboardWithCompletion(completion: () -> Void) {
		let scrollToTop = (self.tableView.contentOffset.y > 0.0)
    
		UIView.animateWithDuration(scrollToTop ? 0.25 : 0.15, animations: {
			if let indexPath = self.tableView.indexPathForSelectedRow {
				self.tableView.deselectRowAtIndexPath(indexPath, animated:false)
				self.tableView.delegate?.tableView?(self.tableView, didDeselectRowAtIndexPath: indexPath)
			}

			if scrollToTop {
				self.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow:0, inSection:0),
					atScrollPosition:.Top,
					animated:false)
			}
		}, completion: { finished in
			self.view.endEditing(true)
			completion()
		})
	}

	//MARK: - Access to Table Cells

	func cellDescriptionForRow(rowIndex: Int, inSection sectionIndex: Int) -> PageCellDescription? {
		if tableSections.count <= sectionIndex {
			return nil
		}

		let section = tableSections[sectionIndex]

		if section.count <= rowIndex {
			return nil
		}

		return section[rowIndex]
	}

	func classForRow(rowIndex: Int, inSection sectionIndex: Int) -> PageCell.Type? {
		return cellDescriptionForRow(rowIndex, inSection:sectionIndex)?.cellClass
	}

	func dataForRow(rowIndex: Int, inSection sectionIndex: Int) -> [NSObject:AnyObject]? {
		return cellDescriptionForRow(rowIndex, inSection:sectionIndex)?.cellData
	}

	func setData(object: [NSObject:AnyObject], forRow rowIndex: Int, inSection sectionIndex: Int) {
		cellDescriptionForRow(rowIndex, inSection:sectionIndex)?.cellData = object

		let indexPath = NSIndexPath(forRow:rowIndex, inSection:sectionIndex)
		let cell = self.tableView.cellForRowAtIndexPath(indexPath) as! PageCell

		cell.configureForData(object, viewController:self, tableView:self.tableView, indexPath:indexPath)
	}

	//MARK: - Access to Table Sections

	func addSectionAtIndex(idx: Int, withAnimation animation: UITableViewRowAnimation) {
		let sectionIndex: Int
		if idx > tableSections.count {
			sectionIndex = tableSections.count
		} else {
			sectionIndex = idx
		}

		tableSections.insert([PageCellDescription](), atIndex: sectionIndex)

		if animation != .None {
			self.tableView.insertSections(NSIndexSet(index:sectionIndex), withRowAnimation:animation)
		}
	}

	func removeSectionAtIndex(sectionIndex: Int, withAnimation animation: UITableViewRowAnimation) {
		if sectionIndex < tableSections.count {
			tableSections.removeAtIndex(sectionIndex)

			if animation != .None {
				self.tableView.deleteSections(NSIndexSet(index:sectionIndex), withRowAnimation:animation)
			}
		}
	}

	func removeAllSectionsWithAnimation(animation: UITableViewRowAnimation) {
		tableSections.removeAll(keepCapacity: false)

		if animation != .None {
			let allSections = NSIndexSet(indexesInRange:NSRange(location: 0, length: tableSections.count))
			self.tableView.deleteSections(allSections, withRowAnimation:animation)
		}
	}

	//MARK: - Access to Table Rows

	func addRowAtIndex(rowIndex rowIdx: Int, inSection sectionIdx: Int, cellClass: PageCell.Type, cellData: [NSObject:AnyObject], withAnimation animation: UITableViewRowAnimation) {
		// Get valid section index and section
		if tableSections.isEmpty {
			addSectionAtIndex(0, withAnimation:animation)
		}

		let sectionIndex: Int
		if sectionIdx > tableSections.count - 1 {
			sectionIndex = tableSections.count - 1
		} else {
			sectionIndex = sectionIdx
		}

		// Get valid row index
		let rowIndex: Int
		if rowIdx > tableSections[sectionIndex].count {
			rowIndex = tableSections[sectionIndex].count
		} else {
			rowIndex = rowIdx
		}

		// Store cell description
		let description = PageCellDescription(cellClass:cellClass, andData:cellData)
		tableSections[sectionIndex].insert(description, atIndex: rowIndex)

		if animation != .None {
			// If necessary update position for former bottom row of the section
			if self.tableView.style == .Grouped {
				if rowIndex == tableSections[sectionIndex].count - 1 && rowIndex > 0 {
					setData(dataForRow(rowIndex-1, inSection:sectionIndex)!,
						forRow:rowIndex-1,
						inSection:sectionIndex)
				}
			}

			// Add row to table
			let indexPath = NSIndexPath(forRow:rowIndex, inSection:sectionIndex)
			self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation:animation)
		}
	}

	func removeRowAtIndex(rowIndex: Int, inSection sectionIndex: Int, withAnimation animation: UITableViewRowAnimation) {
		if sectionIndex < tableSections.count {
			if rowIndex < tableSections[sectionIndex].count {
				tableSections[sectionIndex].removeAtIndex(rowIndex)

				if animation != .None {
					let indexPath = NSIndexPath(forRow:rowIndex, inSection:sectionIndex)
					self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation:animation)
				}
			}
		}
	}

	//MARK: - UITableViewDataSource

	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return tableSections.count
	}

	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return tableSections[section].count
	}

	override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return nil
	}

	override func tableView(tableView: UITableView, shouldIndentWhileEditingRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		return false
	}

	override func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
		return .None
	}

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let description = cellDescriptionForRow(indexPath.row, inSection:indexPath.section)!

		let cellClass = description.cellClass
		var cell = tableView.dequeueReusableCellWithIdentifier(description.cellClass.reuseIdentifier) as? PageCell

		if cell == nil {
			cell = cellClass.init()
		}

		cell!.configureForData(description.cellData, viewController:self, tableView:tableView, indexPath:indexPath)

		return cell!
	}
}
