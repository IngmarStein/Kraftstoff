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
		tableView.rowHeight = UITableView.automaticDimension
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)

		// this fixes a layout issue: the UITextFieldLabels contained in UITextFields are not correctly resized
		self.tableView.reloadData()
	}

	// MARK: - Dismissing the Keyboard

	func dismissKeyboardWithCompletion(_ completion: @escaping () -> Void) {
		let scrollToTop = self.tableView.contentOffset.y > 0.0

		UIViewPropertyAnimator.runningPropertyAnimator(withDuration: scrollToTop ? 0.25 : 0.15, delay: 0, options: [], animations: {
			if let indexPath = self.tableView.indexPathForSelectedRow {
				self.tableView.deselectRow(at: indexPath, animated: false)
				self.tableView.delegate?.tableView?(self.tableView, didDeselectRowAt: indexPath)
			}

			if scrollToTop {
				self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0),
										   at: .top,
										   animated: false)
			}
		}, completion: { _ in
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

	func dataForRow(_ rowIndex: Int, inSection sectionIndex: Int) -> [String: Any]? {
		return cellDescriptionForRow(rowIndex, inSection: sectionIndex)?.cellData
	}

	func setData(_ object: [String: Any], forRow rowIndex: Int, inSection sectionIndex: Int) {
		cellDescriptionForRow(rowIndex, inSection: sectionIndex)?.cellData = object

		let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
		if let cell = self.tableView.cellForRow(at: indexPath) as? PageCell {
			cell.configureForData(object, viewController: self, tableView: self.tableView, indexPath: indexPath)
		}
	}

	// MARK: - Access to Table Sections

	func addSectionAtIndex(_ idx: Int, withAnimation animation: UITableView.RowAnimation) {
		let sectionIndex: Int
		if idx > tableSections.count {
			sectionIndex = tableSections.count
		} else {
			sectionIndex = idx
		}

		tableSections.insert([PageCellDescription](), at: sectionIndex)

		if animation != .none {
			self.tableView.insertSections(IndexSet(integer: sectionIndex), with: animation)
		}
	}

	func removeSectionAtIndex(_ sectionIndex: Int, withAnimation animation: UITableView.RowAnimation) {
		if sectionIndex < tableSections.count {
			tableSections.remove(at: sectionIndex)

			if animation != .none {
				self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: animation)
			}
		}
	}

	func removeAllSectionsWithAnimation(_ animation: UITableView.RowAnimation) {
		tableSections.removeAll(keepingCapacity: false)

		if animation != .none {
			let allSections = IndexSet(integersIn: 0..<tableSections.count)
			self.tableView.deleteSections(allSections, with: animation)
		}
	}

	// MARK: - Access to Table Rows

	func addRowAtIndex(rowIndex rowIdx: Int, inSection sectionIdx: Int, cellClass: PageCell.Type, cellData: [String: Any], withAnimation animation: UITableView.RowAnimation) {
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
			let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
			self.tableView.insertRows(at: [indexPath], with: animation)
		}
	}

	func removeRow(at rowIndex: Int, inSection sectionIndex: Int, withAnimation animation: UITableView.RowAnimation) {
		if sectionIndex < tableSections.count {
			if rowIndex < tableSections[sectionIndex].count {
				tableSections[sectionIndex].remove(at: rowIndex)

				if animation != .none {
					let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
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

	override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
		return false
	}

	override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
		return .none
	}

	override func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
		return false
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let description = cellDescriptionForRow(indexPath.row, inSection: indexPath.section)!

		let cellClass = description.cellClass
		let cell = tableView.dequeueReusableCell(withIdentifier: description.cellClass.reuseIdentifier) as? PageCell ?? cellClass.init()

		cell.configureForData(description.cellData, viewController: self, tableView: tableView, indexPath: indexPath)

		return cell
	}

	override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		guard let pageCell = cell as? PageCell else { return }

		// https://www.fadel.io/blog/posts/ios-performance-tips-you-probably-didnt-know/
		pageCell.reset()
	}

	// MARK: - Programmatically Selecting Table Rows

	func activateCellAtIndexPath(_ indexPath: IndexPath) {
		let cell = self.tableView.cellForRow(at: indexPath)!
		if cell.canBecomeFirstResponder {
			DispatchQueue.main.async {
				cell.becomeFirstResponder()
				self.tableView.beginUpdates()
				self.tableView.endUpdates()
			}
		}
	}

	func deactivateCellAtIndexPath(_ indexPath: IndexPath) {
		let cell = self.tableView.cellForRow(at: indexPath)!
		if cell.canResignFirstResponder {
			DispatchQueue.main.async {
				cell.resignFirstResponder()
				self.tableView.beginUpdates()
				self.tableView.endUpdates()
			}
		}
	}

	func selectRowAtIndexPath(_ indexPath: IndexPath?) {
		if let path = indexPath {
			self.tableView.selectRow(at: path, animated: false, scrollPosition: .none)
			self.tableView(self.tableView, didSelectRowAt: path)
		}
	}

}
