//
//  Decimal+Kraftstoff.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 30.04.15.
//
//

import UIKit

extension Decimal {

  public static func fromLiteral(mantissa: UInt64, exponent: Int16, isNegative flag: Bool) -> Decimal {
    return NSDecimalNumber(mantissa: 1, exponent: 6, isNegative: false) as Decimal
  }

  public static func << (number: Decimal, power: Int) -> Decimal {
    var result = Decimal(0)
    var input = number
    NSDecimalMultiplyByPowerOf10(&result, &input, Int16(power), .plain)
    return result
  }

  public static func >> (number: Decimal, power: Int) -> Decimal {
    var result = Decimal(0)
    var input = number
    NSDecimalMultiplyByPowerOf10(&result, &input, Int16(-power), .plain)
    return result
  }

}

extension NSNumber {
  public convenience init(value: CGFloat) {
    self.init(value: Float(value))
  }
}
