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

#import "NSDate+Kraftstoff.h"


@implementation FuelEventEditorController

@synthesize managedObjectContext;

@synthesize event;
@synthesize car;
@synthesize date;
@synthesize distance;
@synthesize price;
@synthesize fuelVolume;
@synthesize filledUp;

@synthesize editButton;
@synthesize cancelButton;
@synthesize doneButton;



#pragma mark -
#pragma mark View Lifecycle



- (id)initWithNibName: (NSString*)nibName bundle: (NSBundle*)nibBundle
{
    if ((self = [super initWithNibName: nibName bundle: nibBundle]))
    {
        if ([self respondsToSelector: @selector (restorationIdentifier)])
        {
            self.restorationIdentifier = @"FuelEventEditor";
            self.restorationClass = [self class];
        }
    }

    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];


    // Title bar
    self.editButton   = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemEdit
                                                                       target: self
                                                                       action: @selector (enterEditingMode:)];

    self.doneButton   = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone
                                                                       target: self
                                                                       action: @selector (endEditingModeAndSave:)];

    self.cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemStop
                                                                       target: self
                                                                       action: @selector (endEditingModeAndRevert:)];

    self.title = [[AppDelegate sharedDateFormatter] stringFromDate: [event valueForKey: @"timestamp"]];
    self.navigationItem.rightBarButtonItem = self.editButton;


    // Pre-iOS6: add shadow layer onto the background image view
    if ([AppDelegate isRunningOS6] == NO)
    {
        UIView *imageView = [self.view viewWithTag: 100];

        [imageView.layer
            insertSublayer: [AppDelegate shadowWithFrame: CGRectMake (0.0, 0.0, imageView.frame.size.width, NavBarShadowHeight)
                                              darkFactor: 0.5
                                             lightFactor: 150.0 / 255.0
                                           fadeDownwards: YES]
                   atIndex: 0];
    }

    self.tableView.backgroundView = nil;

    
    // Table contents
    self.constantRowHeight = NO;
    self.tableView.allowsSelection = NO;

    [self createTableContentsWithAnimation: UITableViewRowAnimationNone];
    [self.tableView reloadData];

    
    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector (localeChanged:)
               name: NSCurrentLocaleDidChangeNotification
             object: nil];
}



- (void)viewDidAppear: (BOOL)animated
{
    [super viewDidAppear: animated];
    
    NSString *imageName = [AppDelegate isIPhone5] ? @"TablePattern-568h" : @"TablePattern";
    
    [[AppDelegate sharedDelegate]
     setWindowBackground: [[UIImage imageNamed: imageName] resizableImageWithCapInsets: UIEdgeInsetsZero]
     animated: animated];
}


- (void)viewWillDisappear: (BOOL)animated
{
    [super viewWillDisappear: animated];
    
    NSString *imageName = [AppDelegate isIPhone5] ? @"TableBackground-568h" : @"TableBackground";
    
    [[AppDelegate sharedDelegate]
     setWindowBackground: [UIImage imageNamed: imageName]
     animated: animated];
}



#pragma mark -
#pragma mark iOS 6 State Restoration



#define kSRFuelEventCancelSheet     @"FuelEventCancelSheet"
#define kSRFuelEventDataChanged     @"FuelEventDataChanged"
#define kSRFuelEventSelectionIndex  @"FuelEventMostSelectionIndex"
#define kSRFuelEventEventID         @"FuelEventEventID"
#define kSRFuelEventCarID           @"FuelEventCarID"
#define kSRFuelEventDate            @"FuelEventDate"
#define kSRFuelEventDistance        @"FuelEventDistance"
#define kSRFuelEventPrice           @"FuelEventPrice"
#define kSRFuelEventVolume          @"FuelEventVolume "
#define kSRFuelEventFilledUp        @"FuelEventFilledUp"
#define kSRFuelEventEditing         @"FuelEventEditing"


+ (UIViewController*) viewControllerWithRestorationIdentifierPath: (NSArray *)identifierComponents coder: (NSCoder*)coder
{
    AppDelegate *appDelegate = [AppDelegate sharedDelegate];

    FuelEventEditorController *controller = [[self alloc] initWithNibName: @"FuelEventEditor" bundle: nil];

    controller.managedObjectContext = [appDelegate managedObjectContext];
    controller.event                = [appDelegate managedObjectForModelIdentifier: [coder decodeObjectForKey: kSRFuelEventEventID]];

    if (controller.event == nil)
        return nil;

    return controller;
}


- (void)encodeRestorableStateWithCoder: (NSCoder*)coder
{
    AppDelegate *appDelegate = [AppDelegate sharedDelegate];

    NSIndexPath *indexPath = (isShowingCancelSheet) ? restoredSelectionIndex : [self.tableView indexPathForSelectedRow];

    [coder encodeBool: isShowingCancelSheet forKey: kSRFuelEventCancelSheet];
    [coder encodeBool: dataChanged forKey: kSRFuelEventDataChanged];
    [coder encodeObject: indexPath forKey: kSRFuelEventSelectionIndex];
    [coder encodeObject: [appDelegate modelIdentifierForManagedObject: event] forKey: kSRFuelEventEventID];
    [coder encodeObject: [appDelegate modelIdentifierForManagedObject: car] forKey: kSRFuelEventCarID];
    [coder encodeObject: date forKey: kSRFuelEventDate];
    [coder encodeObject: distance forKey: kSRFuelEventDistance];
    [coder encodeObject: price forKey: kSRFuelEventPrice];
    [coder encodeObject: fuelVolume forKey: kSRFuelEventVolume];
    [coder encodeBool: filledUp forKey: kSRFuelEventFilledUp];
    [coder encodeBool: self.editing forKey: kSRFuelEventEditing];

    [super encodeRestorableStateWithCoder: coder];
}


- (void)decodeRestorableStateWithCoder: (NSCoder*)coder
{
    AppDelegate *appDelegate = [AppDelegate sharedDelegate];

    isShowingCancelSheet   = [coder decodeBoolForKey: kSRFuelEventCancelSheet];
    dataChanged            = [coder decodeBoolForKey: kSRFuelEventDataChanged];
    restoredSelectionIndex = [coder decodeObjectForKey: kSRFuelEventSelectionIndex];
    car                    = [appDelegate managedObjectForModelIdentifier: [coder decodeObjectForKey: kSRFuelEventCarID]];
    date                   = [coder decodeObjectForKey: kSRFuelEventDate];
    distance               = [coder decodeObjectForKey: kSRFuelEventDistance];
    price                  = [coder decodeObjectForKey: kSRFuelEventPrice];
    fuelVolume             = [coder decodeObjectForKey: kSRFuelEventVolume];
    filledUp               = [coder decodeBoolForKey: kSRFuelEventFilledUp];
    
    if ([coder decodeBoolForKey: kSRFuelEventEditing])
    {
        [self setEditing: YES animated: NO];
            
        if (isShowingCancelSheet)
        {
            [self showRevertActionSheet];
        }
        else
        {
            [self selectRowAtIndexPath: restoredSelectionIndex];
            restoredSelectionIndex = nil;
        }
    }

    [super decodeRestorableStateWithCoder: coder];
}



#pragma mark -
#pragma mark Saving and Restoring the Fuel Event



- (void)saveStateToEvent
{
    if (dataChanged)
    {
        dataChanged = NO;

        // Remove event from database
        [AppDelegate removeEventFromArchive: self.event
                     inManagedObjectContext: managedObjectContext
                        forceOdometerUpdate: YES];

        // Reinsert new version of event
        self.event = [AppDelegate addToArchiveWithCar: car
                                                 date: date
                                             distance: distance
                                                price: price
                                           fuelVolume: fuelVolume
                                             filledUp: filledUp
                               inManagedObjectContext: managedObjectContext
                                  forceOdometerUpdate: YES];
        
        [[AppDelegate sharedDelegate] saveContext: self.managedObjectContext];
    }
}


- (void)restoreStateFromEvent
{
    self.car = [event valueForKey: @"car"];

    KSDistance odometerUnit = [[car valueForKey: @"odometerUnit"] integerValue];
    KSVolume   fuelUnit     = [[car valueForKey: @"fuelUnit"]     integerValue];
    
    self.title      = [[AppDelegate sharedDateFormatter] stringFromDate: [event valueForKey: @"timestamp"]];
    self.date       = [event valueForKey: @"timestamp"];
    self.distance   = [AppDelegate distanceForKilometers: [event valueForKey: @"distance"] withUnit: odometerUnit];
    self.price      = [AppDelegate pricePerUnit: [event valueForKey: @"price"] withUnit: fuelUnit];
    self.fuelVolume = [AppDelegate volumeForLiters: [event valueForKey: @"fuelVolume"] withUnit: fuelUnit];
    self.filledUp   = [[event valueForKey: @"filledUp"] boolValue];

    dataChanged = NO;
}


- (void)setEvent: (NSManagedObject*)newEvent
{
    if (event != newEvent)
    {
        event = newEvent;

        [self restoreStateFromEvent];
    }
}



#pragma mark -
#pragma mark Modeswitching for Table Rows



- (void)reconfigureRowAtIndexPath: (NSIndexPath*)indexPath
{
    PageCell *cell = (PageCell*)[self.tableView cellForRowAtIndexPath: indexPath];
    
    if (cell)
    {
        [cell configureForData: [self dataForRow: indexPath.row inSection: 0]
                viewController: self
                     tableView: self.tableView
                     indexPath: indexPath];
        
        [cell setNeedsDisplay];
    }
}


- (void)setEditing: (BOOL)enabled animated: (BOOL)animated
{
    if (self.editing != enabled)
    {
        UITableViewRowAnimation animation = (animated) ? UITableViewRowAnimationFade : UITableViewRowAnimationNone;
        
        [super setEditing: enabled animated: animated];
        
        if (enabled)
        {
            self.navigationItem.leftBarButtonItem  = doneButton;
            self.navigationItem.rightBarButtonItem = cancelButton;
            
            [self removeSectionAtIndex: 1 withAnimation: animation];
        }
        else
        {
            self.navigationItem.leftBarButtonItem  = nil;
            self.navigationItem.rightBarButtonItem = editButton;
            
            [self createConsumptionRowWithAnimation: animation];
        }
        
        if (animated)
        {
            for (int row = 0; row <= 4; row++)
                [self reconfigureRowAtIndexPath: [NSIndexPath indexPathForRow: row inSection: 0]];
        }
        else
        {
            [self.tableView reloadData];
        }

        self.tableView.allowsSelection = enabled;
    }
}



#pragma mark -
#pragma mark Entering Editing Mode



- (IBAction)enterEditingMode: (id)sender
{
    [self setEditing: YES animated: YES];
    [self selectRowAtIndexPath: [NSIndexPath indexPathForRow: 0 inSection: 0]];
}



#pragma mark -
#pragma mark Saving Edited Data



- (IBAction)endEditingModeAndSave: (id)sender
{
    [self dismissKeyboardWithCompletion: ^{

        [self saveStateToEvent];        
        [self setEditing: NO animated: YES];
    }];
}



#pragma mark -
#pragma mark Aborting Editing Mode



- (IBAction)endEditingModeAndRevert: (id)sender
{
    restoredSelectionIndex = [self.tableView indexPathForSelectedRow];
    
    [self dismissKeyboardWithCompletion: ^{

        if (dataChanged)
            [self showRevertActionSheet];
        else
            [self endEditingModeAndRevertCompletion];    
    }];
}


- (void)showRevertActionSheet
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle: _I18N (@"Revert Changes for Event?")
                                                       delegate: self
                                              cancelButtonTitle: _I18N (@"Cancel")
                                         destructiveButtonTitle: _I18N (@"Revert")
                                              otherButtonTitles: nil];
    
    sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    
    isShowingCancelSheet = YES;
    [sheet showFromTabBar: self.tabBarController.tabBar];
}


- (void)actionSheet: (UIActionSheet*)actionSheet clickedButtonAtIndex: (NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex)
        [self selectRowAtIndexPath: restoredSelectionIndex];
    else
        [self endEditingModeAndRevertCompletion];
 
    isShowingCancelSheet   = NO;
    restoredSelectionIndex = nil;
}


- (void)endEditingModeAndRevertCompletion
{
    [self restoreStateFromEvent];
    [self setEditing: NO animated: YES];    

    restoredSelectionIndex = nil;
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
    NSArray *highlightStrings = @[[[AppDelegate sharedCurrencyFormatter] currencySymbol],
                                  [AppDelegate consumptionUnitString: consumptionUnit]];

    [self addSectionAtIndex: 1 withAnimation: animation];

    [self addRowAtIndex: 0
              inSection: 1
              cellClass: [ConsumptionTableCell class]
               cellData: @{@"label":            consumptionString,
                           @"highlightStrings": highlightStrings}
          withAnimation: animation];
}


- (void)createTableContentsWithAnimation: (UITableViewRowAnimation)animation
{
    [self addSectionAtIndex: 0 withAnimation: animation];

    [self addRowAtIndex: 0
              inSection: 0
              cellClass: [DateEditTableCell class]
               cellData: @{@"label":           _I18N (@"Date"),
                           @"formatter":       [AppDelegate sharedDateTimeFormatter],
                           @"valueIdentifier": @"date"}
          withAnimation: animation];

    KSDistance odometerUnit = [[self.car valueForKey: @"odometerUnit"] integerValue];

    [self addRowAtIndex: 1
              inSection: 0
              cellClass: [NumberEditTableCell class]
               cellData: @{@"label":           _I18N (@"Distance"),
                           @"suffix":          [@" " stringByAppendingString: [AppDelegate odometerUnitString: odometerUnit]],
                           @"formatter":       [AppDelegate sharedDistanceFormatter],
                           @"valueIdentifier": @"distance"}
          withAnimation: animation];

    KSVolume fuelUnit = [[self.car valueForKey: @"fuelUnit"] integerValue];

    [self addRowAtIndex: 2
              inSection: 0
              cellClass: [NumberEditTableCell class]
               cellData: @{@"label":              [AppDelegate fuelPriceUnitDescription: fuelUnit],
                           @"formatter":          [AppDelegate sharedEditPreciseCurrencyFormatter],
                           @"alternateFormatter": [AppDelegate sharedPreciseCurrencyFormatter],
                           @"valueIdentifier":    @"price"}
          withAnimation: animation];

    [self addRowAtIndex: 3
              inSection: 0
              cellClass: [NumberEditTableCell class]
               cellData: @{@"label":           [AppDelegate fuelUnitDescription: fuelUnit discernGallons: NO pluralization: YES],
                           @"suffix":          [@" " stringByAppendingString: [AppDelegate fuelUnitString: fuelUnit]],
                           @"formatter":       KSVolumeIsMetric (fuelUnit)
                                                    ? [AppDelegate sharedFuelVolumeFormatter]
                                                    : [AppDelegate sharedPreciseFuelVolumeFormatter],
                           @"valueIdentifier": @"fuelVolume"}
          withAnimation: animation];

    [self addRowAtIndex: 4
              inSection: 0
              cellClass: [SwitchTableCell class]
               cellData: @{@"label":           _I18N (@"Full Fill-Up"),
                           @"valueIdentifier": @"filledUp"}
          withAnimation: animation];

    if (!self.editing)
        [self createConsumptionRowWithAnimation: animation];
}



#pragma mark -
#pragma mark Locale Handling



- (void)localeChanged: (id)object
{
    NSIndexPath *previousSelection = [self.tableView indexPathForSelectedRow];
    
    [self dismissKeyboardWithCompletion: ^{
        
        [self removeAllSectionsWithAnimation:   UITableViewRowAnimationNone];
        [self createTableContentsWithAnimation: UITableViewRowAnimationNone];
        [self.tableView reloadData];
        
        [self selectRowAtIndexPath: previousSelection];
    }];
}



#pragma mark -
#pragma mark Programatically Selecting Table Rows



- (void)activateTextFieldAtIndexPath: (NSIndexPath*)indexPath
{
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath: indexPath];
    UITextField *field = nil;
    
    if ([cell isKindOfClass: [DateEditTableCell class]])
        field = [(DateEditTableCell*)cell textField];
    
    else if ([cell isKindOfClass: [NumberEditTableCell class]])
        field = [(NumberEditTableCell*)cell textField];
    
    field.userInteractionEnabled = YES;
    [field becomeFirstResponder];
}


- (void)selectRowAtIndexPath: (NSIndexPath*)path
{
    if (path)
    {
        [self.tableView selectRowAtIndexPath: path animated: NO scrollPosition: UITableViewScrollPositionNone];
        [self tableView: self.tableView didSelectRowAtIndexPath: path];
    }
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
        return @(filledUp);

    else if ([valueIdentifier isEqualToString: @"showValueLabel"])
        return @(!(BOOL)self.editing);

    return nil;
}


- (void)valueChanged: (id)newValue identifier: (NSString*)valueIdentifier
{
    if ([valueIdentifier isEqualToString: @"date"])
    {
        NSDate *newDate = [NSDate dateWithoutSeconds: (NSDate*)newValue];

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



- (NSIndexPath*)tableView: (UITableView*)tableView willSelectRowAtIndexPath: (NSIndexPath*)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath: indexPath];

    if ([cell isKindOfClass: [SwitchTableCell class]] || [cell isKindOfClass: [ConsumptionTableCell class]])
        return nil;
    else
        return indexPath;
}


- (void)tableView: (UITableView*)tableView didSelectRowAtIndexPath: (NSIndexPath*)indexPath
{
    [self activateTextFieldAtIndexPath: indexPath];

    [tableView scrollToRowAtIndexPath: indexPath
                     atScrollPosition: UITableViewScrollPositionMiddle
                             animated: YES];
}



#pragma mark -
#pragma mark Memory Management



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    self.editButton   = nil;
    self.cancelButton = nil;
    self.doneButton   = nil;

    [[NSNotificationCenter defaultCenter] removeObserver: self];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

@end
