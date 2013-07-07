// AppWindow.m
//
// Kraftstoff

#import "AppWindow.h"
#import "AppDelegate.h"

@implementation AppWindow

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake) {

        [[NSNotificationCenter defaultCenter]
            postNotification:[NSNotification notificationWithName:kraftstoffDeviceShakeNotification
                                                           object:nil]];
    }
    else
        [super motionEnded:motion withEvent:event];
}

@end
