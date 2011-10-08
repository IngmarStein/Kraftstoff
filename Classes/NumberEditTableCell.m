// NumberEditTableCell.m
//
// Kraftstoff


#import "NumberEditTableCell.h"
#import "FuelCalculatorController.h"


@implementation NumberEditTableCell

@synthesize textFieldSuffix;
@synthesize numberFormatter;
@synthesize alternateNumberFormatter;


- (void)finishConstruction
{
	[super finishConstruction];

    self.textField.keyboardType = UIKeyboardTypeNumberPad;
}


- (void)dealloc
{
    self.numberFormatter          = nil;
    self.alternateNumberFormatter = nil;
    self.textFieldSuffix          = nil;

    [super dealloc];
}


- (void)configureForData: (id)dataObject viewController: (id)viewController tableView: (UITableView*)tableView indexPath: (NSIndexPath*)indexPath
{
	[super configureForData: dataObject viewController: viewController tableView: tableView indexPath: indexPath];

    self.textFieldSuffix          = [(NSDictionary*)dataObject objectForKey: @"suffix"];
    self.numberFormatter          = [(NSDictionary*)dataObject objectForKey: @"formatter"];
    self.alternateNumberFormatter = [(NSDictionary*)dataObject objectForKey: @"alternateFormatter"];

    NSDecimalNumber *value = [self.delegate valueForIdentifier: self.valueIdentifier];

    if (value)
    {
        if (self.alternateNumberFormatter)
            self.textField.text = [self.alternateNumberFormatter stringFromNumber: value];
        else
            self.textField.text = [self.numberFormatter stringFromNumber: value];

        if (self.textFieldSuffix)
            self.textField.text = [self.textField.text stringByAppendingString: self.textFieldSuffix];
    }
    else
        self.textField.text = @"";
}



#pragma mark -
#pragma mark UITextFieldDelegate



// Implement special behavior for newly added characters
- (BOOL)textField: (UITextField*)aTextField shouldChangeCharactersInRange: (NSRange)range replacementString: (NSString*)string
{
    // Modify text
    NSString *text         = [aTextField text];
    NSDecimalNumber *value = (NSDecimalNumber*)[self.numberFormatter numberFromString: text];
    NSDecimalNumber *ten   = [NSDecimalNumber decimalNumberWithMantissa: 1 exponent: 1 isNegative: NO];
    NSDecimalNumber *scale = [NSDecimalNumber decimalNumberWithMantissa: 1 exponent: [self.numberFormatter maximumFractionDigits] isNegative: NO];

    if (range.length == 0)
    {
        if (range.location == [text length] && [string length] == 1)
        {
            // New character must be a digit
            NSDecimalNumber *digit = [NSDecimalNumber decimalNumberWithString: string];

            if ([digit isEqual: [NSDecimalNumber notANumber]])
                return NO;

            // Special shift semantics when appending at end of string
            value = [value decimalNumberByMultiplyingBy: ten];
            value = [value decimalNumberByAdding: [digit decimalNumberByDividingBy: scale]];
        }
        else
        {
            // Normal insert otherwise
            text  = [text stringByReplacingCharactersInRange: range withString: string];
            text  = [text stringByReplacingOccurrencesOfString: [self.numberFormatter groupingSeparator] withString: @""];
            value = (NSDecimalNumber*)[self.numberFormatter numberFromString: text];
        }

        // Don't append when the result gets too large or below zero
        if ([value compare: [NSDecimalNumber decimalNumberWithMantissa: 1 exponent: 6 isNegative: NO]] != NSOrderedAscending)
            return NO;

        if ([value compare: [NSDecimalNumber zero]] == NSOrderedAscending)
            return NO;
    }

    else if (range.location >= [text length] - 1)
    {
        NSDecimalNumberHandler *handler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode: NSRoundDown
                                                                                                 scale: (short)[self.numberFormatter maximumFractionDigits]
                                                                                      raiseOnExactness: NO
                                                                                       raiseOnOverflow: NO
                                                                                      raiseOnUnderflow: NO
                                                                                   raiseOnDivideByZero: NO];

        // Delete only the last digit
        value = [value decimalNumberByDividingBy: ten withBehavior: handler];
        value = [value decimalNumberByRoundingAccordingToBehavior:  handler];
    }

    [aTextField setText: [self.numberFormatter stringFromNumber: value]];

    // Tell delegate about new value
    [self.delegate valueChanged: value identifier: self.valueIdentifier];

    return NO;
}


// Reset to zero value on clear
- (BOOL)textFieldShouldClear: (UITextField*)aTextField
{
    NSNumber *clearedValue = [NSDecimalNumber zero];


    if (aTextField.editing)
    {
        aTextField.text = [self.numberFormatter stringFromNumber: clearedValue];
    }
    else
    {
        if (self.alternateNumberFormatter)
            aTextField.text = [self.alternateNumberFormatter stringFromNumber: clearedValue];
        else
            aTextField.text = [self.numberFormatter stringFromNumber: clearedValue];

        if (self.textFieldSuffix)
            aTextField.text = [aTextField.text stringByAppendingString: self.textFieldSuffix];
    }

    // Tell delegate about new value
    [self.delegate valueChanged: clearedValue identifier: self.valueIdentifier];

    return NO;
}


// Editing starts, remove suffix and switch to normal formatter
- (void)textFieldDidBeginEditing: (UITextField *)aTextField
{
    if (self.textFieldSuffix)
    {
        if ([aTextField.text hasSuffix: self.textFieldSuffix])
            aTextField.text = [aTextField.text substringToIndex: [aTextField.text length] - [self.textFieldSuffix length]];
    }

    if (self.alternateNumberFormatter)
    {
        NSDecimalNumber *value = (NSDecimalNumber*)[self.alternateNumberFormatter numberFromString: aTextField.text];

        if (value == nil)
            value = [NSDecimalNumber zero];

        aTextField.text = [self.numberFormatter stringFromNumber: value];
        [self.delegate valueChanged: value identifier: self.valueIdentifier];
    }
}


// Editing ends, switch back to alternate formatter and append specified suffix
- (void)textFieldDidEndEditing: (UITextField *)aTextField
{
    if (self.alternateNumberFormatter)
    {
        NSDecimalNumber *value = (NSDecimalNumber*)[self.numberFormatter numberFromString: aTextField.text];

        if (value == nil)
            value = [NSDecimalNumber zero];

        aTextField.text = [self.alternateNumberFormatter stringFromNumber: value];
        [self.delegate valueChanged: value identifier: self.valueIdentifier];
    }

    if (self.textFieldSuffix)
    {
        if (! [aTextField.text hasSuffix: self.textFieldSuffix])
            aTextField.text = [aTextField.text stringByAppendingString: self.textFieldSuffix];
    }

    [super textFieldDidEndEditing: aTextField];
}

@end
