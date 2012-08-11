// AppDelegate.m
//
// Kraftstoffrechner


#import "AppDelegate.h"
#import "CarViewController.h"
#import "FuelCalculatorController.h"
#import "CSVParser.h"
#import "CSVImporter.h"

#import "NSDecimalNumber+Kraftstoff.h"


// Shadow heights used within the app
CGFloat const NavBarShadowHeight   = 4.0;  // old: 16
CGFloat const TableBotShadowHeight = 4.0;  // old: 12
CGFloat const TableTopShadowHeight = 4.0;  // old: 10

// Standard heights for UI elements
CGFloat const TabBarHeight        = 49.0;
CGFloat const NavBarHeight        = 44.0;
CGFloat const StatusBarHeight     = 20.0;
CGFloat const HugeStatusBarHeight = 40.0;

// Pointer to shared Application Delegate Object
static AppDelegate *sharedDelegateObject = nil;


@implementation AppDelegate

@synthesize importAlert;
@synthesize window;
@synthesize tabBarController;
@synthesize background;
@synthesize managedObjectContext;
@synthesize managedObjectModel;
@synthesize persistentStoreCoordinator;



#pragma mark -
#pragma mark Application Support



+ (AppDelegate*)sharedDelegate
{
    NSAssert (sharedDelegateObject != nil, @"AppDelegate not yet initialized");
    return sharedDelegateObject;
}


+ (BOOL)isRunningOS6
{
    static BOOL initialized = NO;
    static BOOL isOS6;

    if (! initialized)
    {
        initialized = YES;
        isOS6 = ([[[UIDevice currentDevice] systemVersion] hasPrefix: @"5"] == NO);
    }
    
    return isOS6;
}



#pragma mark -
#pragma mark Application Lifecycle



- (void)awakeFromNib
{
    sharedDelegateObject = self;

    [[NSUserDefaults standardUserDefaults] registerDefaults:
        @{@"statisticTimeSpan":       @6,
          @"preferredStatisticsPage": @1,
          @"preferredCarID":          @"",
          @"recentDistance":          [NSDecimalNumber zero],
          @"recentPrice":             [NSDecimalNumber zero],
          @"recentFuelVolume":        [NSDecimalNumber zero],
          @"recentFilledUp":          @YES,
          @"editHelpCounter":         @0,
          @"firstStartup":            @YES}];
}


- (void)commonLaunchInitialization: (NSDictionary*)launchOptions
{
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        [window makeKeyAndVisible];

        // Switch once to the car view for new users
        if ([launchOptions objectForKey: UIApplicationLaunchOptionsURLKey] == nil)
        {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

            if ([defaults boolForKey: @"firstStartup"])
            {
                if ([[defaults stringForKey: @"preferredCarID"] isEqualToString: @""])
                    tabBarController.selectedIndex = 1;

                [defaults setObject: @NO forKey: @"firstStartup"];
            }
        }
    });
}


- (BOOL)application: (UIApplication*)application willFinishLaunchingWithOptions: (NSDictionary*)launchOptions
{
    [self commonLaunchInitialization: launchOptions];
    return YES;
}


- (BOOL)application: (UIApplication*)application didFinishLaunchingWithOptions: (NSDictionary*)launchOptions
{
    [self commonLaunchInitialization: launchOptions];
    return YES;
}


- (void)applicationDidEnterBackground: (UIApplication*)application
{
    [self saveContext: managedObjectContext];
}


- (void)applicationWillTerminate: (UIApplication*)application
{
    [self saveContext: managedObjectContext];
}



#pragma mark -
#pragma mark iOS 6 State Restoration



- (BOOL)application: (UIApplication*)application shouldSaveApplicationState: (NSCoder*)coder
{
    return YES;
}


- (BOOL)application: (UIApplication*)application shouldRestoreApplicationState: (NSCoder*)coder
{
    NSInteger stateVersion = [[coder decodeObjectForKey: UIApplicationStateRestorationBundleVersionKey] integerValue];
    NSInteger bundleVersion = [[[[NSBundle mainBundle] infoDictionary] objectForKey: (NSString*)kCFBundleVersionKey] integerValue];

    return (stateVersion <= bundleVersion);
}



#pragma mark -
#pragma mark Data Import



- (void)showImportAlert
{
    if (self.importAlert == nil)
    {
        UIActivityIndicatorView *progress = [[UIActivityIndicatorView alloc] initWithFrame: CGRectMake (125, 50, 30, 30)];
        [progress setActivityIndicatorViewStyle: UIActivityIndicatorViewStyleWhiteLarge];
        [progress startAnimating];


        self.importAlert = [[UIAlertView alloc] initWithTitle: _I18N (@"Importing")
                                                      message: @""
                                                     delegate: nil
                                            cancelButtonTitle: nil
                                            otherButtonTitles: nil];

        [importAlert addSubview: progress];
        [importAlert show];
    }
}


- (void)hideImportAlert
{
    [self.importAlert dismissWithClickedButtonIndex: 0 animated: YES];
    self.importAlert = nil;
}


// Read file contents from given URL, guess file encoding
- (NSString*)contentsOfURL: (NSURL*)url
{
    NSStringEncoding enc;

    NSError  *error  = nil;
    NSString *string = [NSString stringWithContentsOfURL: url usedEncoding: &enc error: &error];

    if (string == nil || error != nil)
    {
        error  = nil;
        string = [NSString stringWithContentsOfURL: url encoding: NSMacOSRomanStringEncoding error: &error];
    }

    return string;
}


// Removes files from the inbox
- (void)removeFileItemAtURL: (NSURL*)url
{
    if ([url isFileURL])
    {
        NSError *error = nil;

        [[NSFileManager defaultManager] removeItemAtURL: url error: &error];

        if (error != nil)
            NSLog (@"%@", [error localizedDescription]);
    }
}


- (NSString*)pluralizedImportMessageForCarCount: (NSInteger)carCount eventCount: (NSInteger)eventCount
{
    NSString *format;
    
    if (carCount == 1)
        format = _I18N (((eventCount == 1) ? @"Imported %d car with %d fuel event."  : @"Imported %d car with %d fuel events."));
    else
        format = _I18N (((eventCount == 1) ? @"Imported %d cars with %d fuel event." : @"Imported %d cars with %d fuel events."));

    return [NSString stringWithFormat:format, carCount, eventCount];
}


- (BOOL)application: (UIApplication*)application openURL: (NSURL*)url sourceApplication: (NSString*)sourceApplication annotation: (id)annotation
{
    // Ugly, but don't allow nested imports
    if (self.importAlert)
    {
        [self removeFileItemAtURL: url];
        return NO;
    }

    // Show modal activity indicator while importing
    [self showImportAlert];

    // Import in context with private queue
    NSManagedObjectContext *parentContext = self.managedObjectContext;
    NSManagedObjectContext *importContext = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSPrivateQueueConcurrencyType];
    [importContext setParentContext: parentContext];

    [importContext performBlock: ^{

        // Read file contents from given URL, guess file encoding
        NSString *CSVString = [self contentsOfURL: url];
        [self removeFileItemAtURL: url];

        if (CSVString)
        {
            // Try to import data from CSV file
            CSVImporter *importer = [[CSVImporter alloc] init];

            NSInteger numCars   = 0;
            NSInteger numEvents = 0;

            BOOL success = [importer importFromCSVString: CSVString
                                            detectedCars: &numCars
                                          detectedEvents: &numEvents
                                               sourceURL: url
                                              inContext: importContext];

            // On success propagate changes to parent context
            if (success)
            {
                [self saveContext: importContext];
                [parentContext performBlock: ^{ [self saveContext: parentContext]; }];
            }

            dispatch_async (dispatch_get_main_queue (),
                            ^{
                               [self hideImportAlert];

                                NSString *title = (success)
                                                     ? _I18N (@"Import Finished")
                                                     : _I18N (@"Import Failed");

                                NSString *message = (success)
                                                     ? [self pluralizedImportMessageForCarCount: numCars eventCount: numEvents]
                                                     : _I18N (@"No valid CSV-data could be found.");

                                [[[UIAlertView alloc] initWithTitle: title
                                                            message: message
                                                           delegate: nil
                                                  cancelButtonTitle: _I18N (@"OK")
                                                  otherButtonTitles: nil] show];
                            });
        }
        else
        {
            dispatch_async (dispatch_get_main_queue (),
                            ^{
                                [self hideImportAlert];

                                [[[UIAlertView alloc] initWithTitle: _I18N (@"Import Failed")
                                                            message: _I18N (@"Can't detect file encoding. Please try to convert your CSV-file to UTF8 encoding.")
                                                           delegate: nil
                                                  cancelButtonTitle: _I18N (@"OK")
                                                  otherButtonTitles: nil] show];
                            });
        }
    }];

    // Treat imports as successfull first startups
    [[NSUserDefaults standardUserDefaults] setObject: @NO forKey: @"firstStartup"];
    return YES;
}



#pragma mark -
#pragma mark Window Background Transitions



- (void)setWindowBackground: (UIImage*)image animated: (BOOL)animated
{
    UIImageView *imageView = [[window subviews] objectAtIndex: 0];

    imageView.image = image;

    if (animated)
    {
        CATransition *transition  = [CATransition animation];

        transition.duration       = 0.25;
        transition.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseOut];
        transition.type           = kCATransitionFade;

        [imageView.layer addAnimation: transition forKey: nil];
    }
}



#pragma mark -
#pragma mark Application's Documents Directory



- (NSString*)applicationDocumentsDirectory
{
    return [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}



#pragma mark -
#pragma mark Shared Color Gradients



// Create gray gradient layers used as drop shadows in table views
+ (CAGradientLayer*)shadowWithFrame: (CGRect)frame
                         darkFactor: (CGFloat)darkFactor
                        lightFactor: (CGFloat)lightFactor
                      fadeDownwards: (BOOL)downwards
{
    CAGradientLayer *newShadow = [[CAGradientLayer alloc] init];

    UIColor *darkColor  = [UIColor colorWithWhite: 0.0         alpha: darkFactor];
    UIColor *lightColor = [UIColor colorWithWhite: lightFactor alpha: 0.0       ];

    newShadow.frame           = frame;
    newShadow.backgroundColor = [UIColor clearColor].CGColor;
    newShadow.colors          = downwards
                                    ? @[(id)[darkColor  CGColor], (id)[lightColor CGColor]]
                                    : @[(id)[lightColor CGColor], (id)[darkColor  CGColor]];
    return newShadow;
}


+ (CGGradientRef)backGradient
{
    static CGGradientRef backGradient = NULL;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        static CGFloat colorComponents [8] = { 25.0/255.0, 1.0,  25.0/255.0, 1.0,  40.0/255.0, 1.0,  117.0/255.0, 1.0 };
        static CGFloat colorLocations  [4] = { 0.0, 0.5, 0.5, 1.0 };

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray ();

        backGradient = CGGradientCreateWithColorComponents (colorSpace, colorComponents, colorLocations, 4);
        CGColorSpaceRelease (colorSpace);
    });

    return backGradient;

}


+ (CGGradientRef)blueGradient
{
    static CGGradientRef blueGradient = NULL;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        static CGFloat colorComponents [8] = { 0.360, 0.682, 0.870, 0.93,  0.466, 0.721, 0.870, 0.93 };

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB ();

        blueGradient = CGGradientCreateWithColorComponents (colorSpace, colorComponents, NULL, 2);
        CGColorSpaceRelease (colorSpace);
    });

    return blueGradient;

}


+ (CGGradientRef)greenGradient
{
    static CGGradientRef greenGradient  = NULL;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        static CGFloat colorComponents [8] = { 0.615, 0.815, 0.404, 0.93,  0.662, 0.815, 0.502, 0.93 };

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB ();

        greenGradient = CGGradientCreateWithColorComponents (colorSpace, colorComponents, NULL, 2);
        CGColorSpaceRelease (colorSpace);
    });

    return greenGradient;
}


+ (CGGradientRef)orangeGradient
{
    static CGGradientRef orangeGradient = NULL;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        static CGFloat colorComponents [8] = { 0.988, 0.603, 0.215, 0.93,  0.988, 0.662, 0.333, 0.93 };

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB ();

        orangeGradient = CGGradientCreateWithColorComponents (colorSpace, colorComponents, NULL, 2);
        CGColorSpaceRelease (colorSpace);
    });

    return orangeGradient;
}


+ (CGGradientRef)infoGradient
{
    static CGGradientRef infoGradient = NULL;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        static CGFloat colorComponents [8] = { 0.97, 0.97, 0.97, 1.0,  0.80, 0.80, 0.80, 1.0 };

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB ();

        infoGradient = CGGradientCreateWithColorComponents (colorSpace, colorComponents, NULL, 2);
        CGColorSpaceRelease (colorSpace);
    });

    return infoGradient;
}


+ (CGGradientRef)knobGradient
{
    static CGGradientRef knobGradient = NULL;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        static CGFloat colorComponents [8] = { 1.0, 0.964, 0.078, 1.0,  1.0, 0.756, 0.188, 1.0 };

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB ();

        knobGradient = CGGradientCreateWithColorComponents (colorSpace, colorComponents, NULL, 2);
        CGColorSpaceRelease (colorSpace);
    });

    return knobGradient;
}



#pragma mark -
#pragma mark Shared Data Formatters



+ (NSDateFormatter*)sharedLongDateFormatter
{
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeStyle: NSDateFormatterShortStyle];
        [dateFormatter setDateStyle: NSDateFormatterLongStyle];
    });

    return dateFormatter;
}


+ (NSDateFormatter*)sharedDateFormatter
{
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeStyle: NSDateFormatterNoStyle];
        [dateFormatter setDateStyle: NSDateFormatterMediumStyle];
    });

    return dateFormatter;
}


+ (NSDateFormatter*)sharedDateTimeFormatter
{
    static NSDateFormatter *dateTimeFormatter = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        dateTimeFormatter = [[NSDateFormatter alloc] init];
        [dateTimeFormatter setTimeStyle: NSDateFormatterShortStyle];
        [dateTimeFormatter setDateStyle: NSDateFormatterMediumStyle];
    });

    return dateTimeFormatter;
}


+ (NSNumberFormatter*)sharedDistanceFormatter
{
    static NSNumberFormatter *distanceFormatter = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        distanceFormatter = [[NSNumberFormatter alloc] init];
        [distanceFormatter setGeneratesDecimalNumbers: YES];
        [distanceFormatter setNumberStyle: NSNumberFormatterDecimalStyle];
        [distanceFormatter setMinimumFractionDigits: 1];
        [distanceFormatter setMaximumFractionDigits: 1];
    });

    return distanceFormatter;
}


+ (NSNumberFormatter*)sharedFuelVolumeFormatter
{
    static NSNumberFormatter *fuelVolumeFormatter = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        fuelVolumeFormatter = [[NSNumberFormatter alloc] init];
        [fuelVolumeFormatter setGeneratesDecimalNumbers: YES];
        [fuelVolumeFormatter setNumberStyle: NSNumberFormatterDecimalStyle];
        [fuelVolumeFormatter setMinimumFractionDigits: 2];
        [fuelVolumeFormatter setMaximumFractionDigits: 2];
    });

    return fuelVolumeFormatter;
}


+ (NSNumberFormatter*)sharedPreciseFuelVolumeFormatter
{
    static NSNumberFormatter *preciseFuelVolumeFormatter = nil;
    static dispatch_once_t pred;
    
    dispatch_once (&pred, ^{
        
        preciseFuelVolumeFormatter = [[NSNumberFormatter alloc] init];
        [preciseFuelVolumeFormatter setGeneratesDecimalNumbers: YES];
        [preciseFuelVolumeFormatter setNumberStyle: NSNumberFormatterDecimalStyle];
        [preciseFuelVolumeFormatter setMinimumFractionDigits: 3];
        [preciseFuelVolumeFormatter setMaximumFractionDigits: 3];
    });
    
    return preciseFuelVolumeFormatter;
}


// Standard currency formatter
+ (NSNumberFormatter*)sharedCurrencyFormatter
{
    static NSNumberFormatter *currencyFormatter = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        currencyFormatter = [[NSNumberFormatter alloc] init];
        [currencyFormatter setGeneratesDecimalNumbers: YES];
        [currencyFormatter setNumberStyle: NSNumberFormatterCurrencyStyle];
    });

    return currencyFormatter;
}


// Currency formatter with empty currency symbol for axis of statistic graphs
+ (NSNumberFormatter*)sharedAxisCurrencyFormatter
{
    static NSNumberFormatter *axisCurrencyFormatter = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        axisCurrencyFormatter = [[NSNumberFormatter alloc] init];
        [axisCurrencyFormatter setGeneratesDecimalNumbers: YES];
        [axisCurrencyFormatter setNumberStyle: NSNumberFormatterCurrencyStyle];
        [axisCurrencyFormatter setCurrencySymbol: @""];
    });

    return axisCurrencyFormatter;
}


// Currency formatter with empty currency symbol and one additional fractional digit - used for active textfields
+ (NSNumberFormatter*)sharedEditPreciseCurrencyFormatter
{
    static NSNumberFormatter *editPreciseCurrencyFormatter = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        CGFloat fractionDigits = [[self sharedCurrencyFormatter] maximumFractionDigits];

        // Don't introduce fractional digits if the currency has none
        if (fractionDigits >  0)
            fractionDigits += 1;

        editPreciseCurrencyFormatter = [[NSNumberFormatter alloc] init];
        [editPreciseCurrencyFormatter setGeneratesDecimalNumbers: YES];
        [editPreciseCurrencyFormatter setNumberStyle: NSNumberFormatterCurrencyStyle];
        [editPreciseCurrencyFormatter setMinimumFractionDigits: fractionDigits];
        [editPreciseCurrencyFormatter setMaximumFractionDigits: fractionDigits];
        [editPreciseCurrencyFormatter setCurrencySymbol: @""];

        // Needed e.g. for CHF
        [editPreciseCurrencyFormatter setRoundingIncrement: @0];

        // Needed since NSNumberFormatters can't parse their own € output
        [editPreciseCurrencyFormatter setLenient: YES];
    });

    return editPreciseCurrencyFormatter;
}


// Currency formatter with one additional fractional digit - used for inactive textfields
+ (NSNumberFormatter*)sharedPreciseCurrencyFormatter
{
    static NSNumberFormatter *preciseCurrencyFormatter = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        CGFloat fractionDigits = [[self sharedCurrencyFormatter] maximumFractionDigits];

        // Don't introduce fractional digits if the currency has none
        if (fractionDigits >  0)
            fractionDigits += 1;

        preciseCurrencyFormatter = [[NSNumberFormatter alloc] init];
        [preciseCurrencyFormatter setGeneratesDecimalNumbers: YES];
        [preciseCurrencyFormatter setNumberStyle: NSNumberFormatterCurrencyStyle];
        [preciseCurrencyFormatter setMinimumFractionDigits: fractionDigits];
        [preciseCurrencyFormatter setMaximumFractionDigits: fractionDigits];

        // Needed e.g. for CHF
        [preciseCurrencyFormatter setRoundingIncrement: @0];

        // Needed since NSNumberFormatters can't parse their own € output
        [preciseCurrencyFormatter setLenient: YES];
    });

    return preciseCurrencyFormatter;
}


// Rounding handler for computation of average consumption
+ (NSDecimalNumberHandler*)sharedConsumptionRoundingHandler
{
    static NSDecimalNumberHandler *consumptionRoundingHandler = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        short fractionDigits = (short)[[self sharedFuelVolumeFormatter] maximumFractionDigits];
        consumptionRoundingHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode: NSRoundPlain
                                                                                            scale: fractionDigits
                                                                                 raiseOnExactness: NO
                                                                                  raiseOnOverflow: NO
                                                                                 raiseOnUnderflow: NO
                                                                              raiseOnDivideByZero: NO];
    });

    return consumptionRoundingHandler;
}


// Rounding handler for precise price computations
+ (NSDecimalNumberHandler*)sharedPriceRoundingHandler
{
    static NSDecimalNumberHandler *priceRoundingHandler = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        short fractionDigits = (short)[[self sharedEditPreciseCurrencyFormatter] maximumFractionDigits];
        priceRoundingHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode: NSRoundUp
                                                                                      scale: fractionDigits
                                                                           raiseOnExactness: NO
                                                                            raiseOnOverflow: NO
                                                                           raiseOnUnderflow: NO
                                                                        raiseOnDivideByZero: NO];
    });

    return priceRoundingHandler;
}



#pragma mark -
#pragma mark Core Data Support



- (void)alertView: (UIAlertView*)alertView didDismissWithButtonIndex: (NSInteger)buttonIndex
{
    [NSException raise: NSGenericException format: @"%@", errorDescription];
    abort ();
}


- (NSManagedObjectContext*)managedObjectContext
{
    if (managedObjectContext == nil)
    {
        NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];

        if (coordinator != nil)
        {
            managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSMainQueueConcurrencyType];
            [managedObjectContext setPersistentStoreCoordinator: coordinator];
            [managedObjectContext setMergePolicy: NSMergeByPropertyObjectTrumpMergePolicy];
        }
    }

    return managedObjectContext;
}


- (NSManagedObjectModel*)managedObjectModel
{
    if (managedObjectModel == nil)
    {
        NSString *modelPath = [[NSBundle mainBundle] pathForResource: @"Kraftstoffrechner" ofType: @"momd"];
        managedObjectModel  = [[NSManagedObjectModel alloc] initWithContentsOfURL: [NSURL fileURLWithPath: modelPath]];
    }

    return managedObjectModel;
}


- (NSPersistentStoreCoordinator*)persistentStoreCoordinator
{
    if (persistentStoreCoordinator == nil)
    {
        NSURL *storeURL = [NSURL fileURLWithPath: [[self applicationDocumentsDirectory] stringByAppendingPathComponent: @"Kraftstoffrechner.sqlite"]];

        NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                                  NSInferMappingModelAutomaticallyOption:       @YES};

        persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: self.managedObjectModel];

        NSError *error = nil;

        if (! [persistentStoreCoordinator addPersistentStoreWithType: NSSQLiteStoreType
                                                       configuration: nil
                                                                 URL: storeURL
                                                             options: options
                                                               error: &error])
        {
            errorDescription = [error localizedDescription];

            [[[UIAlertView alloc] initWithTitle: _I18N (@"Can't Open Database")
                                        message: _I18N (@"Sorry, the application database cannot be opened. Please quit the application with the Home button.")
                                       delegate: self
                              cancelButtonTitle: nil
                              otherButtonTitles: @"Ok", nil] show];
        }
    }

    return persistentStoreCoordinator;
}


- (BOOL)saveContext: (NSManagedObjectContext*)context
{
    if (context != nil && [context hasChanges])
    {
        NSError *error = nil;

        if (![context save: &error])
        {
            errorDescription = [error localizedDescription];

            [[[UIAlertView alloc] initWithTitle: _I18N (@"Can't Save Database")
                                        message: _I18N (@"Sorry, the application database cannot be saved. Please quit the application with the Home button.")
                                       delegate: self
                              cancelButtonTitle: nil
                              otherButtonTitles: @"Ok", nil] show];
        }

        return YES;
    }

    return NO;
}


// Returns a unique cache-name for fetch requests which must rely on 'parent == object' properties.
// The name is derived from the parents object ID.
- (NSString*)cacheNameForFuelEventFetchWithParent: (NSManagedObject*)parent
{
    NSString *URL = [self modelIdentifierForManagedObject: parent];

    return [URL stringByReplacingOccurrencesOfString: @"/" withString: @"_"];
}


- (NSString*)modelIdentifierForManagedObject: (NSManagedObject*)object
{
    NSManagedObjectID *objectID = object.objectID;

    if (objectID && ! [objectID isTemporaryID])
        return [[objectID URIRepresentation] absoluteString];
    else
        return nil;
}


- (NSManagedObject*)managedObjectForModelIdentifier: (NSString*)identifier
{
    NSURL *objectURL = [NSURL URLWithString: identifier];

    if ([[objectURL scheme] isEqualToString: @"x-coredata"])
    {
        NSManagedObjectID *objectID = [self.persistentStoreCoordinator managedObjectIDForURIRepresentation: objectURL];

        if (objectID)
            return [self.managedObjectContext objectWithID: objectID];
    }

    return nil;
}



#pragma mark -
#pragma mark Core Data Fetches



+ (NSFetchRequest*)fetchRequestForCarsInManagedObjectContext: (NSManagedObjectContext*)moc
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

    // Entity name
    NSEntityDescription *entity = [NSEntityDescription entityForName: @"car" inManagedObjectContext: moc];
    [fetchRequest setEntity: entity];
    [fetchRequest setFetchBatchSize: 32];

    // Sorting keys
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"order" ascending: YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects: sortDescriptor, nil];
    [fetchRequest setSortDescriptors: sortDescriptors];

    return fetchRequest;
}


+ (NSFetchRequest*)fetchRequestForEventsForCar: (NSManagedObject*)car
                                     afterDate: (NSDate*)date
                                   dateMatches: (BOOL)dateMatches
                        inManagedObjectContext: (NSManagedObjectContext*)moc
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

    // Entity name
    NSEntityDescription *entity = [NSEntityDescription entityForName: @"fuelEvent" inManagedObjectContext: moc];
    [fetchRequest setEntity: entity];
    [fetchRequest setFetchBatchSize: 128];

    // Predicates
    NSPredicate *parentPredicate = [NSPredicate predicateWithFormat: @"car == %@", car];

    if (date == nil)
    {
        [fetchRequest setPredicate: parentPredicate];
    }
    else
    {
        NSString *dateDescription  = [[NSExpression expressionForConstantValue: date] description];
        NSPredicate *datePredicate = [NSPredicate predicateWithFormat:
                                        [NSString stringWithFormat: @"timestamp %@ %@",
                                            (dateMatches) ? @">=" : @">",
                                            dateDescription]];

        [fetchRequest setPredicate:
            [NSCompoundPredicate andPredicateWithSubpredicates:
                @[parentPredicate, datePredicate]]];
    }

    // Sorting keys
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"timestamp" ascending: NO];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];

    [fetchRequest setSortDescriptors: sortDescriptors];


    return fetchRequest;
}


+ (NSFetchRequest*)fetchRequestForEventsForCar: (NSManagedObject*)car
                                    beforeDate: (NSDate*)date
                                   dateMatches: (BOOL)dateMatches
                        inManagedObjectContext: (NSManagedObjectContext*)moc
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

    // Entity name
    NSEntityDescription *entity = [NSEntityDescription entityForName: @"fuelEvent" inManagedObjectContext: moc];
    [fetchRequest setEntity: entity];
    [fetchRequest setFetchBatchSize: 8];

    // Predicates
    NSPredicate *parentPredicate = [NSPredicate predicateWithFormat: @"car == %@", car];

    if (date == nil)
    {
        [fetchRequest setPredicate: parentPredicate];
    }
    else
    {
        NSString *dateDescription = [[NSExpression expressionForConstantValue: date] description];
        NSPredicate *datePredicate = [NSPredicate predicateWithFormat:
                                        [NSString stringWithFormat: @"timestamp %@ %@",
                                            (dateMatches) ? @"<=" : @"<",
                                            dateDescription]];

        [fetchRequest setPredicate:
            [NSCompoundPredicate andPredicateWithSubpredicates:
                @[parentPredicate, datePredicate]]];
    }

    // Sorting keys
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"timestamp" ascending: NO];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];

    [fetchRequest setSortDescriptors: sortDescriptors];

    return fetchRequest;
}


+ (NSFetchedResultsController*)fetchedResultsControllerForCarsInContext: (NSManagedObjectContext*)moc
{
    NSFetchRequest *fetchRequest = [self fetchRequestForCarsInManagedObjectContext: moc];

    // No section names; perform fetch without cache
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest: fetchRequest
                                                                                               managedObjectContext: moc
                                                                                                 sectionNameKeyPath: nil
                                                                                                          cacheName: nil];


    // Perform the Core Data fetch
    NSError *error = nil;

    if (! [fetchedResultsController performFetch: &error])
    {
        [NSException raise: NSGenericException format: @"%@", [error localizedDescription]];
    }

    return fetchedResultsController;
}


+ (NSArray*)objectsForFetchRequest: (NSFetchRequest*)fetchRequest
            inManagedObjectContext: (NSManagedObjectContext*)moc
{
    NSError *error = nil;
    NSArray *fetchedObjects = [moc executeFetchRequest: fetchRequest error: &error];

    if (error != nil)
    {
        [NSException raise: NSGenericException format: @"%@", [error localizedDescription]];
    }

    return fetchedObjects;
}


+ (BOOL)managedObjectContext: (NSManagedObjectContext*)moc
        containsEventWithCar: (NSManagedObject*)car
                     andDate: (NSDate*)date;
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

    // Entity name
    NSEntityDescription *entity = [NSEntityDescription entityForName: @"fuelEvent"
                                              inManagedObjectContext: moc];
    [fetchRequest setEntity: entity];
    [fetchRequest setFetchBatchSize: 2];

    // Predicates
    NSPredicate *parentPredicate = [NSPredicate predicateWithFormat: @"car == %@", car];

    NSString *dateDescription = [[NSExpression expressionForConstantValue: date] description];
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat: [NSString stringWithFormat: @"timestamp == %@", dateDescription]];

    [fetchRequest setPredicate:
        [NSCompoundPredicate andPredicateWithSubpredicates:
            @[parentPredicate, datePredicate]]];

    // Check whether fetch reveals any event objects
    return ([[self objectsForFetchRequest: fetchRequest inManagedObjectContext: moc] count] > 0);
}



#pragma mark -
#pragma mark Core Data Updates



+ (NSManagedObject*)addToArchiveWithCar: (NSManagedObject*)car
                                   date: (NSDate*)date
                               distance: (NSDecimalNumber*)distance
                                  price: (NSDecimalNumber*)price
                             fuelVolume: (NSDecimalNumber*)fuelVolume
                               filledUp: (BOOL)filledUp
                 inManagedObjectContext: (NSManagedObjectContext*)moc
                    forceOdometerUpdate: (BOOL)forceOdometerUpdate
{
    NSDecimalNumber *zero = [NSDecimalNumber zero];


    // Convert distance and fuelvolume to SI units
    KSVolume fuelUnit       = [[car valueForKey: @"fuelUnit"]     integerValue];
    KSDistance odometerUnit = [[car valueForKey: @"odometerUnit"] integerValue];

    NSDecimalNumber *liters        = [AppDelegate litersForVolume: fuelVolume withUnit: fuelUnit];
    NSDecimalNumber *kilometers    = [AppDelegate kilometersForDistance: distance withUnit: odometerUnit];
    NSDecimalNumber *pricePerLiter = [AppDelegate pricePerLiter: price withUnit: fuelUnit];

    NSDecimalNumber *inheritedCost       = zero;
    NSDecimalNumber *inheritedDistance   = zero;
    NSDecimalNumber *inheritedFuelVolume = zero;


    // Compute inherited data from older element
    {
        // Fetch older events
        NSArray *olderEvents = [self objectsForFetchRequest: [self fetchRequestForEventsForCar: car
                                                                                    beforeDate: date
                                                                                   dateMatches: NO
                                                                        inManagedObjectContext: moc]
                                     inManagedObjectContext: moc];

        if ([olderEvents count])
        {
            NSManagedObject *olderEvent = [olderEvents objectAtIndex: 0];

            if ([[olderEvent valueForKey: @"filledUp"] boolValue] == NO)
            {
                NSDecimalNumber *cost = [[olderEvent valueForKey: @"fuelVolume"] decimalNumberByMultiplyingBy: [olderEvent valueForKey: @"price"]];

                inheritedCost       = [cost decimalNumberByAdding: [olderEvent valueForKey: @"inheritedCost"]];
                inheritedDistance   = [[olderEvent valueForKey: @"distance"]   decimalNumberByAdding: [olderEvent valueForKey: @"inheritedDistance"]];
                inheritedFuelVolume = [[olderEvent valueForKey: @"fuelVolume"] decimalNumberByAdding: [olderEvent valueForKey: @"inheritedFuelVolume"]];
            }
        }
    }


    // Update inherited distance/volume for younger events, probably mark the car odometer for an update
    {
        // Fetch younger events
        NSArray *youngerEvents = [self objectsForFetchRequest: [self fetchRequestForEventsForCar: car
                                                                                       afterDate: date
                                                                                     dateMatches: NO
                                                                          inManagedObjectContext: moc]
                                       inManagedObjectContext: moc];

        if ([youngerEvents count])
        {
            NSDecimalNumber *deltaCost = (filledUp)
                ? [[NSDecimalNumber zero] decimalNumberBySubtracting: inheritedCost]
                : [liters decimalNumberByMultiplyingBy: pricePerLiter];

            NSDecimalNumber *deltaDistance = (filledUp)
                ? [[NSDecimalNumber zero] decimalNumberBySubtracting: inheritedDistance]
                : kilometers;

            NSDecimalNumber *deltaFuelVolume = (filledUp)
                ? [[NSDecimalNumber zero] decimalNumberBySubtracting: inheritedFuelVolume]
                : liters;

            for (NSUInteger row = [youngerEvents count]; row > 0; )
            {
                NSManagedObject *youngerEvent = [youngerEvents objectAtIndex: --row];

                [youngerEvent setValue: [[[youngerEvent valueForKey: @"inheritedCost"] decimalNumberByAdding: deltaCost] max: zero]
                                forKey: @"inheritedCost"];

                [youngerEvent setValue: [[[youngerEvent valueForKey: @"inheritedDistance"] decimalNumberByAdding: deltaDistance] max: zero]
                                forKey: @"inheritedDistance"];

                [youngerEvent setValue: [[[youngerEvent valueForKey: @"inheritedFuelVolume"] decimalNumberByAdding: deltaFuelVolume] max: zero]
                                forKey: @"inheritedFuelVolume"];

                if ([[youngerEvent valueForKey: @"filledUp"] boolValue] == YES)
                    break;
            }
        }

        // New event will be the youngest one => update odometer too
        else
            forceOdometerUpdate = YES;
    }


    // Create new managed object for this event
    NSManagedObject *newEvent = [NSEntityDescription insertNewObjectForEntityForName: @"fuelEvent"
                                                              inManagedObjectContext: moc];

    [newEvent setValue: car           forKey: @"car"];
    [newEvent setValue: date          forKey: @"timestamp"];
    [newEvent setValue: kilometers    forKey: @"distance"];
    [newEvent setValue: pricePerLiter forKey: @"price"];
    [newEvent setValue: liters        forKey: @"fuelVolume"];

    if (filledUp == NO)
        [newEvent setValue: @(filledUp) forKey: @"filledUp"];

    if ([inheritedCost isEqualToNumber: zero] == NO)
        [newEvent setValue: inheritedCost forKey: @"inheritedCost"];

    if ([inheritedDistance isEqualToNumber: zero] == NO)
        [newEvent setValue: inheritedDistance forKey: @"inheritedDistance"];

    if ([inheritedFuelVolume isEqualToNumber: zero] == NO)
        [newEvent setValue: inheritedFuelVolume forKey: @"inheritedFuelVolume"];


    // Conditions for update of global odometer:
    // - when the new event is the youngest one
    // - when sum of all events equals the odometer value
    // - when forced to do so
    if (!forceOdometerUpdate)
        if ([[car valueForKey: @"odometer"] compare: [car valueForKey: @"distanceTotalSum"]] != NSOrderedDescending)
            forceOdometerUpdate = YES;

    // Update total car statistics
    [car setValue: [[car valueForKey: @"distanceTotalSum"]   decimalNumberByAdding: kilometers] forKey: @"distanceTotalSum"];
    [car setValue: [[car valueForKey: @"fuelVolumeTotalSum"] decimalNumberByAdding: liters]     forKey: @"fuelVolumeTotalSum"];

    // Update global odometer
    NSDecimalNumber *newOdometer = [car valueForKey: @"odometer"];

    if (forceOdometerUpdate)
        newOdometer = [newOdometer decimalNumberByAdding: kilometers];

    newOdometer = [newOdometer max: [car valueForKey: @"distanceTotalSum"]];

    [car setValue: newOdometer forKey: @"odometer"];

    return newEvent;
}


+ (void)removeEventFromArchive: (NSManagedObject*)event
        inManagedObjectContext: (NSManagedObjectContext*)moc
           forceOdometerUpdate: (BOOL)forceOdometerUpdate
{
    NSManagedObject *car        = [event valueForKey: @"car"];
    NSDecimalNumber *distance   = [event valueForKey: @"distance"];
    NSDecimalNumber *fuelVolume = [event valueForKey: @"fuelVolume"];
    NSDecimalNumber *zero       = [NSDecimalNumber zero];


    // Event will be deleted: update inherited distance/fuelVolume for younger events
    NSArray *youngerEvents = [self objectsForFetchRequest: [self fetchRequestForEventsForCar: car
                                                                                   afterDate: [event valueForKey: @"timestamp"]
                                                                                 dateMatches: NO
                                                                      inManagedObjectContext: moc]
                                   inManagedObjectContext: moc];

    NSUInteger row = [youngerEvents count];

    if (row > 0)
    {
        // Fill-up event deleted => propagate its inherited distance/volume
        if ([[event valueForKey: @"filledUp"] boolValue])
        {
            NSDecimalNumber *inheritedCost       = [event valueForKey: @"inheritedCost"];
            NSDecimalNumber *inheritedDistance   = [event valueForKey: @"inheritedDistance"];
            NSDecimalNumber *inheritedFuelVolume = [event valueForKey: @"inheritedFuelVolume"];
            NSDecimalNumber *zero = [NSDecimalNumber zero];

            if ([inheritedCost       compare: zero] == NSOrderedDescending ||
                [inheritedDistance   compare: zero] == NSOrderedDescending ||
                [inheritedFuelVolume compare: zero] == NSOrderedDescending)
            {
                while (row > 0)
                {
                    NSManagedObject *youngerEvent = [youngerEvents objectAtIndex: --row];

                    [youngerEvent setValue: [[youngerEvent valueForKey: @"inheritedCost"] decimalNumberByAdding: inheritedCost]
                                    forKey: @"inheritedCost"];

                    [youngerEvent setValue: [[youngerEvent valueForKey: @"inheritedDistance"] decimalNumberByAdding: inheritedDistance]
                                    forKey: @"inheritedDistance"];

                    [youngerEvent setValue: [[youngerEvent valueForKey: @"inheritedFuelVolume"] decimalNumberByAdding: inheritedFuelVolume]
                                    forKey: @"inheritedFuelVolume"];

                    if ([[youngerEvent valueForKey: @"filledUp"] boolValue] == YES)
                        break;
                }
            }
        }

        // Intermediate event deleted => remove distance/volume from inherited data
        else
        {
            while (row > 0)
            {
                NSManagedObject *youngerEvent = [youngerEvents objectAtIndex: --row];
                NSDecimalNumber *cost = [[event valueForKey: @"fuelVolume"] decimalNumberByMultiplyingBy: [event valueForKey: @"price"]];

                [youngerEvent setValue: [[[youngerEvent valueForKey: @"inheritedCost"] decimalNumberBySubtracting: cost] max: zero]
                                forKey: @"inheritedCost"];

                [youngerEvent setValue: [[[youngerEvent valueForKey: @"inheritedDistance"]   decimalNumberBySubtracting: distance] max: zero]
                                forKey: @"inheritedDistance"];

                [youngerEvent setValue: [[[youngerEvent valueForKey: @"inheritedFuelVolume"] decimalNumberBySubtracting: fuelVolume] max: zero]
                                forKey: @"inheritedFuelVolume"];

                if ([[youngerEvent valueForKey: @"filledUp"] boolValue] == YES)
                    break;
            }
        }
    }
    else
        forceOdometerUpdate = YES;


    // Conditions for update of global odometer:
    // - when youngest element gets deleted
    // - when sum of all events equals the odometer value
    // - when forced to do so
    if (!forceOdometerUpdate)
        if ([[car valueForKey: @"odometer"] compare: [car valueForKey: @"distanceTotalSum"]] != NSOrderedDescending)
            forceOdometerUpdate = YES;

    // Update total car statistics
    [car setValue: [[[car valueForKey: @"distanceTotalSum"]   decimalNumberBySubtracting: distance]   max: zero] forKey: @"distanceTotalSum"];
    [car setValue: [[[car valueForKey: @"fuelVolumeTotalSum"] decimalNumberBySubtracting: fuelVolume] max: zero] forKey: @"fuelVolumeTotalSum"];

    // Update global odometer
    if (forceOdometerUpdate)
        [car setValue: [[[car valueForKey: @"odometer"] decimalNumberBySubtracting: distance] max: zero] forKey: @"odometer"];

    // Delete the managed event object
    [moc deleteObject: event];
}



#pragma mark -
#pragma mark Unit Guessing from Current Locale



+ (KSVolume)volumeUnitFromLocale
{
    NSLocale *locale  = [NSLocale autoupdatingCurrentLocale];
    NSString *country = [locale objectForKey: NSLocaleCountryCode];

    if ([country isEqualToString: @"US"])
        return KSVolumeGalUS;
    else
        return KSVolumeLiter;
}


+ (KSFuelConsumption)fuelConsumptionUnitFromLocale
{
    NSString *country = [[NSLocale autoupdatingCurrentLocale] objectForKey: NSLocaleCountryCode];

    if ([country isEqualToString: @"US"])
        return KSFuelConsumptionMilesPerGallonUS;
    else
        return KSFuelConsumptionLitersPer100km;
}


+ (KSDistance)distanceUnitFromLocale
{
    NSString *country = [[NSLocale autoupdatingCurrentLocale] objectForKey: NSLocaleCountryCode];

    if ([country isEqualToString: @"US"])
        return KSDistanceStatuteMile;
    else
        return KSDistanceKilometer;
}



#pragma mark -
#pragma mark Conversion Constants



+ (NSDecimalNumber*)litersPerUSGallon
{
    static NSDecimalNumber *litersPerUSGallon = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        litersPerUSGallon = [NSDecimalNumber decimalNumberWithMantissa: 3785411784 exponent: -9 isNegative: NO];
    });

    return litersPerUSGallon;
}


+ (NSDecimalNumber*)litersPerImperialGallon
{
    static NSDecimalNumber *litersPerImperialGallon = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        litersPerImperialGallon = [NSDecimalNumber decimalNumberWithMantissa: 454609 exponent: -5 isNegative: NO];
    });

    return litersPerImperialGallon;
}


+ (NSDecimalNumber*)kilometersPerStatuteMile
{
    static NSDecimalNumber *kilometersPerStatuteMile = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        kilometersPerStatuteMile = [NSDecimalNumber decimalNumberWithMantissa: 1609344 exponent: -6 isNegative: NO];
    });

    return kilometersPerStatuteMile;
}



#pragma mark -
#pragma mark Conversion to/from Internal Data Format



+ (NSDecimalNumber*)litersForVolume: (NSDecimalNumber*)volume withUnit: (KSVolume)unit
{
    switch (unit)
    {
        case KSVolumeGalUS: return [volume decimalNumberByMultiplyingBy: [self litersPerUSGallon]];
        case KSVolumeGalUK: return [volume decimalNumberByMultiplyingBy: [self litersPerImperialGallon]];
        default:            return volume;
    }
}


+ (NSDecimalNumber*)volumeForLiters: (NSDecimalNumber*)liters withUnit: (KSVolume)unit
{
    switch (unit)
    {
        case KSVolumeGalUS: return [liters decimalNumberByDividingBy: [self litersPerUSGallon]];
        case KSVolumeGalUK: return [liters decimalNumberByDividingBy: [self litersPerImperialGallon]];
        default:            return liters;
    }
}


+ (NSDecimalNumber*)kilometersForDistance: (NSDecimalNumber*)distance withUnit: (KSDistance)unit
{
    if (unit == KSDistanceStatuteMile)
        return [distance decimalNumberByMultiplyingBy: [self kilometersPerStatuteMile]];
    else
        return distance;
}


+ (NSDecimalNumber*)distanceForKilometers: (NSDecimalNumber*)kilometers withUnit: (KSDistance)unit
{
    if (unit == KSDistanceStatuteMile)
        return [kilometers decimalNumberByDividingBy: [self kilometersPerStatuteMile]];
    else
        return kilometers;
}


+ (NSDecimalNumber*)pricePerLiter: (NSDecimalNumber*)price withUnit: (KSVolume)unit
{
    switch (unit)
    {
        case KSVolumeGalUS: return [price decimalNumberByDividingBy: [self litersPerUSGallon]];
        case KSVolumeGalUK: return [price decimalNumberByDividingBy: [self litersPerImperialGallon]];
        default:            return price;
    }
}


+ (NSDecimalNumber*)pricePerUnit: (NSDecimalNumber*)literPrice withUnit: (KSVolume)unit
{
    switch (unit)
    {
        case KSVolumeGalUS: return [literPrice decimalNumberByMultiplyingBy: [self litersPerUSGallon]];
        case KSVolumeGalUK: return [literPrice decimalNumberByMultiplyingBy: [self litersPerImperialGallon]];
        default:            return literPrice;
    }
}



#pragma mark -
#pragma mark Consumption/Efficiency Computation



+ (NSDecimalNumber*)consumptionForKilometers: (NSDecimalNumber*)kilometers
                                      Liters: (NSDecimalNumber*)liters
                                      inUnit: (KSFuelConsumption)unit
{
    NSDecimalNumberHandler *handler = [AppDelegate sharedConsumptionRoundingHandler];

    if (unit == KSFuelConsumptionLitersPer100km)
        return [[liters decimalNumberByMultiplyingByPowerOf10: 2] decimalNumberByDividingBy: kilometers withBehavior: handler];

    NSDecimalNumber *kmPerLiter = [kilometers decimalNumberByDividingBy: liters];

    switch (unit)
    {
        case KSFuelConsumptionMilesPerGallonUS:
            return [kmPerLiter decimalNumberByMultiplyingBy: [self mpgUSFromKML: kmPerLiter] withBehavior: handler];

        case KSFuelConsumptionMilesPerGallonUK:
            return [kmPerLiter decimalNumberByMultiplyingBy: [self mpgImperialFromKML: kmPerLiter] withBehavior: handler];

        default:
            return [kmPerLiter decimalNumberByRoundingAccordingToBehavior: handler];
    }
}


+ (NSDecimalNumber*)mpgUSFromKML: (NSDecimalNumber*)kmPerLiter
{
    static NSDecimalNumber *mpgUSFromKML = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        mpgUSFromKML = [NSDecimalNumber decimalNumberWithMantissa: 2352145833 exponent: -9 isNegative: NO];
    });

    return mpgUSFromKML;
}


+ (NSDecimalNumber*)mpgImperialFromKML: (NSDecimalNumber*)kmPerLiter
{
    static NSDecimalNumber *mpgImperialFromKML = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        mpgImperialFromKML = [NSDecimalNumber decimalNumberWithMantissa: 2737067636 exponent: -9 isNegative: NO];
    });

    return mpgImperialFromKML;
}



#pragma mark -
#pragma mark Unit Strings/Descriptions



+ (NSString*)consumptionUnitString: (KSFuelConsumption)unit
{
    switch (unit)
    {
        case KSFuelConsumptionLitersPer100km:     return _I18N (@"l/100km");
        case KSFuelConsumptionKilometersPerLiter: return _I18N (@"km/l");
        case KSFuelConsumptionMilesPerGallonUS:   return _I18N (@"mpg.us");
        default:                                  return _I18N (@"mpg.uk");
    }
}


+ (NSString*)consumptionUnitDescription: (KSFuelConsumption)unit
{
    switch (unit)
    {
        case KSFuelConsumptionLitersPer100km:     return _I18N (@"Liters per 100 Kilometers");
        case KSFuelConsumptionKilometersPerLiter: return _I18N (@"Kilometers per Liter");
        case KSFuelConsumptionMilesPerGallonUS:   return _I18N (@"Miles per Gallon (US)");
        default:                                  return _I18N (@"Miles per Gallon (UK)");
    }
}


+ (NSString*)consumptionUnitShadedTableViewCellDescription: (KSFuelConsumption)unit
{
    switch (unit)
    {
        case KSFuelConsumptionLitersPer100km:     return _I18N (@"Liters per 100 Kilometers");
        case KSFuelConsumptionKilometersPerLiter: return _I18N (@"Kilometers per Liter");
        default:                                  return _I18N (@"Miles per Gallon");
    }
}


+ (NSString*)fuelUnitString: (KSVolume)unit
{
    if (unit == KSVolumeLiter)
        return @"l";
    else
        return @"gal";
}


+ (NSString*)fuelUnitDescription: (KSVolume)unit discernGallons: (BOOL)discernGallons pluralization: (BOOL)plural
{
    if (plural)
    {
        switch (unit)
        {
            case KSVolumeLiter: return _I18N (@"Liters");
            case KSVolumeGalUS: return (discernGallons) ? _I18N (@"Gallons (US)") : _I18N (@"Gallons");
            default:            return (discernGallons) ? _I18N (@"Gallons (UK)") : _I18N (@"Gallons");
        }
    }
    else
    {
        switch (unit)
        {
            case KSVolumeLiter: return _I18N (@"Liter");
            case KSVolumeGalUS: return (discernGallons) ? _I18N (@"Gallon (US)") : _I18N (@"Gallon");
            default:            return (discernGallons) ? _I18N (@"Gallon (UK)") : _I18N (@"Gallon");
        }
    }
}


+ (NSString*)fuelPriceUnitDescription: (KSVolume)unit
{
    if (KSVolumeIsMetric (unit))
        return _I18N (@"Price per Liter");
    else
        return _I18N (@"Price per Gallon");
}


+ (NSString*)odometerUnitString: (KSDistance)unit
{
    if (KSDistanceIsMetric (unit))
        return @"km";
    else
        return @"mi";
}


+ (NSString*)odometerUnitDescription: (KSDistance)unit pluralization: (BOOL)plural
{
    if (plural)
        return (KSDistanceIsMetric (unit)) ? _I18N (@"Kilometers") : _I18N (@"Miles");
    else
        return (KSDistanceIsMetric (unit)) ? _I18N (@"Kilometer")  : _I18N (@"Mile");
}

@end
