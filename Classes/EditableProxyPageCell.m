// EditableProxyPageCell.m
//
// Kraftstoff


#import "EditableProxyPageCell.h"


@implementation EditableProxyPageCell

- (void)finishConstruction
{
	[super finishConstruction];

    // Create a proxy overlay for the textfield that is used to display the textField contents
    // without a flashing cursor and no Cut&Paste possibilities
    self.textFieldProxy = [[UILabel alloc] initWithFrame:CGRectZero];

    self.textFieldProxy.font                   = self.textField.font;
	self.textFieldProxy.textAlignment          = NSTextAlignmentRight;
	self.textFieldProxy.backgroundColor        = [UIColor clearColor];
	self.textFieldProxy.autoresizingMask       = UIViewAutoresizingFlexibleWidth;
	self.textFieldProxy.userInteractionEnabled = NO;
    self.textFieldProxy.isAccessibilityElement = NO;

	[self.contentView addSubview:self.textFieldProxy];

    // Hide the textfield used for keyboard interaction
    self.textField.hidden = YES;
}


- (void)layoutSubviews
{
    [super layoutSubviews];

    self.textFieldProxy.frame = self.textField.frame;
}


- (NSString *)accessibilityLabel
{
    return [NSString stringWithFormat:@"%@ %@", self.textLabel.text, self.textFieldProxy.text];
}

@end
