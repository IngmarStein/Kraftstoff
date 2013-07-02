// KSNavigationController.m
//
// Kraftstoff


#import "KSNavigationController.h"


@implementation KSNavigationController

- (NSUInteger)supportedInterfaceOrientations
{
    return [self.topViewController supportedInterfaceOrientations];
}

- (BOOL)shouldAutorotate
{
    return [self.topViewController shouldAutorotate];
}

@end
