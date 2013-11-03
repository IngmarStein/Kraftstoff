// FuelCalculatorTextField.m
//
// Kraftstoff


#import "EditablePageCellTextField.h"


@implementation EditablePageCellTextField

@synthesize allowCut;
@synthesize allowPaste;


- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {

        allowCut   = NO;
        allowPaste = NO;
    }

    return self;
}


// Disable Cut&Paste functionality to properly handle special text inputs methods for our textfields
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (action == @selector(cut:) && allowCut == NO)
        return NO;

    if (action == @selector(paste:) && allowPaste == NO)
        return NO;

    return [super canPerformAction:action withSender:sender];
}

@end
