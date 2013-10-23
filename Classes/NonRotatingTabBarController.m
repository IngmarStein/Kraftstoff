// NonRotatingTabBarController.m
//
// TabBarController that does not autorotate.


#import "NonRotatingTabBarController.h"


@implementation NonRotatingTabBarController

- (BOOL)shouldAutorotate
{
    return NO;
}

@end
