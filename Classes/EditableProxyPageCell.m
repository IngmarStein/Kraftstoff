// EditableProxyPageCell.m
//
// Kraftstoff


#import "EditableProxyPageCell.h"


@implementation EditableProxyPageCell

@synthesize textFieldProxy;

- (void)finishConstruction
{
	[super finishConstruction];

    // Create a proxy overlay for the textfield that is used to display the textField contents
    // without a flashing cursor and no Cut&Paste possibilities
    textFieldProxy = [[UILabel alloc] initWithFrame: CGRectZero];

    textFieldProxy.font                   = self.textField.font;
	textFieldProxy.textAlignment          = NSTextAlignmentRight;
	textFieldProxy.backgroundColor        = [UIColor clearColor];
	textFieldProxy.autoresizingMask       = UIViewAutoresizingFlexibleWidth;
	textFieldProxy.userInteractionEnabled = NO;
    textFieldProxy.isAccessibilityElement = NO;

	[self.contentView addSubview: textFieldProxy];

    // Hide the textfield used for keyboard interaction
    self.textField.hidden = YES;
}


- (void)layoutSubviews
{
    [super layoutSubviews];

    self.textFieldProxy.frame = self.textField.frame;
}


- (NSString*)accessibilityLabel
{
    return [NSString stringWithFormat: @"%@ %@", self.textLabel.text, self.textFieldProxy.text];
}

@end
