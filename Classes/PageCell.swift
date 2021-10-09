//
//  PageCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

class PageCell: UITableViewCell {
  class var reuseIdentifier: String {
    String(describing: self)
  }

  required init() {
    super.init(style: .default, reuseIdentifier: type(of: self).reuseIdentifier)

    detailTextLabel?.isHidden = true
  }

  @available(*, unavailable)
  required init(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configureForData(_: [String: Any], viewController _: UIViewController, tableView _: UITableView, indexPath _: IndexPath) {
    // Overridepoint for subclasses
  }

  func reset() {}
}
