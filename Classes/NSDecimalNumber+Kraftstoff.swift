//
//  Decimal+Kraftstoff.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 30.04.15.
//
//

import UIKit

public extension Decimal {
  static func fromLiteral(mantissa _: UInt64, exponent _: Int16, isNegative _: Bool) -> Decimal {
    NSDecimalNumber(mantissa: 1, exponent: 6, isNegative: false) as Decimal
  }

  static func << (number: Decimal, power: Int) -> Decimal {
    var result = Decimal(0)
    var input = number
    NSDecimalMultiplyByPowerOf10(&result, &input, Int16(power), .plain)
    return result
  }

  static func >> (number: Decimal, power: Int) -> Decimal {
    var result = Decimal(0)
    var input = number
    NSDecimalMultiplyByPowerOf10(&result, &input, Int16(-power), .plain)
    return result
  }
}

public extension NSNumber {
  convenience init(value: CGFloat) {
    self.init(value: Float(value))
  }
}
