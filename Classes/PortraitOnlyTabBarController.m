// KSTabBarController.m
//
// TabBarController subclass that allows only portrait orientation
// (needed for iOS6 which doesn't support delegate methods for rotation)


#import "PortraitOnlyTabBarController.h"


@implementation PortraitOnlyTabBarController

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

@end
