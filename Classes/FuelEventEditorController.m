// FuelEventEditorController.h
//
// Kraftstoff


#import "AppDelegate.h"
#import "AppWindow.h"
#import "FuelEventEditorController.h"
#import "FuelEventController.h"
#import "CarTableCell.h"
#import "ConsumptionTableCell.h"
#import "DateEditTableCell.h"
#import "NumberEditTableCell.h"
#import "SwitchTableCell.h"



@interface FuelEventEditorController (private)

- (void)reloadStateFromEvent;
- (void)reconfigureFillupRow;

- (IBAction)enterEditingMode: (id)sender;

- (void)endEditingModeAndSaveCompletion: (id)sender;
- (IBAction)endEditingModeAndSave: (id)sender;

- (void)endEditingModeAndRevertCompletion: (id)sender;
- (void)endEditingModeAndRevertSheet: (id)sender;
- (IBAction)endEditingModeAndRevert: (id)sender;

- (void)selectRowAtIndexPath: (NSIndexPath*)path;

- (void)createConsumptionRowWithAnimation: (UITableViewRowAnimation)animation;
- (void)createDataRows: (unsigned)rowMask withAnimation: (UITableViewRowAnimation)animation;
- (void)createTableContentsWithAnimation: (UITableViewRowAnimation)animation;
- (void)recreateTableContentsWithAnimation: (UITableViewRowAnimation)animation;

- (void)dismissKeyboardWithCompletion: (void (^)(void))completion;

- (void)localeChangedCompletion: (id)previousSelection;
- (void)localeChanged: (id)object;

@end



@implementation FuelEventEditorController

@synthesize managedObjectContext;

@synthesize event;
@synthesize car;
@synthesize date;
@synthesize distance;
@synthesize price;
@synthesize fuelVolume;
@synthesize filledUp;

@synthesize editingTextField;

@synthesize editButton;
@synthesize cancelButton;
@synthesize doneButton;

@synthesize editing;



#pragma mark -
#pragma mark View Lifecycle



- (id)initWithNibName: (NSString*)nibName bundle: (NSBundle*)nibBundle
{
    if ((self = [super initWithNibName: nibName bundle: nibBundle]))
    {
        editing               = NO;
        dataChanged           = NO;
        mostRecentSelectedRow = 0;
    }

    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    // Navigation-Bar buttons
    self.editButton   = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemEdit
                                                                       target: self
                                                                       action: @selector (enterEditingMode:)];

    self.doneButton   = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone
                                                                       target: self
                                                                       action: @selector (endEditingModeAndSave:)];

    self.cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemStop
                                                                       target: self
                                                                       action: @selector (endEditingModeAndRevert:)];

    self.navigationItem.rightBarButtonItem = editButton;

    // Add shadow layer onto the background image view
    UIView *imageView = [self.view viewWithTag: 100];

    [imageView.layer
        insertSublayer: [AppDelegate shadowWithFrame: CGRectMake (0.0, 0.0, imageView.frame.size.width, LargeShadowHeight)
                                          darkFactor: 0.5
                                         lightFactor: 150.0 / 255.0
                                       fadeDownwards: YES]
               atIndex: 0];

    // Observe locale changes
    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector (localeChanged:)
               name: NSCurrentLocaleDidChangeNotification
             object: nil];

    // View title
    self.title = [[AppDelegate sharedDateFormatter] stringFromDate: [event valueForKey: @"timestamp"]];

    // Table contents
    self.constantRowHeight = NO;
    self.tableView.allowsSelection = NO;

    [self recreateTableContentsWithAnimation: UITableViewRowAnimationNone];
}


- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    self.editingTextField = nil;
    self.editButton       = nil;
    self.cancelButton     = nil;
    self.doneButton       = nil;

    [super viewDidUnload];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}


- (void)viewDidAppear: (BOOL)animated
{
    [super viewDidAppear: animated];

    [[AppDelegate sharedDelegate]
        setWindowBackground: [UIImage backgroundImageWithPattern: [UIImage imageNamed: @"TablePattern"]]
                   animated: animated];
}


- (void)viewDidDisappear: (BOOL)animated
{
    [super viewDidDisappear: animated];

    [[AppDelegate sharedDelegate]
        setWindowBackground: [UIImage imageNamed: @"TableBackground"]
                   animated: animated];
}



#pragma mark -
#pragma mark Setting the Edited Event



- (void)reloadStateFromEvent
{
    self.car = [event valueForKey: @"car"];

    KSDistance odometerUnit = [[car valueForKey: @"odometerUnit"] integerValue];
    KSVolume   fuelUnit     = [[car valueForKey: @"fuelUnit"]     integerValue];

    self.date       = [event valueForKey: @"timestamp"];
    self.distance   = [AppDelegate distanceForKilometers: [event valueForKey: @"distance"] withUnit: odometerUnit];
    self.price      = [event valueForKey: @"price"];
    self.fuelVolume = [AppDelegate volumeForLiters: [event valueForKey: @"fuelVolume"] withUnit: fuelUnit];
    self.filledUp   = [[event valueForKey: @"filledUp"] boolValue];

    dataChanged = NO;
}


- (void)setEvent: (NSManagedObject*)newEvent
{
    if (event != newEvent)
    {
        event = newEvent;

        [self reloadStateFromEvent];

        self.title = [[AppDelegate sharedDateFormatter] stringFromDate: [event valueForKey: @"timestamp"]];
    }
}



#pragma mark -
#pragma mark Entering Editing Mode



- (void)reconfigureRow: (int)row
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow: row inSection: 0];

    PageCell *cell = (PageCell*)[self.tableView cellForRowAtIndexPath: indexPath];

    [cell configureForData: [self dataForRow: row inSection: 0]
            viewController: self
                 tableView: self.tableView
                 indexPath: indexPath];

    [cell setNeedsDisplay];
}


- (IBAction)enterEditingMode: (id)sender
{
    self.tableView.allowsSelection = editing = YES;

    [self reconfigureRow: 4];
    [self selectRowAtIndexPath: [NSIndexPath indexPathForRow: 0 inSection: 0]];
}



#pragma mark -
#pragma mark Update of Edited Data



- (void)endEditingModeAndSaveCompletion: (id)sender
{
    [self.editingTextField resignFirstResponder];
    self.editingTextField = nil;

    self.navigationItem.leftBarButtonItem  = nil;
    self.navigationItem.rightBarButtonItem = editButton;

    [self createConsumptionRowWithAnimation: UITableViewRowAnimationFade];

    // Replace event in database with new version
    if (dataChanged)
    {
        dataChanged = NO;

        [AppDelegate removeEventFromArchive: self.event
                     inManagedObjectContext: managedObjectContext
                        forceOdometerUpdate: YES];

        [[AppDelegate sharedDelegate] saveContext: self.managedObjectContext];

        self.event = [AppDelegate addToArchiveWithCar: car
                                                 date: date
                                             distance: [AppDelegate kilometersForDistance: distance
                                                                                 withUnit: [[car valueForKey: @"odometerUnit"] integerValue]]
                                                price: price
                                           fuelVolume: [AppDelegate litersForVolume: fuelVolume
                                                                           withUnit: [[car valueForKey: @"fuelUnit"] integerValue]]
                                             filledUp: filledUp
                               inManagedObjectContext: managedObjectContext
                                  forceOdometerUpdate: YES];

        [[AppDelegate sharedDelegate] saveContext: self.managedObjectContext];
    }
}


- (IBAction)endEditingModeAndSave: (id)sender
{
    self.tableView.allowsSelection = editing = NO;

    [self reconfigureRow: 4];
    [self dismissKeyboardWithCompletion: ^{ [self endEditingModeAndSaveCompletion: sender]; }];
}



#pragma mark -
#pragma mark Aborting Editing Mode



- (void)actionSheet: (UIActionSheet*)actionSheet clickedButtonAtIndex: (NSInteger)buttonIndex
{
    if (buttonIndex != actionSheet.cancelButtonIndex)
        [self endEditingModeAndRevertCompletion: actionSheet];
    else
        [self selectRowAtIndexPath: [NSIndexPath indexPathForRow: mostRecentSelectedRow inSection: 0]];
}


- (void)endEditingModeAndRevertCompletion: (id)sender
{
    self.navigationItem.leftBarButtonItem  = nil;
    self.navigationItem.rightBarButtonItem = editButton;

    self.tableView.allowsSelection = editing = NO;

    [self reloadStateFromEvent];

    for (int i = 0; i <= 4; i++)
        [self reconfigureRow: i];

    [self createConsumptionRowWithAnimation: UITableViewRowAnimationFade];
}


- (void)endEditingModeAndRevertSheet: (id)sender
{
    [self.editingTextField resignFirstResponder];
    self.editingTextField = nil;

    if (dataChanged)
    {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle: _I18N (@"Revert Changes for Event?")
                                                           delegate: self
                                                  cancelButtonTitle: _I18N (@"Cancel")
                                             destructiveButtonTitle: _I18N (@"Revert")
                                                  otherButtonTitles: nil];

        sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;

        [sheet showFromTabBar: self.tabBarController.tabBar];
    }
    else
        [self endEditingModeAndRevertCompletion: sender];
}


- (IBAction)endEditingModeAndRevert: (id)sender
{
    // Remember currently selected row in case the action shhet gets canceled
    mostRecentSelectedRow = [self.tableView indexPathForSelectedRow].row;

    [self dismissKeyboardWithCompletion: ^{ [self endEditingModeAndRevertSheet: self]; }];
}



#pragma mark -
#pragma mark Programatically Selecting Table Rows



- (void)selectRowAtIndexPath: (NSIndexPath*)path
{
    if (path)
    {
        [self.tableView selectRowAtIndexPath: path animated: NO scrollPosition: UITableViewScrollPositionNone];
        [self tableView: self.tableView didSelectRowAtIndexPath: path];
    }
}



#pragma mark -
#pragma mark Creating the Table Rows



- (void)createConsumptionRowWithAnimation: (UITableViewRowAnimation)animation;
{
    // Don't add the section when no value can be computed
    NSDecimalNumber *zero = [NSDecimalNumber zero];

    if (! ([distance compare: zero] == NSOrderedDescending && [fuelVolume compare: zero] == NSOrderedDescending))
        return;

    // Conversion units
    KSDistance        odometerUnit    = [[self.car valueForKey: @"odometerUnit"]        integerValue];
    KSVolume          fuelUnit        = [[self.car valueForKey: @"fuelUnit"]            integerValue];
    KSFuelConsumption consumptionUnit = [[self.car valueForKey: @"fuelConsumptionUnit"] integerValue];

    // Compute the average consumption
    NSDecimalNumber *cost = [fuelVolume decimalNumberByMultiplyingBy: price];

    NSDecimalNumber *liters      = [AppDelegate litersForVolume: fuelVolume withUnit: fuelUnit];
    NSDecimalNumber *kilometers  = [AppDelegate kilometersForDistance: distance withUnit: odometerUnit];
    NSDecimalNumber *consumption = [AppDelegate consumptionForKilometers: kilometers Liters: liters inUnit: consumptionUnit];

    NSString *consumptionString = [NSString stringWithFormat: @"%@ %@ %@ %@",
                                      [[AppDelegate sharedCurrencyFormatter]   stringFromNumber: cost],
                                      _I18N (@"/"),
                                      [[AppDelegate sharedFuelVolumeFormatter] stringFromNumber: consumption],
                                      [AppDelegate consumptionUnitString: consumptionUnit]];

    // Substrings for highlighting
    NSArray *highlightStrings = [NSArray arrayWithObjects:
                                    [[AppDelegate sharedCurrencyFormatter] currencySymbol],
                                    [AppDelegate consumptionUnitString: consumptionUnit],
                                    nil];

    [self addSectionAtIndex: 1 withAnimation: animation];

    [self addRowAtIndex: 0
              inSection: 1
              cellClass: [ConsumptionTableCell class]
               cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                            consumptionString,  @"label",
                            highlightStrings,   @"highlightStrings",
                            nil]
          withAnimation: animation];
}


- (void)createTableContentsWithAnimation: (UITableViewRowAnimation)animation
{
    [self addSectionAtIndex: 0 withAnimation: animation];

    [self addRowAtIndex: 0
              inSection: 0
              cellClass: [DateEditTableCell class]
               cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                            _I18N (@"Date"),                       @"label",
                            [AppDelegate sharedDateTimeFormatter], @"formatter",
                            @"date",                               @"valueIdentifier",
                            nil]
          withAnimation: animation];

    KSDistance odometerUnit = [[self.car valueForKey: @"odometerUnit"] integerValue];

    [self addRowAtIndex: 1
              inSection: 0
              cellClass: [NumberEditTableCell class]
               cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                            _I18N (@"Distance"),                                                            @"label",
                            [@" " stringByAppendingString: [AppDelegate odometerUnitString: odometerUnit]], @"suffix",
                            [AppDelegate sharedDistanceFormatter],                                          @"formatter",
                            @"distance",                                                                    @"valueIdentifier",
                            nil]
          withAnimation: animation];

    KSVolume fuelUnit = [[self.car valueForKey: @"fuelUnit"] integerValue];

    [self addRowAtIndex: 2
              inSection: 0
              cellClass: [NumberEditTableCell class]
               cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                            [AppDelegate fuelPriceUnitDescription: fuelUnit], @"label",
                            [AppDelegate sharedEditPreciseCurrencyFormatter], @"formatter",
                            [AppDelegate sharedPreciseCurrencyFormatter],           @"alternateFormatter",
                            price,                                            @"value",
                            @"price",                                         @"valueIdentifier",
                            nil]
          withAnimation: animation];

    [self addRowAtIndex: 3
              inSection: 0
              cellClass: [NumberEditTableCell class]
               cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                            [AppDelegate fuelUnitDescription: fuelUnit discernGallons: NO],         @"label",
                            [@" " stringByAppendingString: [AppDelegate fuelUnitString: fuelUnit]], @"suffix",
                            [AppDelegate sharedFuelVolumeFormatter],                                @"formatter",
                            @"fuelVolume",                                                          @"valueIdentifier",
                            nil]
          withAnimation: animation];

    [self addRowAtIndex: 4
              inSection: 0
              cellClass: [SwitchTableCell class]
               cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                            _I18N (@"Full Fill-Up"), @"label",
                            @"filledUp",             @"valueIdentifier",
                            nil]
          withAnimation: animation];

    [self createConsumptionRowWithAnimation: animation];
}



#pragma mark -
#pragma mark Updating the Table Rows



- (void)recreateTableContentsWithAnimation: (UITableViewRowAnimation)animation
{
    [self removeAllSectionsWithAnimation:   UITableViewRowAnimationNone];
    [self createTableContentsWithAnimation: UITableViewRowAnimationNone];
    [self.tableView reloadData];
}


- (void)localeChangedCompletion: (id)previousSelection
{
    [self.editingTextField resignFirstResponder];
    self.editingTextField = nil;

    [self recreateTableContentsWithAnimation: UITableViewRowAnimationNone];
    [self selectRowAtIndexPath: previousSelection];
}


- (void)localeChanged: (id)object
{
    NSIndexPath *path = [self.tableView indexPathForSelectedRow];

    if (path)
        [self dismissKeyboardWithCompletion: ^{ [self localeChangedCompletion: path ]; }];
    else
        [self localeChangedCompletion: path];
}



#pragma mark -
#pragma mark Dismissing the Keyboard



- (void)dismissKeyboardWithCompletion: (void (^)(void))completion
{
    BOOL scrollToTop = (self.tableView.contentOffset.y > 0.0);

    [UIView animateWithDuration: scrollToTop ? 0.2 : 0.1
                     animations: ^{

                         // Deselect row and scroll table to the top
                         [self.tableView deselectRowAtIndexPath: [self.tableView indexPathForSelectedRow] animated: NO];

                         if (scrollToTop)
                             [self.tableView scrollToRowAtIndexPath: [NSIndexPath indexPathForRow: 0 inSection: 0]
                                                   atScrollPosition: UITableViewScrollPositionTop
                                                           animated: NO];
                     }
                     completion: ^(BOOL finished){

                         completion ();
                     }];
}



#pragma mark -
#pragma mark EditablePageCellDelegate



- (id)valueForIdentifier: (NSString*)valueIdentifier
{
    if ([valueIdentifier isEqualToString: @"date"])
        return date;

    else if ([valueIdentifier isEqualToString: @"distance"])
        return distance;

    else if ([valueIdentifier isEqualToString: @"price"])
        return price;

    else if ([valueIdentifier isEqualToString: @"fuelVolume"])
        return fuelVolume;

    else if ([valueIdentifier isEqualToString: @"filledUp"])
        return [NSNumber numberWithBool: filledUp];

    else if ([valueIdentifier isEqualToString: @"showValueLabel"])
        return [NSNumber numberWithBool: !editing];

    return nil;
}


- (void)valueChanged: (id)newValue identifier: (NSString*)valueIdentifier
{
    if ([valueIdentifier isEqualToString: @"date"])
    {
        NSDate *newDate = [AppDelegate dateWithoutSeconds: (NSDate*)newValue];

        if (! [self.date isEqualToDate: newDate])
        {
            self.date   = newDate;
            dataChanged = YES;
        }
    }

    else if ([newValue isKindOfClass: [NSDecimalNumber class]])
    {
        NSDecimalNumber *newNumber = (NSDecimalNumber*)newValue;

        if ([valueIdentifier isEqualToString: @"distance"])
        {
            if ([self.distance compare: newNumber] != NSOrderedSame)
            {
                self.distance = newNumber;
                dataChanged   = YES;
            }
        }
        else if ([valueIdentifier isEqualToString: @"price"])
        {
            if ([self.price compare: newNumber] != NSOrderedSame)
            {
                self.price  = newNumber;
                dataChanged = YES;
            }
        }
        else if ([valueIdentifier isEqualToString: @"fuelVolume"])
        {
            if ([self.fuelVolume compare: newNumber] != NSOrderedSame)
            {
                self.fuelVolume = newNumber;
                dataChanged     = YES;
            }
        }
    }

    else if ([valueIdentifier isEqualToString: @"filledUp"])
    {
        BOOL newBoolValue = [newValue boolValue];

        if (self.filledUp != newBoolValue)
        {
            self.filledUp = newBoolValue;
            dataChanged   = YES;
        }
    }

    // Validation of Done-Button
    BOOL canBeSaved = YES;

    NSDecimalNumber *zero = [NSDecimalNumber zero];

    if (! ([distance compare: zero] == NSOrderedDescending && [fuelVolume compare: zero] == NSOrderedDescending))
    {
        canBeSaved = NO;
    }
    else if (! [self.date isEqualToDate: [self.event valueForKey: @"timestamp"]])
    {
        if ([AppDelegate managedObjectContext: managedObjectContext
                         containsEventWithCar: self.car
                                      andDate: self.date])
            canBeSaved = NO;
    }

    doneButton.enabled = canBeSaved;
}


- (BOOL)valueValid: (id)newValue identifier: (NSString*)valueIdentifier
{
    // Date must be collision free
    if ([newValue isKindOfClass: [NSDate class]])
        if ([valueIdentifier isEqualToString: @"date"])
            if (! [self.date isEqualToDate: [self.event valueForKey: @"timestamp"]])
                if ([AppDelegate managedObjectContext: self.managedObjectContext containsEventWithCar: self.car andDate: (NSDate*)newValue] == YES)
                    return NO;

    // DecimalNumbers <= 0.0 are invalid
    if ([newValue isKindOfClass: [NSDecimalNumber class]])
        if (![valueIdentifier isEqualToString: @"price"])
            if ([(NSDecimalNumber*)newValue compare: [NSDecimalNumber zero]] != NSOrderedDescending)
                return NO;

    return YES;
}


#pragma mark -
#pragma mark UITableViewDataSource



- (NSString*)tableView: (UITableView*)aTableView titleForHeaderInSection: (NSInteger)section
{
	return nil;
}



#pragma mark -
#pragma mark UITableViewDelegate



// Don't activate rows with a UISwitch
- (NSIndexPath*)tableView: (UITableView*)tableView willSelectRowAtIndexPath: (NSIndexPath*)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath: indexPath];

    if ([cell isKindOfClass: [SwitchTableCell class]])
        return nil;
    else
        return indexPath;
}



// Activate edit fields for selected rows, track the currently active textfield
- (void)tableView: (UITableView*)tableView didSelectRowAtIndexPath: (NSIndexPath*)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath: indexPath];


    if ([cell isKindOfClass: [DateEditTableCell class]])
        self.editingTextField = [(DateEditTableCell*)cell textField];

    else if ([cell isKindOfClass: [NumberEditTableCell class]])
        self.editingTextField = [(NumberEditTableCell*)cell textField];

    else
        self.editingTextField = nil;


    if (self.editingTextField)
    {
        void (^selectCompletion)(BOOL) = ^(BOOL finished){

            self.navigationItem.leftBarButtonItem  = doneButton;
            self.navigationItem.rightBarButtonItem = cancelButton;

            // Enable user inputs for textfield in selected cell and show keyboard
            self.editingTextField.userInteractionEnabled = YES;
            [self.editingTextField becomeFirstResponder];

            // Scroll selected cell into middle of screen
            [tableView scrollToRowAtIndexPath: indexPath
                             atScrollPosition: UITableViewScrollPositionMiddle
                                     animated: YES];
        };

        if ([self.tableView numberOfSections] == 2)
            [UIView animateWithDuration: 0.3
                             animations: ^{ [self removeSectionAtIndex: 1 withAnimation: UITableViewRowAnimationFade]; }
                             completion: selectCompletion];
        else
            selectCompletion (YES);
    }
    else
    {
        [tableView deselectRowAtIndexPath: indexPath animated: NO];
    }
}

@end
