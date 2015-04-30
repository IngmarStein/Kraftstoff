// FuelCalculatorTextField.m
//
// Kraftstoff


#import "EditablePageCellTextField.h"


@implementation EditablePageCellTextField

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {

        _allowCut   = NO;
        _allowPaste = NO;
    }

    return self;
}


// Disable Cut&Paste functionality to properly handle special text inputs methods for our textfields
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (action == @selector(cut:) && !self.allowCut)
        return NO;

    if (action == @selector(paste:) && !self.allowPaste)
        return NO;

    return [super canPerformAction:action withSender:sender];
}

@end
