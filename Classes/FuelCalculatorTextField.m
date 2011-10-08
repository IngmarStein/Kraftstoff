//  FuelCalculatorTextField.m
//
//  Kraftstoffrechner


#import "FuelCalculatorTextField.h"


@implementation FuelCalculatorTextField

@synthesize allowCut;
@synthesize allowPaste;


- (id)initWithFrame: (CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        allowCut   = NO;
        allowPaste = NO;
    }

    return self;
}


// Disable cut&paste functionality to properly handle special text inputs methods for out textfields
- (BOOL)canPerformAction: (SEL)action withSender: (id)sender
{
    if (action == @selector (cut:) && allowCut == NO)
        return NO;

    if (action == @selector (paste:) && allowPaste == NO)
        return NO;

    return [super canPerformAction: action withSender: sender];
}

@end
