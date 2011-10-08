// FuelCalculatorController.h
//
// Kraftstoff


#import "AppDelegate.h"
#import "AppWindow.h"
#import "FuelCalculatorController.h"
#import "FuelEventController.h"
#import "CarTableCell.h"
#import "ConsumptionTableCell.h"
#import "DateEditTableCell.h"
#import "NumberEditTableCell.h"
#import "SwitchTableCell.h"


#define DISTANCE_DATA_ROW  1
#define PRICE_DATA_ROW     2
#define AMOUNT_DATA_ROW    4
#define ALL_DATA_ROWS      7


@interface FuelCalculatorController (private)

- (void)createConsumptionRowWithAnimation: (UITableViewRowAnimation)animation;
- (void)createDataRows: (unsigned)rowMask withAnimation: (UITableViewRowAnimation)animation;
- (void)createTableContentsWithAnimation: (UITableViewRowAnimation)animation;

- (void)recreateTableContentsWithAnimation: (UITableViewRowAnimation)animation;
- (void)recreateDataRowsWithPreviousCar: (NSManagedObject*)oldCar;
- (void)recreateDistanceRowWithAnimation: (UITableViewRowAnimation)animation;

- (void)dismissKeyboardAndUpdateContinuation;
- (void)dismissKeyboardAndUpdate: (id)sender;
- (void)deselectRowDismissKeyboardAndUpdate: (id)sender;

- (void)localeChanged: (id)object;

- (void)subscribeToShakeNotification;
- (void)unsubscribeFromShakeNotification;
- (void)handleShake: (id)object;

@end


@implementation FuelCalculatorController

@synthesize managedObjectContext;
@synthesize fetchedResultsController;

@synthesize editingTextField;

@synthesize car;
@synthesize lastChangeDate;
@synthesize date;
@synthesize distance;
@synthesize price;
@synthesize fuelVolume;
@synthesize filledUp;

@synthesize doneButton;
@synthesize saveButton;



#pragma mark -
#pragma mark View Lifecycle



- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = _I18N (@"Fill-Up");
    self.constantRowHeight = false;

    // Navigation-Bar buttons
    self.doneButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone
                                                                     target: self
                                                                     action: @selector (deselectRowDismissKeyboardAndUpdate:)] autorelease];

    self.saveButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemSave
                                                                     target: self
                                                                     action: @selector (saveAction:)] autorelease];

    // Add shadow layer onto the background image view
    UIView *imageView = [self.view viewWithTag: 100];

    [imageView.layer
        insertSublayer: [AppDelegate shadowWithFrame: CGRectMake (0.0, 0.0, imageView.frame.size.width, LargeShadowHeight)
                                          darkFactor: 0.5
                                         lightFactor: 150.0 / 255.0
                                             inverse: NO]
               atIndex: 0];

    // Fetch the cars
    self.fetchedResultsController          = [AppDelegate fetchedResultsControllerForCarsInContext: self.managedObjectContext];
    self.fetchedResultsController.delegate = self;

    changeIsUserDriven = NO;

    // Dump any old tables

    // Observe locale changes
    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector (localeChanged:)
               name: NSCurrentLocaleDidChangeNotification
             object: nil];

    // Schedule this to avoid some animation stuttering
    dispatch_async (dispatch_get_main_queue (),
                    ^{
                        if ([tableSections count] == 0)
                            [self   createTableContentsWithAnimation: UITableViewRowAnimationFade];
                        else
                            [self recreateTableContentsWithAnimation: UITableViewRowAnimationNone];                        
                    });
}


- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    self.editingTextField = nil;

    [super viewDidUnload];
}


- (void)viewDidAppear: (BOOL)animated
{
    [super viewDidAppear: animated];

    [self subscribeToShakeNotification];
}


- (void)viewWillDisappear: (BOOL)animated
{
    [super viewWillDisappear: animated];

    [self unsubscribeFromShakeNotification];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    self.editingTextField         = nil;
    self.managedObjectContext     = nil;
    self.fetchedResultsController = nil;

    self.date           = nil;
    self.lastChangeDate = nil;
    self.distance       = nil;
    self.fuelVolume     = nil;
    self.price          = nil;

    self.doneButton = nil;
    self.saveButton = nil;

    [super dealloc];
}




#pragma mark -
#pragma mark Shake Events



- (void)subscribeToShakeNotification
{
    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector (handleShake:)
               name: kraftstoffDeviceShakeNotification
             object: nil];

}


- (void)unsubscribeFromShakeNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: kraftstoffDeviceShakeNotification
                                                  object: nil];
}


- (void)handleShake: (id)object
{
    NSDecimalNumber *zero = [NSDecimalNumber zero];

    if ([distance   compare: zero] == NSOrderedSame &&
        [fuelVolume compare: zero] == NSOrderedSame &&
        [price      compare: zero] == NSOrderedSame)
        return;

    [UIView animateWithDuration: 0.3
                     animations: ^{

                         if ([self.tableView numberOfSections] == 2)
                             [self removeSectionAtIndex: 1 withAnimation: UITableViewRowAnimationFade];
                     }
                     completion: ^(BOOL finished){

                         NSDate *now = [NSDate date];

                         [self valueChanged: now  identifier: @"date"];
                         [self valueChanged: now  identifier: @"lastChangeDate"];
                         [self valueChanged: zero identifier: @"distance"];
                         [self valueChanged: zero identifier: @"price"];
                         [self valueChanged: zero identifier: @"fuelVolume"];
                         [self valueChanged: [NSNumber numberWithBool: YES] identifier: @"filledUp"];

                         [self recreateTableContentsWithAnimation: UITableViewRowAnimationLeft];
                     }];
}



#pragma mark -
#pragma mark Creating the Table Rows



- (void)createConsumptionRowWithAnimation: (UITableViewRowAnimation)animation;
{
    self.navigationItem.rightBarButtonItem = nil;

    // Don't add the section when no value can be computed
    NSDecimalNumber *zero = [NSDecimalNumber zero];

    if (! ([distance   compare: zero] == NSOrderedDescending &&
           [fuelVolume compare: zero] == NSOrderedDescending &&
           [price      compare: zero] == NSOrderedDescending))
        return;

    // Conversion units
    KSDistance        odometerUnit;
    KSVolume          fuelUnit;
    KSFuelConsumption consumptionUnit;

    if (self.car)
    {
        odometerUnit    = [[self.car valueForKey: @"odometerUnit"]        integerValue];
        fuelUnit        = [[self.car valueForKey: @"fuelUnit"]            integerValue];
        consumptionUnit = [[self.car valueForKey: @"fuelConsumptionUnit"] integerValue];
    }
    else
    {
        odometerUnit    = [AppDelegate odometerUnitFromLocale];
        fuelUnit        = [AppDelegate fuelUnitFromLocale];
        consumptionUnit = [AppDelegate fuelConsumptionUnitFromLocale];
    }

    // Compute the average consumption
    NSDecimalNumber *cost = [fuelVolume decimalNumberByMultiplyingBy: price];

    NSDecimalNumber *liters      = [AppDelegate litersForVolume: fuelVolume withUnit: fuelUnit];
    NSDecimalNumber *kilometers  = [AppDelegate kilometersForDistance: distance withUnit: odometerUnit];
    NSDecimalNumber *consumption = [AppDelegate consumptionForDistance: kilometers Volume: liters withUnit: consumptionUnit];

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

    // Enable save-button when bo other object for car/date exists
    if (car != nil && date != nil)
        if ([AppDelegate managedObjectContext: self.managedObjectContext containsEventWithCar: car andDate: date] == NO)
            self.navigationItem.rightBarButtonItem = saveButton;
}


- (void)createDataRows: (unsigned)rowMask withAnimation: (UITableViewRowAnimation)animation
{
    KSDistance odometerUnit;
    KSVolume fuelUnit;

    if (self.car)
    {
        odometerUnit = [[self.car valueForKey: @"odometerUnit"] integerValue];
        fuelUnit     = [[self.car valueForKey: @"fuelUnit"]     integerValue];
    }
    else
    {
        odometerUnit = [AppDelegate odometerUnitFromLocale];
        fuelUnit     = [AppDelegate fuelUnitFromLocale];
    }


    int rowOffset = ([self.fetchedResultsController.fetchedObjects count] < 2) ? 1 : 2;

    if (rowMask & DISTANCE_DATA_ROW)
    {
        if (distance == nil)
            self.distance = [NSDecimalNumber decimalNumberWithDecimal:
                                [[[NSUserDefaults standardUserDefaults] objectForKey: @"recentDistance"]
                                    decimalValue]];

        [self addRowAtIndex: 0 + rowOffset
                  inSection: 0
                  cellClass: [NumberEditTableCell class]
                   cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                                _I18N (@"Distance"),                                                            @"label",
                                [@" " stringByAppendingString: [AppDelegate odometerUnitString: odometerUnit]], @"suffix",
                                [AppDelegate sharedDistanceFormatter],                                          @"formatter",
                                @"distance",                                                                    @"valueIdentifier",
                                nil]
              withAnimation: animation];
    }

    if (rowMask & PRICE_DATA_ROW)
    {
        if (price == nil)
            self.price = [NSDecimalNumber decimalNumberWithDecimal:
                            [[[NSUserDefaults standardUserDefaults] objectForKey: @"recentPrice"]
                                decimalValue]];

        [self addRowAtIndex: 1 + rowOffset
                  inSection: 0
                  cellClass: [NumberEditTableCell class]
                   cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                                [AppDelegate fuelPriceUnitDescription: fuelUnit], @"label",
                                [AppDelegate sharedEditPreciseCurrencyFormatter], @"formatter",
                                [AppDelegate preciseCurrencyFormatter],           @"alternateFormatter",
                                price,                                            @"value",
                                @"price",                                         @"valueIdentifier",
                                nil]
              withAnimation: animation];
    }

    if (rowMask & AMOUNT_DATA_ROW)
    {
        if (fuelVolume == nil)
            self.fuelVolume = [NSDecimalNumber decimalNumberWithDecimal:
                                [[[NSUserDefaults standardUserDefaults] objectForKey: @"recentFuelVolume"]
                                    decimalValue]];

        [self addRowAtIndex: 2 + rowOffset
                  inSection: 0
                  cellClass: [NumberEditTableCell class]
                   cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                                [AppDelegate fuelUnitDescription: fuelUnit discernGallons: NO],         @"label",
                                [@" " stringByAppendingString: [AppDelegate fuelUnitString: fuelUnit]], @"suffix",
                                [AppDelegate sharedFuelVolumeFormatter],                                @"formatter",
                                @"fuelVolume",                                                          @"valueIdentifier",
                                nil]
              withAnimation: animation];
    }
}


- (void)createTableContentsWithAnimation: (UITableViewRowAnimation)animation
{
    [self addSectionAtIndex: 0 withAnimation: animation];

    // Row for car is optional
    switch ([self.fetchedResultsController.fetchedObjects count])
    {
        case 0:
            self.car = nil;
            break;

        case 1:
            self.car = [self.fetchedResultsController.fetchedObjects objectAtIndex: 0];
            break;

        default:
            {
                // Look for preferred car in preferences
                self.car = [[AppDelegate sharedDelegate] managedObjectForURLString:
                                [[NSUserDefaults standardUserDefaults]
                                    objectForKey: @"preferredCarID"]];

                // Fallback to first car if no preference can be found
                if (self.car == nil)
                    self.car = [self.fetchedResultsController.fetchedObjects objectAtIndex: 0];

                [self addRowAtIndex: 0
                          inSection: 0
                          cellClass: [CarTableCell class]
                           cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                                        _I18N (@"Car"),                               @"label",
                                        @"car",                                       @"valueIdentifier",
                                        self.fetchedResultsController.fetchedObjects, @"fetchedObjects",
                                        nil]
                      withAnimation: animation];
            }
            break;
    }

    if (date == nil)
        self.date = [AppDelegate dateWithoutSeconds: [NSDate date]];

    [self addRowAtIndex: (self.car) ? 1 : 0
              inSection: 0
              cellClass: [DateEditTableCell class]
               cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                            _I18N (@"Date"),                       @"label",
                            [AppDelegate sharedDateTimeFormatter], @"formatter",
                            @"date",                               @"valueIdentifier",
                            @"lastChangeDate",                     @"valueTimestamp",
                            [NSNumber numberWithBool: YES],        @"autorefresh",
                            nil]
          withAnimation: animation];

    [self createDataRows: ALL_DATA_ROWS withAnimation: animation];

    self.filledUp = [[[NSUserDefaults standardUserDefaults] objectForKey: @"recentFilledUp"] boolValue];

    if (self.car != nil)
        [self addRowAtIndex: (self.car) ? 5 : 4
                  inSection: 0
                  cellClass: [SwitchTableCell class]
                   cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                              _I18N (@"Full Fill-Up"), @"label",
                              @"filledUp",             @"valueIdentifier",
                              nil]
              withAnimation: animation];

    [self createConsumptionRowWithAnimation: animation];
}


- (void)recreateTableContentsWithAnimation: (UITableViewRowAnimation)animation
{
    if ([tableSections count] == 0)
        animation = UITableViewRowAnimationNone;

    // First remove and create new table rows in the internal data model...
    [self removeAllSectionsWithAnimation:   UITableViewRowAnimationNone];
    [self createTableContentsWithAnimation: UITableViewRowAnimationNone];

    // ...then update the tableview
    if (animation == UITableViewRowAnimationNone)
        [self.tableView reloadData];
    else
        [self.tableView reloadSections: [NSIndexSet indexSetWithIndexesInRange:
                                            NSMakeRange (0, [self.tableView numberOfSections])]
                      withRowAnimation: animation];
}



#pragma mark -
#pragma mark Updating the Table Rows



- (void)recreateDataRowsWithPreviousCar: (NSManagedObject*)oldCar
{
    // Replace data rows in the internal data model...
    for (int row = 4; row >= 2; row--)
        [self removeRowAtIndex: row inSection: 0 withAnimation: UITableViewRowAnimationNone];

    [self createDataRows: ALL_DATA_ROWS withAnimation: UITableViewRowAnimationNone];

    // ...then update the tableview
    BOOL odoChanged  = [[oldCar   valueForKey: @"odometerUnit"] integerValue]
                    != [[self.car valueForKey: @"odometerUnit"] integerValue];

    BOOL fuelChanged = KSVolumeIsMetric ([[oldCar   valueForKey: @"fuelUnit"] integerValue])
                    != KSVolumeIsMetric ([[self.car valueForKey: @"fuelUnit"] integerValue]);

    UITableViewRowAnimation animation = UITableViewRowAnimationRight;
    int count = 0;

    for (int row = 2; row <= 4; row++)
    {
        if ((row == 2 && odoChanged) || (row != 2 && fuelChanged))
        {
            animation = UITableViewRowAnimationRight + (count % 2);
            count ++;
        }
        else
            animation = UITableViewRowAnimationNone;

        [self.tableView reloadRowsAtIndexPaths: [NSArray arrayWithObject: [NSIndexPath indexPathForRow: row inSection: 0]]
                              withRowAnimation: animation];
    }
}


- (void)recreateDistanceRowWithAnimation: (UITableViewRowAnimation)animation
{
    int rowOffset = ([self.fetchedResultsController.fetchedObjects count] < 2) ? 1 : 2;

    // Replace distance row in the internal data model...
    [self removeRowAtIndex: 0 + rowOffset inSection: 0 withAnimation: UITableViewRowAnimationNone];
    [self createDataRows: DISTANCE_DATA_ROW withAnimation: UITableViewRowAnimationNone];

    // ...then update the tableview
    if (animation != UITableViewRowAnimationNone)
        [self.tableView reloadRowsAtIndexPaths: [NSArray arrayWithObject:
                                                    [NSIndexPath indexPathForRow: 0 + rowOffset
                                                                       inSection: 0]]
                              withRowAnimation: animation];
    else
        [self.tableView reloadData];
}


- (void)localeChanged: (id)object
{
    [self recreateTableContentsWithAnimation: UITableViewRowAnimationNone];
}



#pragma mark -
#pragma mark Storing Information in the Database



- (void)saveAction: (id)sender
{
    if (car != nil)
    {
        [UIView animateWithDuration: 0.3
                         animations: ^{ [self removeSectionAtIndex: 1 withAnimation: UITableViewRowAnimationFade]; }
                         completion: ^(BOOL finished){

                             // This will enable an animated reload of the table (row/cell count won't change)
                             changeIsUserDriven = YES;

                             // Create new managed object with our data
                             [AppDelegate addToArchiveWithCar: car
                                                         date: date
                                                     distance: distance
                                                        price: price
                                                   fuelVolume: fuelVolume
                                                     filledUp: filledUp
                                       inManagedObjectContext: self.managedObjectContext
                                          forceOdometerUpdate: NO];

                             // Reset internal data (except the date). Note: we aren't allowed to recreate the consumption section during the reload forced by CoreData change-event!
                             NSDecimalNumber *zero = [NSDecimalNumber zero];

                             [self valueChanged: zero identifier: @"distance"];
                             [self valueChanged: zero identifier: @"price"];
                             [self valueChanged: zero identifier: @"fuelVolume"];
                             [self valueChanged: [NSNumber numberWithBool: YES] identifier: @"filledUp"];

                             [[AppDelegate sharedDelegate] saveContext: self.managedObjectContext];
                         }];
    }
}



#pragma mark -
#pragma mark Conversion for Odometer



- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // Replace distance in table with difference to car odometer
    if (buttonIndex == 1)
    {
        KSDistance odometerUnit = [[car valueForKey: @"odometerUnit"] integerValue];
        NSDecimalNumber *rawDistance  = [AppDelegate kilometersForDistance: distance withUnit: odometerUnit];
        NSDecimalNumber *convDistance = [rawDistance decimalNumberBySubtracting: [car valueForKey: @"odometer"]];

        self.distance = [AppDelegate distanceForKilometers: convDistance withUnit: odometerUnit];

        [self recreateDistanceRowWithAnimation: UITableViewRowAnimationRight];
    }

    [self dismissKeyboardAndUpdateContinuation];
}


- (BOOL)askOdometerConversion
{
    // A simple heuristics when to ask for distance cobversion
    NSDecimalNumber *zero = [NSDecimalNumber zero];
    NSDecimalNumber *one  = [NSDecimalNumber one];


    // 1.) entered "distance" must be larger than car odometer
    KSDistance odometerUnit = [[car valueForKey: @"odometerUnit"] integerValue];

    NSDecimalNumber *rawDistance  = [AppDelegate kilometersForDistance: distance withUnit: odometerUnit];
    NSDecimalNumber *convDistance = [rawDistance decimalNumberBySubtracting: [car valueForKey: @"odometer"]];

    if ([zero compare: convDistance] != NSOrderedAscending)
        return NO;


    // 2.) consumption with converted distances is more 'logical'
    KSVolume fuelUnit     = [[car valueForKey: @"fuelUnit"] integerValue];
    NSDecimalNumber *liters = [AppDelegate litersForVolume: fuelVolume withUnit: fuelUnit];

    if ([zero compare: liters] != NSOrderedAscending)
        return NO;

    NSDecimalNumber *rawConsumption  = [AppDelegate consumptionForDistance: rawDistance  Volume: liters withUnit: 0];
    NSDecimalNumber *convConsumption = [AppDelegate consumptionForDistance: convDistance Volume: liters withUnit: 0];

    if ([one compare: rawConsumption] != NSOrderedDescending || [one compare: convConsumption] != NSOrderedAscending)
        return NO;


    // 3.) the event must be the youngest one
    NSArray *youngerEvents = [AppDelegate objectsForFetchRequest: [AppDelegate fetchRequestForEventsForCar: car
                                                                                                 afterDate: date
                                                                                               dateMatches: NO
                                                                                    inManagedObjectContext: managedObjectContext]
                                          inManagedObjectContext: managedObjectContext];

    if ([youngerEvents count] > 0)
        return NO;


    // Ask for conversion, offer both distance options
    NSNumberFormatter *distanceFormatter = [AppDelegate sharedDistanceFormatter];

    NSString *rawButton = [NSString stringWithFormat: @"%@ %@",
                                [distanceFormatter stringFromNumber: [AppDelegate distanceForKilometers: rawDistance  withUnit: odometerUnit]],
                                [AppDelegate odometerUnitString: odometerUnit]];

    NSString *convButton = [NSString stringWithFormat: @"%@ %@",
                                [distanceFormatter stringFromNumber: [AppDelegate distanceForKilometers: convDistance withUnit: odometerUnit]],
                                [AppDelegate odometerUnitString: odometerUnit]];

    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle: _I18N (@"Convert odometer reading into distance?")
                                                     message: _I18N (@"Please choose the distance driven:")
                                                    delegate: self
                                           cancelButtonTitle: rawButton
                                           otherButtonTitles: convButton, nil] autorelease];
    [alert show];
    return YES;
}



#pragma mark -
#pragma mark Dismissing the Keyboard



- (void)dismissKeyboardAndUpdateContinuation
{
    [self createConsumptionRowWithAnimation: UITableViewRowAnimationFade];
    [self subscribeToShakeNotification];
}


- (void)dismissKeyboardAndUpdate: (id)userInfo
{
    [self.editingTextField resignFirstResponder];

    self.navigationItem.leftBarButtonItem = nil;

    if (self.car == nil || [self askOdometerConversion] == NO)
    {
        [self dismissKeyboardAndUpdateContinuation];
    }
}


- (void)deselectRowDismissKeyboardAndUpdate: (id)sender
{
    BOOL scrollToTop = (self.tableView.contentOffset.y > 0.0);

    [UIView animateWithDuration: scrollToTop ? 0.2 : 0.1
                     animations: ^{

                         // Deselect active row
                         [self.tableView deselectRowAtIndexPath: [self.tableView indexPathForSelectedRow] animated: NO];

                         // If necessary scroll table to the top (this avoids ugly behavour when the keyboard slides away)
                         if (scrollToTop)
                             [self.tableView scrollToRowAtIndexPath: [NSIndexPath indexPathForRow: 0 inSection: 0]
                                                   atScrollPosition: UITableViewScrollPositionTop
                                                           animated: NO];
                     }
                     completion: ^(BOOL finished){

                         [self dismissKeyboardAndUpdate: sender];
                     }];
}



#pragma mark -
#pragma mark EditablePageCellDelegate



- (id)valueForIdentifier: (NSString*)valueIdentifier
{
    if ([valueIdentifier isEqualToString: @"car"])
        return car;
    else if ([valueIdentifier isEqualToString: @"date"])
        return date;
    else if ([valueIdentifier isEqualToString: @"lastChangeDate"])
        return lastChangeDate;
    else if ([valueIdentifier isEqualToString: @"distance"])
        return distance;
    else if ([valueIdentifier isEqualToString: @"price"])
        return price;
    else if ([valueIdentifier isEqualToString: @"fuelVolume"])
        return fuelVolume;
    else if ([valueIdentifier isEqualToString: @"filledUp"])
        return [NSNumber numberWithBool: filledUp];

    return nil;
}


- (void)valueChanged: (id)newValue identifier: (NSString*)valueIdentifier
{
    if ([newValue isKindOfClass: [NSDate class]])
    {
        if ([valueIdentifier isEqualToString: @"date"])
            self.date = [AppDelegate dateWithoutSeconds: (NSDate*)newValue];

        else if ([valueIdentifier isEqualToString: @"lastChangeDate"])
            self.lastChangeDate = [AppDelegate dateWithoutSeconds: (NSDate*)newValue];
    }

    else if ([newValue isKindOfClass: [NSDecimalNumber class]])
    {
        NSString *recentKey = nil;

        if ([valueIdentifier isEqualToString: @"distance"])
        {
            self.distance = (NSDecimalNumber*)newValue;
            recentKey     = @"recentDistance";
        }

        else if ([valueIdentifier isEqualToString: @"fuelVolume"])
        {
            self.fuelVolume = (NSDecimalNumber*)newValue;
            recentKey       = @"recentFuelVolume";
        }

        else if ([valueIdentifier isEqualToString: @"price"])
        {
            self.price = (NSDecimalNumber*)newValue;
            recentKey  = @"recentPrice";
        }

        if (recentKey)
        {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

            [defaults setObject: newValue forKey: recentKey];
            [defaults synchronize];
        }
    }

    else if ([valueIdentifier isEqualToString: @"filledUp"])
    {
        self.filledUp = [newValue boolValue];

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        [defaults setObject: newValue forKey: @"recentFilledUp"];
        [defaults synchronize];
    }

    else if ([valueIdentifier isEqualToString: @"car"])
    {
        if (! [self.car isEqual: newValue])
        {
            NSManagedObject *oldCar = self.car;

            self.car = (NSManagedObject*)newValue;
            [self recreateDataRowsWithPreviousCar: oldCar];
        }

        if ([[self.car objectID] isTemporaryID] == NO)
        {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

            [defaults setObject: [[[self.car objectID] URIRepresentation] absoluteString] forKey: @"preferredCarID"];
            [defaults synchronize];
        }
    }
}



#pragma mark -
#pragma mark NSFetchedResultsControllerDelegate



- (void)controllerDidChangeContent: (NSFetchedResultsController*)controller
{
    // Rebuild table when CoreData fetch changed contents
    // Attention: when the change modifies the number of displayed rows  (e.g. the car cell)
    //            the tableview must do reloadData instead of reloadSections. This behaviour
    //            is tied to the animation...

    [self recreateTableContentsWithAnimation: changeIsUserDriven ? UITableViewRowAnimationRight
                                                                 : UITableViewRowAnimationNone];

    changeIsUserDriven = NO;
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
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
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


    if ([cell isKindOfClass: [CarTableCell class]])
        self.editingTextField = [(CarTableCell*)cell textField];

    else if ([cell isKindOfClass: [DateEditTableCell class]])
        self.editingTextField = [(DateEditTableCell*)cell textField];

    else if ([cell isKindOfClass: [NumberEditTableCell class]])
        self.editingTextField = [(NumberEditTableCell*)cell textField];

    else
        self.editingTextField = nil;


    if (self.editingTextField)
    {
        [self unsubscribeFromShakeNotification];

        [UIView animateWithDuration: 0.3 // Seems to be overwritten by the table animation
                         animations: ^{

                             // Fade out consumption section
                             if ([self.tableView numberOfSections] == 2)
                                 [self removeSectionAtIndex: 1 withAnimation: UITableViewRowAnimationFade];
                         }
                         completion: ^(BOOL finished){

                             self.navigationItem.leftBarButtonItem  = doneButton;
                             self.navigationItem.rightBarButtonItem = nil;

                             // Enable user inputs for textfield in selected cell and show keyboard
                             self.editingTextField.userInteractionEnabled = YES;
                             [self.editingTextField becomeFirstResponder];

                             // Scroll selected cell into middle of screen
                             [tableView scrollToRowAtIndexPath: indexPath
                                              atScrollPosition: UITableViewScrollPositionMiddle
                                                      animated: YES];
                         }];
    }
    else
    {
        [tableView deselectRowAtIndexPath: indexPath animated: NO];
    }
}

@end
