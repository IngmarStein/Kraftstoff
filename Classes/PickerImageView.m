// PickerImageView.m
//
// Kraftstoff


#import "PickerImageView.h"
#import "AppDelegate.h"


@implementation PickerImageView

@synthesize textualDescription;
@synthesize pickerView;
@synthesize rowIndex;


- (void)dealloc
{
    self.textualDescription = nil;

    [super dealloc];
}


- (BOOL)isAccessibilityElement
{
    return YES;
}


- (NSString*)accessibilityLabel
{
    return textualDescription;
}


// Workaround for disabled autoselection prior to iOS 5
- (void)viewTapped: (id)sender
{
    if (pickerView)
    {
        [pickerView selectRow: rowIndex inComponent: 0 animated: YES];

        // didSelectRow is not called on programatic updates
        if ([pickerView.delegate respondsToSelector: @selector(pickerView:didSelectRow:inComponent:)])
            [pickerView.delegate pickerView: pickerView didSelectRow: rowIndex inComponent: 0];
    }
}

@end
