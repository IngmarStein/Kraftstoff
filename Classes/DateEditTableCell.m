// DateEditTableCell.m
//
// Kraftstoff


#import "DateEditTableCell.h"
#import "FuelCalculatorController.h"
#import "AppDelegate.h"


@interface DateEditTableCell (private)

- (void)significantTimeChange: (id)object;

- (void)datePickerValueChanged: (UIDatePicker*)sender;

- (void)refreshDatePickerInputViewWithDate: (NSDate*)date forceRecreation: (BOOL)force;

@end


@implementation DateEditTableCell

@synthesize valueTimestamp;
@synthesize dateFormatter;
@synthesize autoRefreshedDate;


- (void)finishConstruction
{
	[super finishConstruction];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector (significantTimeChange:)
                                                 name: UIApplicationSignificantTimeChangeNotification
                                               object: nil];
}


- (void)updateTextFieldColorForValue: (id)value
{
    BOOL valid = YES;
    
    if ([(id)self.delegate respondsToSelector: @selector(valueValid:identifier:)])
        if (! [self.delegate valueValid:value identifier: self.valueIdentifier])
            valid = NO;
    
    self.textFieldProxy.textColor = (valid) ? [UIColor blackColor] : [self invalidTextColor];
}


- (void)configureForData: (id)dataObject viewController: (id)viewController tableView: (UITableView*)tableView indexPath: (NSIndexPath*)indexPath
{
	[super configureForData: dataObject viewController: viewController tableView: tableView indexPath: indexPath];

    NSDate *value = [self.delegate valueForIdentifier: self.valueIdentifier];

    self.valueTimestamp      = [(NSDictionary*)dataObject objectForKey: @"valueTimestamp"];
    self.dateFormatter       = [(NSDictionary*)dataObject objectForKey: @"formatter"];
    self.autoRefreshedDate   = [[(NSDictionary*)dataObject objectForKey: @"autorefresh"] boolValue];

    self.textFieldProxy.text = (value) ? [self.dateFormatter stringFromDate: value] : @"";

    [self updateTextFieldColorForValue: value];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    self.valueTimestamp = nil;
	self.dateFormatter  = nil;

	[super dealloc];
}


- (void)significantTimeChange: (id)object
{
    if (self.valueTimestamp)
        [self.delegate valueChanged: [NSDate distantPast] identifier: self.valueTimestamp];

    [self refreshDatePickerInputViewWithDate: nil forceRecreation: YES];
}


- (void)datePickerValueChanged: (UIDatePicker*)sender
{
    NSDate *selectedDate = [AppDelegate dateWithoutSeconds: [sender date]];

    if ([[self.delegate valueForIdentifier: self.valueIdentifier] isEqualToDate: selectedDate] == NO)
    {
        self.textFieldProxy.text = [self.dateFormatter stringFromDate: selectedDate];
        [self.delegate valueChanged: selectedDate  identifier: self.valueIdentifier];
        [self.delegate valueChanged: [NSDate date] identifier: self.valueTimestamp];
        [self updateTextFieldColorForValue: selectedDate];        
    }
}


- (void)refreshDatePickerInputViewWithDate: (NSDate*)date forceRecreation: (BOOL)forceRecreation;
{
    NSDate *now = [NSDate date];


    // Get previous input view
    UIDatePicker *datePicker = nil;

    if (!forceRecreation)
        if ([self.textField.inputView isKindOfClass: [UIDatePicker class]])
            datePicker = (UIDatePicker*)self.textField.inputView;


    // If not specified get the date to be selected from the delegate
    if (date == nil)
        date = [self.delegate valueForIdentifier: self.valueIdentifier];

    if (date == nil)
        date = now;


    // Create new datepicker with a correct 'today' flag
    if (datePicker == nil || forceRecreation)
    {
        datePicker                = [[[UIDatePicker alloc] init] autorelease];
        datePicker.datePickerMode = UIDatePickerModeDateAndTime;

        [datePicker addTarget: self
                       action: @selector (datePickerValueChanged:)
             forControlEvents: UIControlEventValueChanged];

        self.textField.inputView = datePicker;
    }

    [datePicker setMaximumDate: [AppDelegate dateWithoutSeconds: now]];
    [datePicker setDate: [AppDelegate dateWithoutSeconds: date] animated: NO];


    // Immediate update when we are the first responder and notify delegate about new value too
    [self datePickerValueChanged: datePicker];
    [self.textField reloadInputViews];
}



#pragma mark -
#pragma mark UITextFieldDelegate



- (void)textFieldDidBeginEditing: (UITextField *)aTextField
{
    // Optional: update selected value to current time when no change was done in the last 5 minutes
    NSDate *selectedDate = nil;

    if (autoRefreshedDate)
    {
        NSDate *now            = [NSDate date];
        NSDate *lastChangeDate = [self.delegate valueForIdentifier: self.valueTimestamp];

        NSTimeInterval noChangeInterval = [now timeIntervalSinceDate: lastChangeDate];

        if (lastChangeDate == nil || noChangeInterval >= 300 || noChangeInterval < 0)
            selectedDate = now;
    }

    // Update the date picker with the selected time
    [self refreshDatePickerInputViewWithDate: selectedDate forceRecreation: NO];
}

@end
