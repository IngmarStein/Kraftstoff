// TextEditTableCell.m
//
// Kraftstoff


#import "TextEditTableCell.h"

NSUInteger const maximumTextFieldLength = 15;


@implementation TextEditTableCell

- (void)finishConstruction
{
	[super finishConstruction];

    self.textField.keyboardType  = UIKeyboardTypeASCIICapable;
    self.textField.returnKeyType = UIReturnKeyNext;
    self.textField.allowCut      = YES;
    self.textField.allowPaste    = YES;
}


- (void)configureForData: (id)dataObject viewController: (id)viewController tableView: (UITableView*)tableView indexPath: (NSIndexPath*)indexPath
{
	[super configureForData: dataObject viewController: viewController tableView: tableView indexPath: indexPath];

    if ([[(NSDictionary*)dataObject valueForKey: @"autocapitalizeAll"] boolValue])
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    else
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;

    self.textField.text = [self.delegate valueForIdentifier: self.valueIdentifier];
}



#pragma mark -
#pragma mark UITextFieldDelegate



- (BOOL)textFieldShouldReturn: (UITextField *)aTextField
{
    // Let delegate handle switching to next textfield
    if ([(id)self.delegate respondsToSelector: @selector(focusNextFieldForValueIdentifier:)])
    {
        [self.delegate focusNextFieldForValueIdentifier: self.valueIdentifier];
    }

    return NO;
}


- (BOOL)textFieldShouldClear: (UITextField*)aTextField
{
    // Propagate cleared value to the delegate
    [self.delegate valueChanged: @"" identifier: self.valueIdentifier];

    return YES;
}


- (BOOL)textField: (UITextField*)aTextField shouldChangeCharactersInRange: (NSRange)range replacementString: (NSString*)string
{
    NSString *newValue = [aTextField.text stringByReplacingCharactersInRange: range withString: string];

    // Don't allow to large strings
    if ([newValue length] > maximumTextFieldLength)
        return NO;

    // Do the update here and propagate the new value back to the delegate
    aTextField.text = newValue;

    [self.delegate valueChanged: newValue identifier: self.valueIdentifier];
    return NO;
}

@end
