// EditablePageCell.m
//
// Kraftstoff


#import "EditablePageCell.h"
#import "FuelCalculatorController.h"
#import "AppDelegate.h"


static CGFloat const margin = 8.0;


@implementation EditablePageCell


- (void)finishConstruction
{
	[super finishConstruction];

    // Create textfield
    self.textField = [[EditablePageCellTextField alloc] initWithFrame:CGRectZero];

	self.textField.font                     = [UIFont fontWithName:@"HelveticaNeue-Light" size:17.0];
	self.textField.textAlignment            = NSTextAlignmentRight;
	self.textField.autocapitalizationType   = UITextAutocapitalizationTypeNone;
	self.textField.autocorrectionType       = UITextAutocorrectionTypeNo;
	self.textField.backgroundColor          = [UIColor clearColor];
	self.textField.clearButtonMode          = UITextFieldViewModeWhileEditing;
	self.textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	self.textField.autoresizingMask         = UIViewAutoresizingFlexibleWidth;
	self.textField.userInteractionEnabled   = NO;

	[self.contentView addSubview:self.textField];


    // Configure the default textlabel
    UILabel *label = self.textLabel;

	label.textAlignment        = NSTextAlignmentLeft;
	label.font                 = [UIFont fontWithName:@"HelveticaNeue" size:17.0];
	label.highlightedTextColor = [UIColor blackColor];
	label.textColor            = [UIColor blackColor];
}


- (NSString *)accessibilityLabel
{
	return [NSString stringWithFormat:@"%@ %@", self.textLabel.text, self.textField.text];
}


- (void)configureForData:(id)dataObject
          viewController:(id)viewController
               tableView:(UITableView *)tableView
               indexPath:(NSIndexPath *)indexPath
{
	[super configureForData:dataObject viewController:viewController tableView:tableView indexPath:indexPath];

	self.textLabel.text   = ((NSDictionary *)dataObject)[@"label"];
    self.delegate         = viewController;
    self.valueIdentifier  = ((NSDictionary *)dataObject)[@"valueIdentifier"];

	self.textField.placeholder = ((NSDictionary *)dataObject)[@"placeholder"];
	self.textField.delegate    = self;
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat leftOffset = 6.0;
    CGFloat labelWidth = [self.textLabel.text sizeWithAttributes:@{NSFontAttributeName:self.textLabel.font}].width;
    CGFloat height     = self.contentView.bounds.size.height;
	CGFloat width      = self.contentView.bounds.size.width;

    self.textLabel.frame = CGRectMake (leftOffset + margin, 0.0, labelWidth,                    height - 1);
    self.textField.frame = CGRectMake (leftOffset + margin, 0.0, width - 2*margin - leftOffset, height - 1);
}


- (UIColor *)invalidTextColor
{
    return [(AppDelegate *)[[UIApplication sharedApplication] delegate] window].tintColor;
}



#pragma mark -
#pragma mark UITextFieldDelegate



- (void)textFieldDidEndEditing:(UITextField *)aTextField
{
    aTextField.userInteractionEnabled = NO;
}

@end
