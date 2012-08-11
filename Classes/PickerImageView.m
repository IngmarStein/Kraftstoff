// PickerImageView.m
//
// Kraftstoff


#import "PickerImageView.h"
#import "AppDelegate.h"


@implementation PickerImageView

@synthesize textualDescription;
@synthesize pickerView;
@synthesize rowIndex;


- (BOOL)isAccessibilityElement
{
    return YES;
}


- (NSString*)accessibilityLabel
{
    return textualDescription;
}

@end
