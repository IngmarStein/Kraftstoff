//
//  StyleKit.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 16.12.17.
//  Copyright © 2017 Ingmar Stein. All rights reserved.
//
//  Generated by PaintCode
//  http://www.paintcodeapp.com
//



import UIKit

public class StyleKit : NSObject {

  //// Drawing Methods

  @objc dynamic public class func drawStartHelpCanvas(frame targetFrame: CGRect = CGRect(x: 0, y: 0, width: 320, height: 92), resizing: ResizingBehavior = .aspectFit, text: String = "Start here…") {
    //// General Declarations
    let context = UIGraphicsGetCurrentContext()!

    //// Resize to Target Frame
    context.saveGState()
    let resizedFrame: CGRect = resizing.apply(rect: CGRect(x: 0, y: 0, width: 320, height: 92), target: targetFrame)
    context.translateBy(x: resizedFrame.minX, y: resizedFrame.minY)
    context.scaleBy(x: resizedFrame.width / 320, y: resizedFrame.height / 92)


    //// Label Drawing
    let labelRect = CGRect(x: 0, y: 36, width: 276, height: 24)
    let labelStyle = NSMutableParagraphStyle()
    labelStyle.alignment = .right
    let labelFontAttributes = [
      .font: UIFont.systemFont(ofSize: 20),
      .foregroundColor: UIColor.black,
      .paragraphStyle: labelStyle,
      ] as [NSAttributedString.Key: Any]

    let labelTextHeight: CGFloat = text.boundingRect(with: CGSize(width: labelRect.width, height: CGFloat.infinity), options: .usesLineFragmentOrigin, attributes: labelFontAttributes, context: nil).height
    context.saveGState()
    context.clip(to: labelRect)
    text.draw(in: CGRect(x: labelRect.minX, y: labelRect.minY + (labelRect.height - labelTextHeight) / 2, width: labelRect.width, height: labelTextHeight), withAttributes: labelFontAttributes)
    context.restoreGState()


    //// Arrow Drawing
    let arrowPath = UIBezierPath()
    arrowPath.move(to: CGPoint(x: 286.5, y: 49.5))
    arrowPath.addLine(to: CGPoint(x: 296.5, y: 49.5))
    arrowPath.addLine(to: CGPoint(x: 296.5, y: 17.5))
    arrowPath.move(to: CGPoint(x: 293.5, y: 28.3))
    arrowPath.addLine(to: CGPoint(x: 296.5, y: 17.5))
    arrowPath.addLine(to: CGPoint(x: 299.5, y: 28.3))
    UIColor.black.setStroke()
    arrowPath.lineWidth = 1
    arrowPath.lineCapStyle = .square
    arrowPath.stroke()

    context.restoreGState()

  }

  @objc dynamic public class func drawEditHelpCanvas(frame targetFrame: CGRect = CGRect(x: 0, y: 0, width: 320, height: 92), resizing: ResizingBehavior = .aspectFit, line1: String = "Tap and hold", line2: String = "to modify a car…") {
    //// General Declarations
    let context = UIGraphicsGetCurrentContext()!

    //// Resize to Target Frame
    context.saveGState()
    let resizedFrame: CGRect = resizing.apply(rect: CGRect(x: 0, y: 0, width: 320, height: 92), target: targetFrame)
    context.translateBy(x: resizedFrame.minX, y: resizedFrame.minY)
    context.scaleBy(x: resizedFrame.width / 320, y: resizedFrame.height / 92)


    //// Color Declarations
    let textForeground = UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 1.000)
    let strokeColor = UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 1.000)

    //// Label Drawing
    let labelRect = CGRect(x: 76, y: 38, width: 244, height: 24)
    let labelStyle = NSMutableParagraphStyle()
    labelStyle.alignment = .left
    let labelFontAttributes = [
      .font: UIFont.systemFont(ofSize: 20),
      .foregroundColor: textForeground,
      .paragraphStyle: labelStyle,
      ] as [NSAttributedString.Key: Any]

    let labelTextHeight: CGFloat = line1.boundingRect(with: CGSize(width: labelRect.width, height: CGFloat.infinity), options: .usesLineFragmentOrigin, attributes: labelFontAttributes, context: nil).height
    context.saveGState()
    context.clip(to: labelRect)
    line1.draw(in: CGRect(x: labelRect.minX, y: labelRect.minY + (labelRect.height - labelTextHeight) / 2, width: labelRect.width, height: labelTextHeight), withAttributes: labelFontAttributes)
    context.restoreGState()


    //// Label 2 Drawing
    let label2Rect = CGRect(x: 76, y: 61.58, width: 244, height: 24)
    let label2Style = NSMutableParagraphStyle()
    label2Style.alignment = .left
    let label2FontAttributes = [
      .font: UIFont.systemFont(ofSize: 20),
      .foregroundColor: textForeground,
      .paragraphStyle: label2Style,
      ] as [NSAttributedString.Key: Any]

    let label2TextHeight: CGFloat = line2.boundingRect(with: CGSize(width: label2Rect.width, height: CGFloat.infinity), options: .usesLineFragmentOrigin, attributes: label2FontAttributes, context: nil).height
    context.saveGState()
    context.clip(to: label2Rect)
    line2.draw(in: CGRect(x: label2Rect.minX, y: label2Rect.minY + (label2Rect.height - label2TextHeight) / 2, width: label2Rect.width, height: label2TextHeight), withAttributes: label2FontAttributes)
    context.restoreGState()


    //// Arrow Drawing
    let arrowPath = UIBezierPath()
    arrowPath.move(to: CGPoint(x: 64, y: 50))
    arrowPath.addLine(to: CGPoint(x: 54, y: 50))
    arrowPath.addLine(to: CGPoint(x: 54, y: 18))
    arrowPath.move(to: CGPoint(x: 57, y: 28.8))
    arrowPath.addLine(to: CGPoint(x: 54, y: 18))
    arrowPath.addLine(to: CGPoint(x: 51, y: 28.8))
    strokeColor.setStroke()
    arrowPath.lineWidth = 1
    arrowPath.lineCapStyle = .square
    arrowPath.stroke()

    context.restoreGState()

  }

  //// Generated Images

  @objc dynamic public class func imageOfStartHelpCanvas(text: String = "Start here…") -> UIImage {
    UIGraphicsBeginImageContextWithOptions(CGSize(width: 320, height: 92), false, 0)
    StyleKit.drawStartHelpCanvas(text: text)

    let imageOfStartHelpCanvas = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()

    return imageOfStartHelpCanvas
  }

  @objc dynamic public class func imageOfEditHelpCanvas(line1: String = "Tap and hold", line2: String = "to modify a car…") -> UIImage {
    UIGraphicsBeginImageContextWithOptions(CGSize(width: 320, height: 92), false, 0)
    StyleKit.drawEditHelpCanvas(line1: line1, line2: line2)

    let imageOfEditHelpCanvas = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()

    return imageOfEditHelpCanvas
  }




  @objc(StyleKitResizingBehavior)
  public enum ResizingBehavior: Int {
    case aspectFit /// The content is proportionally resized to fit into the target rectangle.
    case aspectFill /// The content is proportionally resized to completely fill the target rectangle.
    case stretch /// The content is stretched to match the entire target rectangle.
    case center /// The content is centered in the target rectangle, but it is NOT resized.

    public func apply(rect: CGRect, target: CGRect) -> CGRect {
      if rect == target || target == CGRect.zero {
        return rect
      }

      var scales = CGSize.zero
      scales.width = abs(target.width / rect.width)
      scales.height = abs(target.height / rect.height)

      switch self {
      case .aspectFit:
        scales.width = min(scales.width, scales.height)
        scales.height = scales.width
      case .aspectFill:
        scales.width = max(scales.width, scales.height)
        scales.height = scales.width
      case .stretch:
        break
      case .center:
        scales.width = 1
        scales.height = 1
      }

      var result = rect.standardized
      result.size.width *= scales.width
      result.size.height *= scales.height
      result.origin.x = target.minX + (target.width - result.width) / 2
      result.origin.y = target.minY + (target.height - result.height) / 2
      return result
    }
  }
}

