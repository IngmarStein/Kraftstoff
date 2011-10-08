//  FuelCalculatorPageCell.m
//
//  Kraftstoffrechner


#import "FuelCalculatorPageCell.h"
#import "FuelCalculatorController.h"


static CGFloat const labelWidth = 80.0;
static CGFloat const margin     =  8.0;


@implementation FuelCalculatorPageCell


@synthesize textField;
@synthesize valueIdentifier;
@synthesize delegate;


- (void)finishConstruction
{
	[super finishConstruction];

	CGFloat height   = self.contentView.bounds.size.height;
	CGFloat width    = self.contentView.bounds.size.width;
	CGFloat fontSize = [UIFont labelFontSize] - 2;


    // create textfield
    textField = [[FuelCalculatorTextField alloc] initWithFrame: CGRectMake (labelWidth + 2*margin,
                                                                            0,
                                                                            width - labelWidth - 3*margin,
                                                                            height - 1)];

	textField.font                     = [UIFont systemFontOfSize:fontSize];
	textField.textAlignment            = UITextAlignmentRight;
	textField.autocapitalizationType   = UITextAutocapitalizationTypeNone;
	textField.autocorrectionType       = UITextAutocorrectionTypeNo;
	textField.backgroundColor          = [UIColor clearColor];
	textField.clearButtonMode          = UITextFieldViewModeWhileEditing;
	textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	textField.autoresizingMask         = UIViewAutoresizingFlexibleWidth;
	textField.userInteractionEnabled   = NO;

	[self.contentView addSubview: textField];


    // configure the default textlabel
    UILabel *label = self.textLabel;

	label.textAlignment        = UITextAlignmentLeft;
	label.font                 = [UIFont boldSystemFontOfSize: fontSize];
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


// Return description and value for Voice Over
- (NSString *)accessibilityLabel
{
	return [NSString stringWithFormat: @"%@ %@", self.textLabel.text, textField.text];
}



// Configure cell with set of data
- (void)configureForData: (id)dataObject
               tableView: (UITableView*)tableView
               indexPath: (NSIndexPath*)indexPath
{
	[super configureForData: dataObject tableView: tableView indexPath: indexPath];

	self.textLabel.text   = [(NSDictionary*)dataObject objectForKey: @"label"];
    self.delegate         = [(NSDictionary*)dataObject objectForKey: @"delegate"];
    self.valueIdentifier  = [(NSDictionary*)dataObject objectForKey: @"valueIdentifier"];

	textField.placeholder = [(NSDictionary*)dataObject objectForKey: @"placeholder"];
	textField.delegate    = self;
}



#pragma mark -
#pragma mark UITextFieldDelegate



// Deactivate userinput after editing ends, so that the table catches all touches
- (BOOL)textFieldShouldEndEditing:(UITextField *)aTextField
{
    aTextField.userInteractionEnabled = NO;
    return YES;
}

@end
