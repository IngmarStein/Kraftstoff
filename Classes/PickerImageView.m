// PickerImageView.m
//
// Kraftstoff


#import "PickerImageView.h"
#import "AppDelegate.h"


@implementation PickerImageView

- (BOOL)isAccessibilityElement
{
    return YES;
}


- (NSString *)accessibilityLabel
{
    return self.textualDescription;
}

@end
