// KSTabBarController.m
//
// Kraftstoff


#import "KSTabBarController.h"


@implementation KSTabBarController

- (NSUInteger)supportedInterfaceOrientations
{
    return [self.selectedViewController supportedInterfaceOrientations];
}

- (BOOL)shouldAutorotate
{
    return [self.selectedViewController shouldAutorotate];
}

@end
