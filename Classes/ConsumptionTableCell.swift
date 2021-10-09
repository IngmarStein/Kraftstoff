//
//  ConsumptionTableCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
//

import UIKit

final class ConsumptionTableCell: PageCell {
  private(set) var coloredLabel: ConsumptionLabel

  required init() {
    coloredLabel = ConsumptionLabel(frame: .zero)

    super.init()

    selectionStyle = .none

    coloredLabel.textAlignment = .center
    coloredLabel.adjustsFontSizeToFitWidth = true
    coloredLabel.backgroundColor = .clear
    coloredLabel.highlightedTextColor = .highlightedText
    coloredLabel.baseColor = .text
    coloredLabel.translatesAutoresizingMaskIntoConstraints = false
    coloredLabel.adjustsFontForContentSizeCategory = true
    coloredLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.title3)

    contentView.addSubview(coloredLabel)

    let constraints = NSLayoutConstraint.constraints(withVisualFormat: "|-[coloredLabel]-|", options: [], metrics: nil, views: ["coloredLabel": coloredLabel])
      + NSLayoutConstraint.constraints(withVisualFormat: "V:|-[coloredLabel]-|", options: [], metrics: nil, views: ["coloredLabel": coloredLabel])
    NSLayoutConstraint.activate(constraints)
  }

  @available(*, unavailable)
  required init(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func configureForData(_ dictionary: [String: Any], viewController: UIViewController, tableView: UITableView, indexPath: IndexPath) {
    super.configureForData(dictionary, viewController: viewController, tableView: tableView, indexPath: indexPath)

    coloredLabel.highlightStrings = dictionary["highlightStrings"] as? [String]
    coloredLabel.text = dictionary["label"] as? String
  }

  override var accessibilityLabel: String? {
    get {
      self.coloredLabel.text
    }
    set {}
  }

  override func reset() {
    super.reset()

    coloredLabel.text = ""
  }
}
