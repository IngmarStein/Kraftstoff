//  FuelCalculatorShadowPageCell.m
//
//  Kraftstoffrechner


#import "FuelCalculatorShadowPageCell.h"


@implementation FuelCalculatorShadowPageCell

@synthesize textFieldShadow;

- (void)finishConstruction
{
	[super finishConstruction];

    // Create a shadow overlay for the textfield that is used to display the textField contents without a flashing cursor
    textFieldShadow = [[UILabel alloc] initWithFrame: self.textField.frame];
    textFieldShadow.font                   = [UIFont systemFontOfSize: [UIFont labelFontSize] - 2];
	textFieldShadow.textAlignment          = UITextAlignmentRight;
	textFieldShadow.backgroundColor        = [UIColor clearColor];
	textFieldShadow.autoresizingMask       = UIViewAutoresizingFlexibleWidth;
	textFieldShadow.userInteractionEnabled = NO;

	[self.contentView addSubview: textFieldShadow];

    // Hide real textfield
    self.textField.hidden = YES;
}


- (NSString*)accessibilityLabel
{
    return [NSString stringWithFormat: @"%@ %@", self.textLabel.text, self.textFieldShadow.text];
}


- (void)dealloc
{
	self.textFieldShadow = nil;

	[super dealloc];
}

@end
