//
//  AppWindow.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 30.04.15.
//
//

import UIKit

class AppWindow: UIWindow {

	override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent?)	{
		if motion == .MotionShake {
			NSNotificationCenter.defaultCenter().postNotificationName(kraftstoffDeviceShakeNotification, object:nil)
		} else {
			super.motionEnded(motion, withEvent:event)
		}
	}

}
