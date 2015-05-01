// FuelEventEditorController.h
//
// Kraftstoff


#import "AppDelegate.h"
#import "FuelEventEditorController.h"
#import "FuelEventController.h"
#import "CarTableCell.h"
#import "ConsumptionTableCell.h"
#import "DateEditTableCell.h"
#import "NumberEditTableCell.h"
#import "SwitchTableCell.h"
#import "kraftstoff-Swift.h"


@implementation FuelEventEditorController
{
    BOOL isShowingCancelSheet;
    BOOL dataChanged;
    NSIndexPath *restoredSelectionIndex;
}



#pragma mark -
#pragma mark View Lifecycle


- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) {
		self.restorationClass = [self class];
	}
	return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Title bar
    _editButton   = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(enterEditingMode:)];
    _doneButton   = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(endEditingModeAndSave:)];
    _cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(endEditingModeAndRevert:)];

    self.title = [[AppDelegate sharedDateFormatter] stringFromDate:[_event valueForKey:@"timestamp"]];
    self.navigationItem.rightBarButtonItem = _editButton;

    // Remove tint from bavigation bar
    self.navigationController.navigationBar.tintColor = nil;

    // Table contents
    self.constantRowHeight = NO;
    self.tableView.allowsSelection = NO;

    [self createTableContentsWithAnimation:UITableViewRowAnimationNone];
    [self.tableView reloadData];
    
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(localeChanged:)
               name:NSCurrentLocaleDidChangeNotification
             object:nil];
}



#pragma mark -
#pragma mark State Restoration



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


+ (UIViewController*) viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

	UIStoryboard *storyboard = [coder decodeObjectForKey:UIStateRestorationViewControllerStoryboardKey];
    FuelEventEditorController *controller = [storyboard instantiateViewControllerWithIdentifier:@"FuelEventEditor"];
    controller.managedObjectContext = [appDelegate managedObjectContext];
    controller.event                = [appDelegate managedObjectForModelIdentifier:[coder decodeObjectForKey:kSRFuelEventEventID]];

    if (controller.event == nil)
        return nil;

    return controller;
}


- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    NSIndexPath *indexPath = (isShowingCancelSheet) ? restoredSelectionIndex : [self.tableView indexPathForSelectedRow];

    [coder encodeBool:isShowingCancelSheet forKey:kSRFuelEventCancelSheet];
    [coder encodeBool:dataChanged forKey:kSRFuelEventDataChanged];
    [coder encodeObject:indexPath forKey:kSRFuelEventSelectionIndex];
    [coder encodeObject:[appDelegate modelIdentifierForManagedObject:_event] forKey:kSRFuelEventEventID];
    [coder encodeObject:[appDelegate modelIdentifierForManagedObject:_car] forKey:kSRFuelEventCarID];
    [coder encodeObject:_date forKey:kSRFuelEventDate];
    [coder encodeObject:_distance forKey:kSRFuelEventDistance];
    [coder encodeObject:_price forKey:kSRFuelEventPrice];
    [coder encodeObject:_fuelVolume forKey:kSRFuelEventVolume];
    [coder encodeBool:_filledUp forKey:kSRFuelEventFilledUp];
    [coder encodeBool:self.editing forKey:kSRFuelEventEditing];

    [super encodeRestorableStateWithCoder:coder];
}


- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    isShowingCancelSheet   = [coder decodeBoolForKey:kSRFuelEventCancelSheet];
    dataChanged            = [coder decodeBoolForKey:kSRFuelEventDataChanged];
    restoredSelectionIndex = [coder decodeObjectForKey:kSRFuelEventSelectionIndex];
    _car                   = [appDelegate managedObjectForModelIdentifier:[coder decodeObjectForKey:kSRFuelEventCarID]];
    _date                  = [coder decodeObjectForKey:kSRFuelEventDate];
    _distance              = [coder decodeObjectForKey:kSRFuelEventDistance];
    _price                 = [coder decodeObjectForKey:kSRFuelEventPrice];
    _fuelVolume            = [coder decodeObjectForKey:kSRFuelEventVolume];
    _filledUp              = [coder decodeBoolForKey:kSRFuelEventFilledUp];
    
    if ([coder decodeBoolForKey:kSRFuelEventEditing]) {
        [self setEditing:YES animated:NO];
            
        if (isShowingCancelSheet)
            [self showRevertActionSheet];
        else {
            [self selectRowAtIndexPath:restoredSelectionIndex];
            restoredSelectionIndex = nil;
        }
    }

    [super decodeRestorableStateWithCoder:coder];
}



#pragma mark -
#pragma mark Saving and Restoring the Fuel Event



- (void)saveStateToEvent
{
    if (dataChanged) {
        dataChanged = NO;

        // Remove event from database
        [AppDelegate removeEventFromArchive:_event
                     inManagedObjectContext:_managedObjectContext
                        forceOdometerUpdate:YES];

        // Reinsert new version of event
        _event = [AppDelegate addToArchiveWithCar:_car
                                             date:_date
                                         distance:_distance
                                            price:_price
                                       fuelVolume:_fuelVolume
                                         filledUp:_filledUp
                           inManagedObjectContext:_managedObjectContext
                              forceOdometerUpdate:YES];
        
        [(AppDelegate *)[[UIApplication sharedApplication] delegate] saveContext:_managedObjectContext];
    }
}


- (void)restoreStateFromEvent
{
    _car = [_event valueForKey:@"car"];

    KSDistance odometerUnit = (KSDistance)[[_car valueForKey:@"odometerUnit"] integerValue];
    KSVolume   fuelUnit     = (KSVolume)[[_car valueForKey:@"fuelUnit"]     integerValue];
    
    self.title  = [[AppDelegate sharedDateFormatter] stringFromDate:[_event valueForKey:@"timestamp"]];
    _date       = [_event valueForKey:@"timestamp"];
    _distance   = [AppDelegate distanceForKilometers:[_event valueForKey:@"distance"] withUnit:odometerUnit];
    _price      = [AppDelegate pricePerUnit:[_event valueForKey:@"price"] withUnit:fuelUnit];
    _fuelVolume = [AppDelegate volumeForLiters:[_event valueForKey:@"fuelVolume"] withUnit:fuelUnit];
    _filledUp   = [[_event valueForKey:@"filledUp"] boolValue];

    dataChanged = NO;
}


- (void)setEvent:(NSManagedObject *)newEvent
{
    if (_event != newEvent) {
        
        _event = newEvent;
        [self restoreStateFromEvent];
    }
}



#pragma mark -
#pragma mark Modeswitching for Table Rows



- (void)reconfigureRowAtIndexPath:(NSIndexPath *)indexPath
{
    PageCell *cell = (PageCell*)[self.tableView cellForRowAtIndexPath:indexPath];
    
    if (cell) {
        [cell configureForData:[self dataForRow:indexPath.row inSection:0]
                viewController:self
                     tableView:self.tableView
                     indexPath:indexPath];
        
        [cell setNeedsDisplay];
    }
}


- (void)setEditing:(BOOL)enabled animated:(BOOL)animated
{
    if (self.editing != enabled) {

        UITableViewRowAnimation animation = (animated) ? UITableViewRowAnimationFade : UITableViewRowAnimationNone;
        
        [super setEditing:enabled animated:animated];
        
        if (enabled) {
            self.navigationItem.leftBarButtonItem  = _doneButton;
            self.navigationItem.rightBarButtonItem = _cancelButton;
            
            [self removeSectionAtIndex:1 withAnimation:animation];
            
        } else {
            self.navigationItem.leftBarButtonItem  = nil;
            self.navigationItem.rightBarButtonItem = _editButton;
            
            [self createConsumptionRowWithAnimation:animation];
        }
        
        if (animated) {
            for (int row = 0; row <= 4; row++)
                [self reconfigureRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
            
        } else {
            [self.tableView reloadData];
        }

        self.tableView.allowsSelection = enabled;
    }
}



#pragma mark -
#pragma mark Entering Editing Mode



- (IBAction)enterEditingMode:(id)sender
{
    [self setEditing:YES animated:YES];
    [self selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
}



#pragma mark -
#pragma mark Saving Edited Data



- (IBAction)endEditingModeAndSave:(id)sender
{
    [self dismissKeyboardWithCompletion: ^{

        [self saveStateToEvent];        
        [self setEditing:NO animated:YES];
    }];
}



#pragma mark -
#pragma mark Aborting Editing Mode



- (IBAction)endEditingModeAndRevert:(id)sender
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
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Revert Changes for Event?", @"")
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                         destructiveButtonTitle:NSLocalizedString(@"Revert", @"")
                                              otherButtonTitles:nil];
    
    sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    
    isShowingCancelSheet = YES;
    [sheet showFromTabBar:self.tabBarController.tabBar];
}


- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex)
        [self selectRowAtIndexPath:restoredSelectionIndex];
    else
        [self endEditingModeAndRevertCompletion];
 
    isShowingCancelSheet   = NO;
    restoredSelectionIndex = nil;
}


- (void)endEditingModeAndRevertCompletion
{
    [self restoreStateFromEvent];
    [self setEditing:NO animated:YES];    

    restoredSelectionIndex = nil;
}



#pragma mark -
#pragma mark Creating the Table Rows



- (void)createConsumptionRowWithAnimation:(UITableViewRowAnimation)animation;
{
    // Don't add the section when no value can be computed
    NSDecimalNumber *zero = [NSDecimalNumber zero];

    if (! ([_distance compare:zero] == NSOrderedDescending && [_fuelVolume compare:zero] == NSOrderedDescending))
        return;

    // Conversion units
    KSDistance        odometerUnit    = (KSDistance)[[_car valueForKey:@"odometerUnit"] integerValue];
    KSVolume          fuelUnit        = (KSVolume)[[_car valueForKey:@"fuelUnit"] integerValue];
    KSFuelConsumption consumptionUnit = (KSFuelConsumption)[[_car valueForKey:@"fuelConsumptionUnit"] integerValue];

    // Compute the average consumption
    NSDecimalNumber *cost = [_fuelVolume decimalNumberByMultiplyingBy:_price];

    NSDecimalNumber *liters      = [AppDelegate litersForVolume:_fuelVolume withUnit:fuelUnit];
    NSDecimalNumber *kilometers  = [AppDelegate kilometersForDistance:_distance withUnit:odometerUnit];
    NSDecimalNumber *consumption = [AppDelegate consumptionForKilometers:kilometers Liters:liters inUnit:consumptionUnit];

    NSString *consumptionString = [NSString stringWithFormat:@"%@ %@ %@ %@",
                                      [[AppDelegate sharedCurrencyFormatter]   stringFromNumber:cost],
                                      NSLocalizedString(@"/", @""),
                                      [[AppDelegate sharedFuelVolumeFormatter] stringFromNumber:consumption],
                                      [AppDelegate consumptionUnitString:consumptionUnit]];

    // Substrings for highlighting
    NSArray *highlightStrings = @[[[AppDelegate sharedCurrencyFormatter] currencySymbol],
                                  [AppDelegate consumptionUnitString:consumptionUnit]];

    [self addSectionAtIndex:1 withAnimation:animation];

    [self addRowAtIndex:0
              inSection:1
              cellClass:[ConsumptionTableCell class]
               cellData:@{@"label":            consumptionString,
                          @"highlightStrings":highlightStrings}
          withAnimation:animation];
}


- (void)createTableContentsWithAnimation:(UITableViewRowAnimation)animation
{
    [self addSectionAtIndex:0 withAnimation:animation];

    [self addRowAtIndex:0
              inSection:0
              cellClass:[DateEditTableCell class]
               cellData:@{@"label": NSLocalizedString(@"Date", @""),
                          @"formatter": [AppDelegate sharedDateTimeFormatter],
                          @"valueIdentifier": @"date"}
          withAnimation:animation];

    KSDistance odometerUnit = (KSDistance)[[_car valueForKey:@"odometerUnit"] integerValue];

    [self addRowAtIndex:1
              inSection:0
              cellClass:[NumberEditTableCell class]
               cellData:@{@"label": NSLocalizedString(@"Distance", @""),
                          @"suffix": [@" " stringByAppendingString:[AppDelegate odometerUnitString:odometerUnit]],
                          @"formatter": [AppDelegate sharedDistanceFormatter],
                          @"valueIdentifier": @"distance"}
          withAnimation:animation];

    KSVolume fuelUnit = (KSVolume)[[_car valueForKey:@"fuelUnit"] integerValue];

    [self addRowAtIndex:2
              inSection:0
              cellClass:[NumberEditTableCell class]
               cellData:@{@"label": [AppDelegate fuelPriceUnitDescription:fuelUnit],
                          @"formatter": [AppDelegate sharedEditPreciseCurrencyFormatter],
                          @"alternateFormatter": [AppDelegate sharedPreciseCurrencyFormatter],
                          @"valueIdentifier": @"price"}
          withAnimation:animation];

    [self addRowAtIndex:3
              inSection:0
              cellClass:[NumberEditTableCell class]
               cellData:@{@"label": [AppDelegate fuelUnitDescription:fuelUnit discernGallons:NO pluralization:YES],
                          @"suffix": [@" " stringByAppendingString:[AppDelegate fuelUnitString:fuelUnit]],
                          @"formatter": KSVolumeIsMetric (fuelUnit) ? [AppDelegate sharedFuelVolumeFormatter] : [AppDelegate sharedPreciseFuelVolumeFormatter],
                          @"valueIdentifier": @"fuelVolume"}
          withAnimation:animation];

    [self addRowAtIndex:4
              inSection:0
              cellClass:[SwitchTableCell class]
               cellData:@{@"label": NSLocalizedString(@"Full Fill-Up", @""),
                          @"valueIdentifier": @"filledUp"}
          withAnimation:animation];

    if (!self.editing)
        [self createConsumptionRowWithAnimation:animation];
}



#pragma mark -
#pragma mark Locale Handling



- (void)localeChanged:(id)object
{
    NSIndexPath *previousSelection = [self.tableView indexPathForSelectedRow];
    
    [self dismissKeyboardWithCompletion: ^{
        
        [self removeAllSectionsWithAnimation:UITableViewRowAnimationNone];
        [self createTableContentsWithAnimation:UITableViewRowAnimationNone];
        [self.tableView reloadData];
        
        [self selectRowAtIndexPath:previousSelection];
    }];
}



#pragma mark -
#pragma mark Programatically Selecting Table Rows



- (void)activateTextFieldAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    UITextField *field = nil;
    
    if ([cell isKindOfClass:[DateEditTableCell class]])
        field = [(DateEditTableCell*)cell textField];
    
    else if ([cell isKindOfClass:[NumberEditTableCell class]])
        field = [(NumberEditTableCell*)cell textField];
    
    field.userInteractionEnabled = YES;
    [field becomeFirstResponder];
}


- (void)selectRowAtIndexPath:(NSIndexPath *)path
{
    if (path)
    {
        [self.tableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
        [self tableView:self.tableView didSelectRowAtIndexPath:path];
    }
}



#pragma mark -
#pragma mark EditablePageCellDelegate



- (id)valueForIdentifier:(NSString *)valueIdentifier
{
    if ([valueIdentifier isEqualToString:@"date"])
        return _date;

    else if ([valueIdentifier isEqualToString:@"distance"])
        return _distance;

    else if ([valueIdentifier isEqualToString:@"price"])
        return _price;

    else if ([valueIdentifier isEqualToString:@"fuelVolume"])
        return _fuelVolume;

    else if ([valueIdentifier isEqualToString:@"filledUp"])
        return @(_filledUp);

    else if ([valueIdentifier isEqualToString:@"showValueLabel"])
        return @(!(BOOL)self.editing);

    return nil;
}


- (void)valueChanged:(id)newValue identifier:(NSString *)valueIdentifier
{
    if ([valueIdentifier isEqualToString:@"date"]) {
        NSDate *newDate = [NSDate dateWithoutSeconds:(NSDate *)newValue];

        if (! [_date isEqualToDate:newDate]) {
            _date = newDate;
            dataChanged = YES;
        }
    }

    else if ([newValue isKindOfClass:[NSDecimalNumber class]]) {
        NSDecimalNumber *newNumber = (NSDecimalNumber *)newValue;

        if ([valueIdentifier isEqualToString:@"distance"]) {
            if ([_distance compare:newNumber] != NSOrderedSame) {
                _distance = newNumber;
                dataChanged = YES;
            }

        } else if ([valueIdentifier isEqualToString:@"price"]) {
            if ([_price compare:newNumber] != NSOrderedSame) {
                _price = newNumber;
                dataChanged = YES;
            }

        } else if ([valueIdentifier isEqualToString:@"fuelVolume"]) {
            if ([_fuelVolume compare:newNumber] != NSOrderedSame) {
                _fuelVolume = newNumber;
                dataChanged = YES;
            }
        }
    }

    else if ([valueIdentifier isEqualToString:@"filledUp"]) {
        BOOL newBoolValue = [newValue boolValue];

        if (_filledUp != newBoolValue) {
            _filledUp = newBoolValue;
            dataChanged = YES;
        }
    }

    // Validation of Done-Button
    BOOL canBeSaved = YES;

    NSDecimalNumber *zero = [NSDecimalNumber zero];

    if (! ([_distance compare:zero] == NSOrderedDescending && [_fuelVolume compare:zero] == NSOrderedDescending)) {
        canBeSaved = NO;

    } else if (! [_date isEqualToDate:[_event valueForKey:@"timestamp"]]) {
        if ([AppDelegate managedObjectContext:_managedObjectContext
                         containsEventWithCar:_car
                                      andDate:_date])
            canBeSaved = NO;
    }

    _doneButton.enabled = canBeSaved;
}


- (BOOL)valueValid:(id)newValue identifier:(NSString *)valueIdentifier
{
    // Date must be collision free
    if ([newValue isKindOfClass:[NSDate class]])
        if ([valueIdentifier isEqualToString:@"date"])
            if (! [_date isEqualToDate:[_event valueForKey:@"timestamp"]])
                if ([AppDelegate managedObjectContext:_managedObjectContext containsEventWithCar:_car andDate:(NSDate *)newValue] == YES)
                    return NO;

    // DecimalNumbers <= 0.0 are invalid
    if ([newValue isKindOfClass:[NSDecimalNumber class]])
        if (![valueIdentifier isEqualToString:@"price"])
            if ([(NSDecimalNumber *)newValue compare:[NSDecimalNumber zero]] != NSOrderedDescending)
                return NO;

    return YES;
}



#pragma mark -
#pragma mark UITableViewDataSource



- (NSString *)tableView:(UITableView *)aTableView titleForHeaderInSection:(NSInteger)section
{
	return nil;
}



#pragma mark -
#pragma mark UITableViewDelegate



- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];

    if ([cell isKindOfClass:[SwitchTableCell class]] || [cell isKindOfClass:[ConsumptionTableCell class]])
        return nil;
    else
        return indexPath;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self activateTextFieldAtIndexPath:indexPath];

    [tableView scrollToRowAtIndexPath:indexPath
                     atScrollPosition:UITableViewScrollPositionMiddle
                             animated:YES];
}



#pragma mark -
#pragma mark Memory Management



- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
