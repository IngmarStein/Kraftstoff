// FuelCalculatorPageCell.m
//
// Kraftstoff


#import "EditablePageCell.h"
#import "FuelCalculatorController.h"


static CGFloat const margin = 8.0;


@implementation EditablePageCell


@synthesize textField;
@synthesize valueIdentifier;
@synthesize delegate;


- (void)finishConstruction
{
	[super finishConstruction];


    // Create textfield
    textField = [[EditablePageCellTextField alloc] initWithFrame: CGRectZero];

	textField.font                     = [UIFont systemFontOfSize: [UIFont labelFontSize] - 2];
	textField.textAlignment            = UITextAlignmentRight;
	textField.autocapitalizationType   = UITextAutocapitalizationTypeNone;
	textField.autocorrectionType       = UITextAutocorrectionTypeNo;
	textField.backgroundColor          = [UIColor clearColor];
	textField.clearButtonMode          = UITextFieldViewModeWhileEditing;
	textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	textField.autoresizingMask         = UIViewAutoresizingFlexibleWidth;
	textField.userInteractionEnabled   = NO;
    
	[self.contentView addSubview: textField];


    // Configure the default textlabel
    UILabel *label = self.textLabel;

	label.textAlignment        = UITextAlignmentLeft;
	label.font                 = [UIFont boldSystemFontOfSize: [UIFont labelFontSize]];
	label.highlightedTextColor = [UIColor blackColor];
	label.textColor            = [UIColor blackColor];
	label.shadowColor          = [UIColor whiteColor];
	label.shadowOffset         = CGSizeMake (0, 1);
}


- (void)dealloc
{
	self.textField       = nil;
	self.valueIdentifier = nil;

	[super dealloc];
}


- (NSString *)accessibilityLabel
{
	return [NSString stringWithFormat: @"%@ %@", self.textLabel.text, textField.text];
}


- (void)configureForData: (id)dataObject
          viewController: (id)viewController
               tableView: (UITableView*)tableView
               indexPath: (NSIndexPath*)indexPath
{
	[super configureForData: dataObject viewController: viewController tableView: tableView indexPath: indexPath];

	self.textLabel.text   = [(NSDictionary*)dataObject objectForKey: @"label"];
    self.delegate         = viewController;
    self.valueIdentifier  = [(NSDictionary*)dataObject objectForKey: @"valueIdentifier"];

	textField.placeholder = [(NSDictionary*)dataObject objectForKey: @"placeholder"];
	textField.delegate    = self;
}


- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat labelWidth = [self.textLabel.text sizeWithFont: self.textLabel.font].width;
    CGFloat height     = self.contentView.bounds.size.height;
	CGFloat width      = self.contentView.bounds.size.width;

    self.textLabel.frame   = CGRectMake (margin, 0.0, labelWidth,       height - 1);
    self.textField.frame   = CGRectMake (margin, 0.0, width - 2*margin, height - 1);

    // Correct frame for textField would be:
    // CGRectMake (labelWidth + 2*margin, 0, width - labelWidth - 3*margin, height - 1);
}


- (UIColor*)invalidTextColor
{
    return [UIColor colorWithRed: 0.42 green: 0.0 blue: 0.0 alpha: 1.0];
}



#pragma mark -
#pragma mark UITextFieldDelegate



- (void)textFieldDidEndEditing: (UITextField *)aTextField
{
    aTextField.userInteractionEnabled = NO;
}

@end
