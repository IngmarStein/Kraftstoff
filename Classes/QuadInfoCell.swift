//
//  QuadInfoCell.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 03.05.15.
//
// TableView cells with four labels for information.

import UIKit

class QuadInfoCell: UITableViewCell {

	private(set) var topLeftLabel: UILabel
	private(set) var botLeftLabel: UILabel
	private(set) var topRightLabel: UILabel
	private(set) var botRightLabel: UILabel

	var topLeftAccessibilityLabel: String?
	var botLeftAccessibilityLabel: String?
	var topRightAccessibilityLabel: String?
	var botRightAccessibilityLabel: String?

	private var separatorView: UIView
	private var cellState: UITableViewCellStateMask
	private var large: Bool

	init(style: UITableViewCellStyle, reuseIdentifier: String?, enlargeTopRightLabel: Bool) {
		cellState     = .DefaultMask
		large         = enlargeTopRightLabel
		botLeftLabel  = UILabel(frame:CGRectZero)
		topLeftLabel  = UILabel(frame:CGRectZero)
		topRightLabel = UILabel(frame:CGRectZero)
		botRightLabel = UILabel(frame:CGRectZero)
		separatorView = UIView(frame:CGRectZero)

		super.init(style: style, reuseIdentifier: reuseIdentifier)

        topLeftLabel.backgroundColor            = UIColor.clearColor()
        topLeftLabel.textColor                  = UIColor.blackColor()
        topLeftLabel.adjustsFontSizeToFitWidth  = true
        topLeftLabel.font                       = UIFont(name:"HelveticaNeue-Light", size:22.0)
        topLeftLabel.minimumScaleFactor         = 12.0/topLeftLabel.font.pointSize
		self.contentView.addSubview(topLeftLabel)

        botLeftLabel.backgroundColor            = UIColor.clearColor()
        botLeftLabel.textColor                  = UIColor(white:0.5, alpha:1.0)
        botLeftLabel.adjustsFontSizeToFitWidth  = true
        botLeftLabel.font                       = UIFont(name:"HelveticaNeue-Light", size:15.0)
        botLeftLabel.minimumScaleFactor         = 12.0/botLeftLabel.font.pointSize
        self.contentView.addSubview(botLeftLabel)

        topRightLabel.backgroundColor           = UIColor.clearColor()
        topRightLabel.textColor                 = UIColor.blackColor()
        topRightLabel.adjustsFontSizeToFitWidth = true
		topRightLabel.font                      = UIFont(name:"HelveticaNeue-Light", size:large ? 28.0 : 22.0)
        topRightLabel.minimumScaleFactor        = 12.0/topRightLabel.font.pointSize
        topRightLabel.textAlignment             = .Right
		self.contentView.addSubview(topRightLabel)

        botRightLabel.backgroundColor           = UIColor.clearColor()
        botRightLabel.textColor                 = UIColor(white:0.5, alpha:1.0)
        botRightLabel.adjustsFontSizeToFitWidth = true
        botRightLabel.font                      = UIFont(name:"HelveticaNeue-Light", size:15.0)
        botRightLabel.minimumScaleFactor        = 12.0/botRightLabel.font.pointSize
        botRightLabel.textAlignment             = .Right
        self.contentView.addSubview(botRightLabel)

		separatorView.backgroundColor = UIColor(white:200.0/255.0, alpha:1.0)
		self.contentView.addSubview(separatorView)

        self.accessoryType = .DisclosureIndicator
    }

	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	override var accessibilityLabel: String! {
		get {
			var label = String(format:"%@, %@",
							(topLeftAccessibilityLabel ?? topLeftLabel.text) ?? "",
							(botLeftAccessibilityLabel ?? botLeftLabel.text) ?? "")

			if cellState == .DefaultMask {
				if let accessibilityLabel = topRightAccessibilityLabel {
					label = label.stringByAppendingFormat(", %@", accessibilityLabel)
				}

				if let accessibilityLabel = botRightAccessibilityLabel {
					label = label.stringByAppendingFormat(" %@", accessibilityLabel)
				}
			}

			return label
		}
		set {
		}
	}


	// Remember target state for transition
	override func willTransitionToState(state: UITableViewCellStateMask) {
		super.willTransitionToState(state)
		cellState = state
	}

	// Reset to default state before reuse of cell
	override func prepareForReuse() {
		super.prepareForReuse()
		cellState = .DefaultMask
	}

	override func layoutSubviews() {
		let margin: CGFloat = 15.0

		// offset to compensate shift caused by editing control
		let editOffset : CGFloat

		if cellState & .ShowingEditControlMask == .ShowingEditControlMask {
			editOffset = 38.0
		} else {
			editOffset = 0.0
		}

		// space that can be distributed
		let width = CGFloat(self.frame.size.width) - 9.0 - margin

		// width of right labels
		let iWidth: CGFloat  = large ? 96.0 : 135.0

		// y position and height of top right label
		let iYStart: CGFloat = large ? 17.0 :  20.0
		let iHeight: CGFloat = large ? 36.0 :  30.0
		let separatorHeight = 1.0 / UIScreen.mainScreen().scale

		// compute label frames
		topLeftLabel.frame  = CGRect(x:margin,                      y:20.0,    width: width - iWidth - 20, height: 30.0)
		botLeftLabel.frame  = CGRect(x:margin,                      y:52.0,    width: width - iWidth - 20, height: 20.0)
		topRightLabel.frame = CGRect(x:width - iWidth - editOffset, y:iYStart, width: iWidth - margin,     height: iHeight)
		botRightLabel.frame = CGRect(x:width - iWidth - editOffset, y:52.0,    width: iWidth - margin,     height: 20.0)
		separatorView.frame = CGRect(x:0.0, y:self.frame.size.height - separatorHeight, width: self.frame.size.width, height: separatorHeight)

		// hide right labels in editing modes
		UIView.animateWithDuration(0.5) {
			let newAlpha: CGFloat = ((self.cellState & .ShowingEditControlMask) == .ShowingEditControlMask) ? 0.0 : 1.0
			self.topRightLabel.alpha = newAlpha
			self.botRightLabel.alpha = newAlpha
		}

		super.layoutSubviews()
	}

}
