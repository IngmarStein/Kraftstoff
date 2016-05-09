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

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)

		// this fixes a layout issue: the UITextFieldLabels contained in UITextFields are not correctly resized
		self.tableView.reloadData()
	}

	// MARK: - Dismissing the Keyboard

	func dismissKeyboardWithCompletion(completion: () -> Void) {
		let scrollToTop = self.tableView.contentOffset.y > 0.0

		UIView.animate(withDuration: scrollToTop ? 0.25 : 0.15, animations: {
			if let indexPath = self.tableView.indexPathForSelectedRow {
				self.tableView.deselectRow(at: indexPath, animated: false)
				self.tableView.delegate?.tableView?(self.tableView, didDeselectRowAt: indexPath)
			}

			if scrollToTop {
				self.tableView.scrollToRow(at: NSIndexPath(forRow: 0, inSection: 0),
					at: .top,
					animated: false)
			}
		}, completion: { finished in
			self.view.endEditing(true)
			completion()
		})
	}

	// MARK: - Access to Table Cells

	func cellDescriptionForRow(_ rowIndex: Int, inSection sectionIndex: Int) -> PageCellDescription? {
		if tableSections.count <= sectionIndex {
			return nil
		}

		let section = tableSections[sectionIndex]

		if section.count <= rowIndex {
			return nil
		}

		return section[rowIndex]
	}

	func classForRow(_ rowIndex: Int, inSection sectionIndex: Int) -> PageCell.Type? {
		return cellDescriptionForRow(rowIndex, inSection: sectionIndex)?.cellClass
	}

	func dataForRow(_ rowIndex: Int, inSection sectionIndex: Int) -> [NSObject: AnyObject]? {
		return cellDescriptionForRow(rowIndex, inSection: sectionIndex)?.cellData
	}

	func setData(_ object: [NSObject: AnyObject], forRow rowIndex: Int, inSection sectionIndex: Int) {
		cellDescriptionForRow(rowIndex, inSection: sectionIndex)?.cellData = object

		let indexPath = NSIndexPath(forRow: rowIndex, inSection: sectionIndex)
		let cell = self.tableView.cellForRow(at: indexPath) as! PageCell

		cell.configureForData(object, viewController: self, tableView: self.tableView, indexPath: indexPath)
	}

	// MARK: - Access to Table Sections

	func addSectionAtIndex(_ idx: Int, withAnimation animation: UITableViewRowAnimation) {
		let sectionIndex: Int
		if idx > tableSections.count {
			sectionIndex = tableSections.count
		} else {
			sectionIndex = idx
		}

		tableSections.insert([PageCellDescription](), at: sectionIndex)

		if animation != .none {
			self.tableView.insertSections(NSIndexSet(index: sectionIndex), with: animation)
		}
	}

	func removeSectionAtIndex(_ sectionIndex: Int, withAnimation animation: UITableViewRowAnimation) {
		if sectionIndex < tableSections.count {
			tableSections.remove(at: sectionIndex)

			if animation != .none {
				self.tableView.deleteSections(NSIndexSet(index: sectionIndex), with: animation)
			}
		}
	}

	func removeAllSectionsWithAnimation(_ animation: UITableViewRowAnimation) {
		tableSections.removeAll(keepingCapacity: false)

		if animation != .none {
			let allSections = NSIndexSet(indexesIn: NSRange(location: 0, length: tableSections.count))
			self.tableView.deleteSections(allSections, with: animation)
		}
	}

	// MARK: - Access to Table Rows

	func addRowAtIndex(rowIndex rowIdx: Int, inSection sectionIdx: Int, cellClass: PageCell.Type, cellData: [NSObject: AnyObject], withAnimation animation: UITableViewRowAnimation) {
		// Get valid section index and section
		if tableSections.isEmpty {
			addSectionAtIndex(0, withAnimation: animation)
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
		let description = PageCellDescription(cellClass: cellClass, andData: cellData)
		tableSections[sectionIndex].insert(description, at: rowIndex)

		if animation != .none {
			// If necessary update position for former bottom row of the section
			if self.tableView.style == .grouped {
				if rowIndex == tableSections[sectionIndex].count - 1 && rowIndex > 0 {
					setData(dataForRow(rowIndex-1,
						inSection: sectionIndex)!,
						forRow: rowIndex-1,
						inSection: sectionIndex)
				}
			}

			// Add row to table
			let indexPath = NSIndexPath(forRow: rowIndex, inSection: sectionIndex)
			self.tableView.insertRows(at: [indexPath], with: animation)
		}
	}

	func removeRow(at rowIndex: Int, inSection sectionIndex: Int, withAnimation animation: UITableViewRowAnimation) {
		if sectionIndex < tableSections.count {
			if rowIndex < tableSections[sectionIndex].count {
				tableSections[sectionIndex].remove(at: rowIndex)

				if animation != .none {
					let indexPath = NSIndexPath(forRow: rowIndex, inSection: sectionIndex)
					self.tableView.deleteRows(at: [indexPath], with: animation)
				}
			}
		}
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return tableSections.count
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return tableSections[section].count
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return nil
	}

	override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: NSIndexPath) -> Bool {
		return false
	}

	override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
		return .none
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: NSIndexPath) -> UITableViewCell {
		let description = cellDescriptionForRow(indexPath.row, inSection: indexPath.section)!

		let cellClass = description.cellClass
		let cell = tableView.dequeueReusableCell(withIdentifier: description.cellClass.reuseIdentifier) as? PageCell ?? cellClass.init()

		cell.configureForData(description.cellData, viewController: self, tableView: tableView, indexPath: indexPath)

		return cell
	}

}
