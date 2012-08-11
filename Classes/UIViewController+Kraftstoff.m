//  UIViewController+Kraftstoff.m
//
// Kraftstoff


#import "UIViewController+Kraftstoff.h"


@implementation UIViewController (Kraftstoff)

- (BOOL)isCurrentVisible
{
    return self.isViewLoaded && self.view.window;
}

@end
