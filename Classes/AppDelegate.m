// AppDelegate.m
//
// Kraftstoffrechner


#import "AppDelegate.h"
#import "CarViewController.h"
#import "FuelCalculatorController.h"
#import "CSVParser.h"
#import "CSVImporter.h"
#import "kraftstoff-Swift.h"


@implementation AppDelegate
{
    NSString    *errorDescription;
    UIAlertView *importAlert;
}

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;



#pragma mark -
#pragma mark Application Lifecycle


- (instancetype)init {
	self = [super init];
	if (self) {
		[[NSUserDefaults standardUserDefaults] registerDefaults:
			@{@"statisticTimeSpan":@6,
			@"preferredStatisticsPage":@1,
			@"preferredCarID":@"",
			@"recentDistance":[NSDecimalNumber zero],
			@"recentPrice":[NSDecimalNumber zero],
			@"recentFuelVolume":[NSDecimalNumber zero],
			@"recentFilledUp":@YES,
			@"editHelpCounter":@0,
			@"firstStartup":@YES}];
	}

	return self;
}

- (UIWindow *)window
{
	static UIWindow *appWindow = nil;
	static dispatch_once_t pred;

	dispatch_once (&pred, ^{
		appWindow = [[AppWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	});

	return appWindow;
}

- (void)commonLaunchInitialization:(NSDictionary *)launchOptions
{
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{
        
        [_window makeKeyAndVisible];

        // Switch once to the car view for new users
        if (launchOptions[UIApplicationLaunchOptionsURLKey] == nil) {

            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

            if ([defaults boolForKey:@"firstStartup"]) {

                if ([[defaults stringForKey:@"preferredCarID"] isEqualToString:@""])
                    _tabBarController.selectedIndex = 1;

                [defaults setObject:@NO forKey:@"firstStartup"];
            }
        }
    });
}


- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self commonLaunchInitialization:launchOptions];
    return YES;
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self commonLaunchInitialization:launchOptions];
    return YES;
}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [self saveContext:_managedObjectContext];
}


- (void)applicationWillTerminate:(UIApplication *)application
{
    [self saveContext:_managedObjectContext];
}



#pragma mark -
#pragma mark State Restoration



- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
    return YES;
}


- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
    NSInteger bundleVersion = [[[NSBundle mainBundle] infoDictionary][(NSString *)kCFBundleVersionKey] integerValue];
    NSInteger stateVersion = [[coder decodeObjectForKey:UIApplicationStateRestorationBundleVersionKey] integerValue];

    // we don't restore from iOS6 compatible or future versions of the App
    if (stateVersion >= 1572)
        if (stateVersion <= bundleVersion)
            return YES;

    return NO;
}



#pragma mark -
#pragma mark Data Import



- (void)showImportAlert
{
    if (importAlert == nil) {

        UIActivityIndicatorView *progress = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake (125, 50, 30, 30)];
        [progress setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [progress startAnimating];

        importAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Importing", @"")
                                                 message:@""
                                                delegate:nil
                                       cancelButtonTitle:nil
                                       otherButtonTitles:nil];

        [importAlert addSubview:progress];
        [importAlert show];
    }
}


- (void)hideImportAlert
{
    [importAlert dismissWithClickedButtonIndex:0 animated:YES];
    importAlert = nil;
}


// Read file contents from given URL, guess file encoding
- (NSString *)contentsOfURL:(NSURL *)url
{
    NSStringEncoding enc;

    NSError  *error  = nil;
    NSString *string = [NSString stringWithContentsOfURL:url usedEncoding:&enc error:&error];

    if (string == nil || error != nil) {

        error  = nil;
        string = [NSString stringWithContentsOfURL:url encoding:NSMacOSRomanStringEncoding error:&error];
    }

    return string;
}


// Removes files from the inbox
- (void)removeFileItemAtURL:(NSURL *)url
{
    if ([url isFileURL]) {

        NSError *error = nil;

        [[NSFileManager defaultManager] removeItemAtURL:url error:&error];

        if (error != nil)
            NSLog (@"%@", [error localizedDescription]);
    }
}


- (NSString *)pluralizedImportMessageForCarCount:(NSInteger)carCount eventCount:(NSInteger)eventCount
{
    NSString *format;
    
    if (carCount == 1)
        format = NSLocalizedString(((eventCount == 1) ? @"Imported %d car with %d fuel event."  : @"Imported %d car with %d fuel events."), @"");
    else
        format = NSLocalizedString(((eventCount == 1) ? @"Imported %d cars with %d fuel event." : @"Imported %d cars with %d fuel events."), @"");

    return [NSString stringWithFormat:format, carCount, eventCount];
}


- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    // Ugly, but don't allow nested imports
    if (importAlert) {
        [self removeFileItemAtURL:url];
        return NO;
    }

    // Show modal activity indicator while importing
    [self showImportAlert];

    // Import in context with private queue
    NSManagedObjectContext *parentContext = self.managedObjectContext;
    NSManagedObjectContext *importContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [importContext setParentContext:parentContext];

    [importContext performBlock: ^{

        // Read file contents from given URL, guess file encoding
        NSString *CSVString = [self contentsOfURL:url];
        [self removeFileItemAtURL:url];

        if (CSVString) {

            // Try to import data from CSV file
            CSVImporter *importer = [[CSVImporter alloc] init];

            NSInteger numCars   = 0;
            NSInteger numEvents = 0;

            BOOL success = [importer importFromCSVString:CSVString
                                            detectedCars:&numCars
                                          detectedEvents:&numEvents
                                               sourceURL:url
                                              inContext:importContext];

            // On success propagate changes to parent context
            if (success) {

                [self saveContext:importContext];
                [parentContext performBlock: ^{ [self saveContext:parentContext]; }];
            }

            dispatch_async (dispatch_get_main_queue(),
                            ^{
                               [self hideImportAlert];

                                NSString *title = (success)
                                                     ? NSLocalizedString(@"Import Finished", @"")
                                                     : NSLocalizedString(@"Import Failed", @"");

                                NSString *message = (success)
                                                     ? [self pluralizedImportMessageForCarCount:numCars eventCount:numEvents]
                                                     : NSLocalizedString(@"No valid CSV-data could be found.", @"");

                                [[[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                                  otherButtonTitles:nil] show];
                            });

        } else {

            dispatch_async (dispatch_get_main_queue(),
                            ^{
                                [self hideImportAlert];

                                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Import Failed", @"")
                                                            message:NSLocalizedString(@"Can't detect file encoding. Please try to convert your CSV-file to UTF8 encoding.", @"")
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                                  otherButtonTitles:nil] show];
                            });
        }
    }];

    // Treat imports as successfull first startups
    [[NSUserDefaults standardUserDefaults] setObject:@NO forKey:@"firstStartup"];
    return YES;
}



#pragma mark -
#pragma mark Application's Documents Directory



- (NSString *)applicationDocumentsDirectory
{
    return [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}



#pragma mark -
#pragma mark Shared Color Gradients



+ (CAGradientLayer*)shadowWithFrame:(CGRect)frame
                         darkFactor:(CGFloat)darkFactor
                        lightFactor:(CGFloat)lightFactor
                      fadeDownwards:(BOOL)downwards
{
    CAGradientLayer *newShadow = [[CAGradientLayer alloc] init];

    UIColor *darkColor = [UIColor colorWithWhite:0.0 alpha:darkFactor];
    UIColor *lightColor = [UIColor colorWithWhite:lightFactor alpha:0.0];

    newShadow.frame = frame;
    newShadow.backgroundColor = [UIColor clearColor].CGColor;
    newShadow.colors = downwards ? @[(id)[darkColor CGColor], (id)[lightColor CGColor]]
                                 : @[(id)[lightColor CGColor], (id)[darkColor CGColor]];
    return newShadow;
}


+ (CGGradientRef)backGradient
{
    static CGGradientRef backGradient = NULL;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        static CGFloat colorComponents [8] = { 25.0/255.0, 1.0,  25.0/255.0, 1.0,  40.0/255.0, 1.0,  117.0/255.0, 1.0 };
        static CGFloat colorLocations  [4] = { 0.0, 0.5, 0.5, 1.0 };

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();

        backGradient = CGGradientCreateWithColorComponents(colorSpace, colorComponents, colorLocations, 4);
        CGColorSpaceRelease (colorSpace);
    });

    return backGradient;

}


+ (CGGradientRef)blueGradient
{
    static CGGradientRef blueGradient = NULL;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        static CGFloat colorComponentsFlat [8] = { 0.360, 0.682, 0.870, 0.0,  0.466, 0.721, 0.870, 0.9 };

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

        blueGradient = CGGradientCreateWithColorComponents(colorSpace, colorComponentsFlat, NULL, 2);
        CGColorSpaceRelease (colorSpace);
    });

    return blueGradient;
}


+ (CGGradientRef)greenGradient
{
    static CGGradientRef greenGradient  = NULL;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        static CGFloat colorComponentsFlat [8] = { 0.662, 0.815, 0.502, 0.0,  0.662, 0.815, 0.502, 0.9 };

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

        greenGradient = CGGradientCreateWithColorComponents(colorSpace, colorComponentsFlat, NULL, 2);
        CGColorSpaceRelease (colorSpace);
    });

    return greenGradient;
}


+ (CGGradientRef)orangeGradient
{
    static CGGradientRef orangeGradient = NULL;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        static CGFloat colorComponentsFlat [8] = { 0.988, 0.662, 0.333, 0.0,  0.988, 0.662, 0.333, 0.9 };

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

        orangeGradient = CGGradientCreateWithColorComponents(colorSpace, colorComponentsFlat, NULL, 2);
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

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

        infoGradient = CGGradientCreateWithColorComponents(colorSpace, colorComponents, NULL, 2);
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

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

        knobGradient = CGGradientCreateWithColorComponents(colorSpace, colorComponents, NULL, 2);
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
        [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        [dateFormatter setDateStyle:NSDateFormatterLongStyle];
    });

    return dateFormatter;
}


+ (NSDateFormatter*)sharedDateFormatter
{
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
        [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    });

    return dateFormatter;
}


+ (NSDateFormatter*)sharedDateTimeFormatter
{
    static NSDateFormatter *dateTimeFormatter = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        dateTimeFormatter = [[NSDateFormatter alloc] init];
        [dateTimeFormatter setTimeStyle:NSDateFormatterShortStyle];
        [dateTimeFormatter setDateStyle:NSDateFormatterMediumStyle];
    });

    return dateTimeFormatter;
}


+ (NSNumberFormatter*)sharedDistanceFormatter
{
    static NSNumberFormatter *distanceFormatter = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        distanceFormatter = [[NSNumberFormatter alloc] init];
        [distanceFormatter setGeneratesDecimalNumbers:YES];
        [distanceFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
        [distanceFormatter setMinimumFractionDigits:1];
        [distanceFormatter setMaximumFractionDigits:1];
    });

    return distanceFormatter;
}


+ (NSNumberFormatter*)sharedFuelVolumeFormatter
{
    static NSNumberFormatter *fuelVolumeFormatter = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        fuelVolumeFormatter = [[NSNumberFormatter alloc] init];
        [fuelVolumeFormatter setGeneratesDecimalNumbers:YES];
        [fuelVolumeFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
        [fuelVolumeFormatter setMinimumFractionDigits:2];
        [fuelVolumeFormatter setMaximumFractionDigits:2];
    });

    return fuelVolumeFormatter;
}


+ (NSNumberFormatter*)sharedPreciseFuelVolumeFormatter
{
    static NSNumberFormatter *preciseFuelVolumeFormatter = nil;
    static dispatch_once_t pred;
    
    dispatch_once (&pred, ^{
        
        preciseFuelVolumeFormatter = [[NSNumberFormatter alloc] init];
        [preciseFuelVolumeFormatter setGeneratesDecimalNumbers:YES];
        [preciseFuelVolumeFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
        [preciseFuelVolumeFormatter setMinimumFractionDigits:3];
        [preciseFuelVolumeFormatter setMaximumFractionDigits:3];
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
        [currencyFormatter setGeneratesDecimalNumbers:YES];
        [currencyFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
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
        [axisCurrencyFormatter setGeneratesDecimalNumbers:YES];
        [axisCurrencyFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [axisCurrencyFormatter setCurrencySymbol:@""];
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
        [editPreciseCurrencyFormatter setGeneratesDecimalNumbers:YES];
        [editPreciseCurrencyFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [editPreciseCurrencyFormatter setMinimumFractionDigits:fractionDigits];
        [editPreciseCurrencyFormatter setMaximumFractionDigits:fractionDigits];
        [editPreciseCurrencyFormatter setCurrencySymbol:@""];

        // Needed e.g. for CHF
        [editPreciseCurrencyFormatter setRoundingIncrement:@0];

        // Needed since NSNumberFormatters can't parse their own € output
        [editPreciseCurrencyFormatter setLenient:YES];
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
        [preciseCurrencyFormatter setGeneratesDecimalNumbers:YES];
        [preciseCurrencyFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [preciseCurrencyFormatter setMinimumFractionDigits:fractionDigits];
        [preciseCurrencyFormatter setMaximumFractionDigits:fractionDigits];

        // Needed e.g. for CHF
        [preciseCurrencyFormatter setRoundingIncrement:@0];

        // Needed since NSNumberFormatters can't parse their own € output
        [preciseCurrencyFormatter setLenient:YES];
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
        consumptionRoundingHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundPlain
                                                                                            scale:fractionDigits
                                                                                 raiseOnExactness:NO
                                                                                  raiseOnOverflow:NO
                                                                                 raiseOnUnderflow:NO
                                                                              raiseOnDivideByZero:NO];
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
        priceRoundingHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                      scale:fractionDigits
                                                                           raiseOnExactness:NO
                                                                            raiseOnOverflow:NO
                                                                           raiseOnUnderflow:NO
                                                                        raiseOnDivideByZero:NO];
    });

    return priceRoundingHandler;
}



#pragma mark -
#pragma mark Core Data Support



- (void)alertView:(UIAlertView*)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [NSException raise:NSGenericException format:@"%@", errorDescription];
    abort();
}


- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext == nil) {

        NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;

        if (coordinator != nil) {

            _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            [_managedObjectContext setPersistentStoreCoordinator:coordinator];
            [_managedObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        }
    }

    return _managedObjectContext;
}


- (NSManagedObjectModel*)managedObjectModel
{
    if (_managedObjectModel == nil) {

        NSString *modelPath = [[NSBundle mainBundle] pathForResource:@"Kraftstoffrechner" ofType:@"momd"];
        _managedObjectModel  = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:modelPath]];
    }

    return _managedObjectModel;
}


- (NSPersistentStoreCoordinator*)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator == nil) {

        NSError *error = nil;
        NSURL *storeURL = [NSURL fileURLWithPath:[[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"Kraftstoffrechner.sqlite"]];
        NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES};

        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];

        if (! [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                       configuration:nil
                                                                 URL:storeURL
                                                             options:options
                                                               error:&error]) {

            errorDescription = [error localizedDescription];
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Can't Open Database", @"")
                                        message:NSLocalizedString(@"Sorry, the application database cannot be opened. Please quit the application with the Home button.", @"")
                                       delegate:self
                              cancelButtonTitle:nil
                              otherButtonTitles:@"Ok", nil] show];
        }
    }

    return _persistentStoreCoordinator;
}


- (BOOL)saveContext:(NSManagedObjectContext *)context
{
    if (context != nil && [context hasChanges]) {

        NSError *error = nil;

        if (![context save:&error]) {

            errorDescription = [error localizedDescription];
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Can't Save Database", @"")
                                        message:NSLocalizedString(@"Sorry, the application database cannot be saved. Please quit the application with the Home button.", @"")
                                       delegate:self
                              cancelButtonTitle:nil
                              otherButtonTitles:@"Ok", nil] show];
        }

        return YES;
    }

    return NO;
}


- (NSString *)modelIdentifierForManagedObject:(NSManagedObject *)object
{
    NSManagedObjectID *objectID = object.objectID;

    if (objectID && ! [objectID isTemporaryID])
        return [[objectID URIRepresentation] absoluteString];
    else
        return nil;
}


- (NSManagedObject *)managedObjectForModelIdentifier:(NSString *)identifier
{
    NSURL *objectURL = [NSURL URLWithString:identifier];

    if ([[objectURL scheme] isEqualToString:@"x-coredata"]) {

        NSManagedObjectID *objectID = [self.persistentStoreCoordinator managedObjectIDForURIRepresentation:objectURL];

        if (objectID) {
            NSError *error = nil;
            NSManagedObject *object = [self.managedObjectContext existingObjectWithID:objectID error:&error];

            return object;
        }
    }

    return nil;
}


+ (NSManagedObject *)existingObject:(NSManagedObject *)object inManagedObjectContext:(NSManagedObjectContext *)moc
{
    if (object.isDeleted)
        return nil;
    else
        return [moc existingObjectWithID:object.objectID error:NULL];
}



#pragma mark -
#pragma mark Preconfigured Core Data Fetches



+ (NSFetchRequest*)fetchRequestForCarsInManagedObjectContext:(NSManagedObjectContext *)moc
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

    // Entity name
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"car" inManagedObjectContext:moc];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:32];

    // Sorting keys
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES];
    NSArray *sortDescriptors = @[sortDescriptor];
    [fetchRequest setSortDescriptors:sortDescriptors];

    return fetchRequest;
}



+ (NSFetchRequest*)fetchRequestForEventsForCar:(NSManagedObject *)car
                                       andDate:(NSDate *)date
                                dateComparator:(NSString *)dateCompare
                                     fetchSize:(NSInteger)fetchSize
                        inManagedObjectContext:(NSManagedObjectContext *)moc
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

    // Entity name
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"fuelEvent" inManagedObjectContext:moc];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:fetchSize];

    // Predicates
    NSPredicate *parentPredicate = [NSPredicate predicateWithFormat:@"car == %@", car];

    if (date == nil) {

        [fetchRequest setPredicate:parentPredicate];

    } else {

        NSString *dateDescription  = [[NSExpression expressionForConstantValue:date] description];
        NSPredicate *datePredicate = [NSPredicate predicateWithFormat:[NSString stringWithFormat:@"timestamp %@ %@", dateCompare, dateDescription]];

        [fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:@[parentPredicate, datePredicate]]];
    }

    // Sorting keys
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];

    [fetchRequest setSortDescriptors:sortDescriptors];

    return fetchRequest;
}



+ (NSFetchRequest*)fetchRequestForEventsForCar:(NSManagedObject *)car
                                     afterDate:(NSDate *)date
                                   dateMatches:(BOOL)dateMatches
                        inManagedObjectContext:(NSManagedObjectContext *)moc
{
    return [self fetchRequestForEventsForCar:car
                                     andDate:date
                              dateComparator:(dateMatches) ? @">=" : @">"
                                   fetchSize:128
                      inManagedObjectContext:moc];
}


+ (NSFetchRequest*)fetchRequestForEventsForCar:(NSManagedObject *)car
                                    beforeDate:(NSDate *)date
                                   dateMatches:(BOOL)dateMatches
                        inManagedObjectContext:(NSManagedObjectContext *)moc
{
    return [self fetchRequestForEventsForCar:car
                                     andDate:date
                              dateComparator:(dateMatches) ? @"<=" : @"<"
                                   fetchSize:8
                      inManagedObjectContext:moc];
}


+ (NSFetchedResultsController *)fetchedResultsControllerForCarsInContext:(NSManagedObjectContext *)moc
{
    NSFetchRequest *fetchRequest = [self fetchRequestForCarsInManagedObjectContext:moc];

    // No section names; perform fetch without cache
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                                               managedObjectContext:moc
                                                                                                 sectionNameKeyPath:nil
                                                                                                          cacheName:nil];


    // Perform the Core Data fetch
    NSError *error = nil;

    if (! [fetchedResultsController performFetch:&error])
        [NSException raise:NSGenericException format:@"%@", [error localizedDescription]];

    return fetchedResultsController;
}


+ (NSArray *)objectsForFetchRequest:(NSFetchRequest*)fetchRequest
            inManagedObjectContext:(NSManagedObjectContext *)moc
{
    NSError *error = nil;
    NSArray *fetchedObjects = [moc executeFetchRequest:fetchRequest error:&error];

    if (error != nil)
        [NSException raise:NSGenericException format:@"%@", [error localizedDescription]];

    return fetchedObjects;
}


+ (BOOL)managedObjectContext:(NSManagedObjectContext *)moc
        containsEventWithCar:(NSManagedObject *)car
                     andDate:(NSDate *)date;
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

    // Entity name
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"fuelEvent"
                                              inManagedObjectContext:moc];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:2];

    // Predicates
    NSPredicate *parentPredicate = [NSPredicate predicateWithFormat:@"car == %@", car];

    NSString *dateDescription = [[NSExpression expressionForConstantValue:date] description];
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:[NSString stringWithFormat:@"timestamp == %@", dateDescription]];

    [fetchRequest setPredicate:
        [NSCompoundPredicate andPredicateWithSubpredicates:
            @[parentPredicate, datePredicate]]];

    // Check whether fetch would reveal any event objects
    NSError *error = nil;
    NSUInteger objectCount = [moc countForFetchRequest:fetchRequest error:&error];

    if (error != nil)
        [NSException raise:NSGenericException format:@"%@", [error localizedDescription]];

    return (objectCount > 0);
}



#pragma mark -
#pragma mark Core Data Updates



+ (NSManagedObject *)addToArchiveWithCar:(NSManagedObject *)car
                                    date:(NSDate *)date
                                distance:(NSDecimalNumber *)distance
                                   price:(NSDecimalNumber *)price
                              fuelVolume:(NSDecimalNumber *)fuelVolume
                                filledUp:(BOOL)filledUp
                  inManagedObjectContext:(NSManagedObjectContext *)moc
                     forceOdometerUpdate:(BOOL)forceOdometerUpdate
{
    NSDecimalNumber *zero = [NSDecimalNumber zero];


    // Convert distance and fuelvolume to SI units
    KSVolume fuelUnit       = (KSVolume)[[car valueForKey:@"fuelUnit"]     integerValue];
    KSDistance odometerUnit = (KSDistance)[[car valueForKey:@"odometerUnit"] integerValue];

    NSDecimalNumber *liters        = [AppDelegate litersForVolume:fuelVolume withUnit:fuelUnit];
    NSDecimalNumber *kilometers    = [AppDelegate kilometersForDistance:distance withUnit:odometerUnit];
    NSDecimalNumber *pricePerLiter = [AppDelegate pricePerLiter:price withUnit:fuelUnit];

    NSDecimalNumber *inheritedCost       = zero;
    NSDecimalNumber *inheritedDistance   = zero;
    NSDecimalNumber *inheritedFuelVolume = zero;


    // Compute inherited data from older element
    {
        // Fetch older events
        NSArray *olderEvents = [self objectsForFetchRequest:[self fetchRequestForEventsForCar:car
                                                                                    beforeDate:date
                                                                                   dateMatches:NO
                                                                        inManagedObjectContext:moc]
                                     inManagedObjectContext:moc];

        if (olderEvents.count) {

            NSManagedObject *olderEvent = olderEvents[0];

            if ([[olderEvent valueForKey:@"filledUp"] boolValue] == NO) {
                NSDecimalNumber *cost = [[olderEvent valueForKey:@"fuelVolume"] decimalNumberByMultiplyingBy:[olderEvent valueForKey:@"price"]];

                inheritedCost       = [cost decimalNumberByAdding:[olderEvent valueForKey:@"inheritedCost"]];
                inheritedDistance   = [[olderEvent valueForKey:@"distance"]   decimalNumberByAdding:[olderEvent valueForKey:@"inheritedDistance"]];
                inheritedFuelVolume = [[olderEvent valueForKey:@"fuelVolume"] decimalNumberByAdding:[olderEvent valueForKey:@"inheritedFuelVolume"]];
            }
        }
    }


    // Update inherited distance/volume for younger events, probably mark the car odometer for an update
    {
        // Fetch younger events
        NSArray *youngerEvents = [self objectsForFetchRequest:[self fetchRequestForEventsForCar:car
                                                                                       afterDate:date
                                                                                     dateMatches:NO
                                                                          inManagedObjectContext:moc]
                                       inManagedObjectContext:moc];

        if (youngerEvents.count) {

            NSDecimalNumber *deltaCost = (filledUp)
                ? [[NSDecimalNumber zero] decimalNumberBySubtracting:inheritedCost]
                : [liters decimalNumberByMultiplyingBy:pricePerLiter];

            NSDecimalNumber *deltaDistance = (filledUp)
                ? [[NSDecimalNumber zero] decimalNumberBySubtracting:inheritedDistance]
                : kilometers;

            NSDecimalNumber *deltaFuelVolume = (filledUp)
                ? [[NSDecimalNumber zero] decimalNumberBySubtracting:inheritedFuelVolume]
                : liters;

            for (NSUInteger row = [youngerEvents count]; row > 0; ) {

                NSManagedObject *youngerEvent = youngerEvents[--row];

                [youngerEvent setValue:[[[youngerEvent valueForKey:@"inheritedCost"] decimalNumberByAdding:deltaCost] max:zero]
                                forKey:@"inheritedCost"];

                [youngerEvent setValue:[[[youngerEvent valueForKey:@"inheritedDistance"] decimalNumberByAdding:deltaDistance] max:zero]
                                forKey:@"inheritedDistance"];

                [youngerEvent setValue:[[[youngerEvent valueForKey:@"inheritedFuelVolume"] decimalNumberByAdding:deltaFuelVolume] max:zero]
                                forKey:@"inheritedFuelVolume"];

                if ([[youngerEvent valueForKey:@"filledUp"] boolValue] == YES)
                    break;
            }
        }

        // New event will be the youngest one => update odometer too
        else
            forceOdometerUpdate = YES;
    }


    // Create new managed object for this event
    NSManagedObject *newEvent = [NSEntityDescription insertNewObjectForEntityForName:@"fuelEvent"
                                                              inManagedObjectContext:moc];

    [newEvent setValue:car           forKey:@"car"];
    [newEvent setValue:date          forKey:@"timestamp"];
    [newEvent setValue:kilometers    forKey:@"distance"];
    [newEvent setValue:pricePerLiter forKey:@"price"];
    [newEvent setValue:liters        forKey:@"fuelVolume"];

    if (filledUp == NO)
        [newEvent setValue:@(filledUp) forKey:@"filledUp"];

    if ([inheritedCost isEqualToNumber:zero] == NO)
        [newEvent setValue:inheritedCost forKey:@"inheritedCost"];

    if ([inheritedDistance isEqualToNumber:zero] == NO)
        [newEvent setValue:inheritedDistance forKey:@"inheritedDistance"];

    if ([inheritedFuelVolume isEqualToNumber:zero] == NO)
        [newEvent setValue:inheritedFuelVolume forKey:@"inheritedFuelVolume"];


    // Conditions for update of global odometer:
    // - when the new event is the youngest one
    // - when sum of all events equals the odometer value
    // - when forced to do so
    if (!forceOdometerUpdate)
        if ([[car valueForKey:@"odometer"] compare:[car valueForKey:@"distanceTotalSum"]] != NSOrderedDescending)
            forceOdometerUpdate = YES;

    // Update total car statistics
    [car setValue:[[car valueForKey:@"distanceTotalSum"]   decimalNumberByAdding:kilometers] forKey:@"distanceTotalSum"];
    [car setValue:[[car valueForKey:@"fuelVolumeTotalSum"] decimalNumberByAdding:liters]     forKey:@"fuelVolumeTotalSum"];

    // Update global odometer
    NSDecimalNumber *newOdometer = [car valueForKey:@"odometer"];

    if (forceOdometerUpdate)
        newOdometer = [newOdometer decimalNumberByAdding:kilometers];

    newOdometer = [newOdometer max:[car valueForKey:@"distanceTotalSum"]];

    [car setValue:newOdometer forKey:@"odometer"];

    return newEvent;
}


+ (void)removeEventFromArchive:(NSManagedObject *)event
        inManagedObjectContext:(NSManagedObjectContext *)moc
           forceOdometerUpdate:(BOOL)forceOdometerUpdate
{
    NSManagedObject *car = [event valueForKey:@"car"];
    NSDecimalNumber *distance = [event valueForKey:@"distance"];
    NSDecimalNumber *fuelVolume = [event valueForKey:@"fuelVolume"];
    NSDecimalNumber *zero = [NSDecimalNumber zero];

    // catch nil events
    if (!event)
        return;

    // Event will be deleted:update inherited distance/fuelVolume for younger events
    NSArray *youngerEvents = [self objectsForFetchRequest:[self fetchRequestForEventsForCar:car
                                                                                  afterDate:[event valueForKey:@"timestamp"]
                                                                                dateMatches:NO
                                                                     inManagedObjectContext:moc]
                                   inManagedObjectContext:moc];

    NSUInteger row = [youngerEvents count];

    if (row > 0) {

        // Fill-up event deleted => propagate its inherited distance/volume
        if ([[event valueForKey:@"filledUp"] boolValue]) {

            NSDecimalNumber *inheritedCost       = [event valueForKey:@"inheritedCost"];
            NSDecimalNumber *inheritedDistance   = [event valueForKey:@"inheritedDistance"];
            NSDecimalNumber *inheritedFuelVolume = [event valueForKey:@"inheritedFuelVolume"];
            NSDecimalNumber *zero = [NSDecimalNumber zero];

            if ([inheritedCost       compare:zero] == NSOrderedDescending ||
                [inheritedDistance   compare:zero] == NSOrderedDescending ||
                [inheritedFuelVolume compare:zero] == NSOrderedDescending) {

                while (row > 0) {
                    NSManagedObject *youngerEvent = youngerEvents[--row];

                    [youngerEvent setValue:[[youngerEvent valueForKey:@"inheritedCost"] decimalNumberByAdding:inheritedCost]
                                    forKey:@"inheritedCost"];

                    [youngerEvent setValue:[[youngerEvent valueForKey:@"inheritedDistance"] decimalNumberByAdding:inheritedDistance]
                                    forKey:@"inheritedDistance"];

                    [youngerEvent setValue:[[youngerEvent valueForKey:@"inheritedFuelVolume"] decimalNumberByAdding:inheritedFuelVolume]
                                    forKey:@"inheritedFuelVolume"];

                    if ([[youngerEvent valueForKey:@"filledUp"] boolValue] == YES)
                        break;
                }
            }

        // Intermediate event deleted => remove distance/volume from inherited data
        } else {

            while (row > 0) {

                NSManagedObject *youngerEvent = youngerEvents[--row];
                NSDecimalNumber *cost = [[event valueForKey:@"fuelVolume"] decimalNumberByMultiplyingBy:[event valueForKey:@"price"]];

                [youngerEvent setValue:[[[youngerEvent valueForKey:@"inheritedCost"] decimalNumberBySubtracting:cost] max:zero]
                                forKey:@"inheritedCost"];

                [youngerEvent setValue:[[[youngerEvent valueForKey:@"inheritedDistance"]   decimalNumberBySubtracting:distance] max:zero]
                                forKey:@"inheritedDistance"];

                [youngerEvent setValue:[[[youngerEvent valueForKey:@"inheritedFuelVolume"] decimalNumberBySubtracting:fuelVolume] max:zero]
                                forKey:@"inheritedFuelVolume"];

                if ([[youngerEvent valueForKey:@"filledUp"] boolValue] == YES)
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
        if ([[car valueForKey:@"odometer"] compare:[car valueForKey:@"distanceTotalSum"]] != NSOrderedDescending)
            forceOdometerUpdate = YES;

    // Update total car statistics
    [car setValue:[[[car valueForKey:@"distanceTotalSum"]   decimalNumberBySubtracting:distance]   max:zero] forKey:@"distanceTotalSum"];
    [car setValue:[[[car valueForKey:@"fuelVolumeTotalSum"] decimalNumberBySubtracting:fuelVolume] max:zero] forKey:@"fuelVolumeTotalSum"];

    // Update global odometer
    if (forceOdometerUpdate)
        [car setValue:[[[car valueForKey:@"odometer"] decimalNumberBySubtracting:distance] max:zero] forKey:@"odometer"];

    // Delete the managed event object
    [moc deleteObject:event];
}



#pragma mark -
#pragma mark Unit Guessing from Current Locale



+ (KSVolume)volumeUnitFromLocale
{
    NSLocale *locale  = [NSLocale autoupdatingCurrentLocale];
    NSString *country = [locale objectForKey:NSLocaleCountryCode];

    if ([country isEqualToString:@"US"])
        return KSVolumeGalUS;
    else
        return KSVolumeLiter;
}


+ (KSFuelConsumption)fuelConsumptionUnitFromLocale
{
    NSString *country = [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleCountryCode];

    if ([country isEqualToString:@"US"])
        return KSFuelConsumptionMilesPerGallonUS;
    else
        return KSFuelConsumptionLitersPer100km;
}


+ (KSDistance)distanceUnitFromLocale
{
    NSString *country = [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleCountryCode];

    if ([country isEqualToString:@"US"])
        return KSDistanceStatuteMile;
    else
        return KSDistanceKilometer;
}



#pragma mark -
#pragma mark Conversion Constants



+ (NSDecimalNumber *)litersPerUSGallon
{
    static NSDecimalNumber *litersPerUSGallon = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        litersPerUSGallon = [NSDecimalNumber decimalNumberWithMantissa:3785411784 exponent: -9 isNegative:NO];
    });

    return litersPerUSGallon;
}


+ (NSDecimalNumber *)litersPerImperialGallon
{
    static NSDecimalNumber *litersPerImperialGallon = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        litersPerImperialGallon = [NSDecimalNumber decimalNumberWithMantissa:454609 exponent: -5 isNegative:NO];
    });

    return litersPerImperialGallon;
}


+ (NSDecimalNumber *)kilometersPerStatuteMile
{
    static NSDecimalNumber *kilometersPerStatuteMile = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        kilometersPerStatuteMile = [NSDecimalNumber decimalNumberWithMantissa:1609344 exponent: -6 isNegative:NO];
    });

    return kilometersPerStatuteMile;
}


+ (NSDecimalNumber *)kilometersPerLiterToMilesPerUSGallon
{
    static NSDecimalNumber *mpgUSFromKML = nil;
    static dispatch_once_t pred;
    
    dispatch_once (&pred, ^{
        
        mpgUSFromKML = [NSDecimalNumber decimalNumberWithMantissa:2352145833 exponent: -9 isNegative:NO];
    });
    
    return mpgUSFromKML;
}


+ (NSDecimalNumber *)kilometersPerLiterToMilesPerImperialGallon
{
    static NSDecimalNumber *mpgImperialFromKML = nil;
    static dispatch_once_t pred;
    
    dispatch_once (&pred, ^{
        
        mpgImperialFromKML = [NSDecimalNumber decimalNumberWithMantissa:2737067636 exponent: -9 isNegative:NO];
    });
    
    return mpgImperialFromKML;
}


+ (NSDecimalNumber *)litersPer100KilometersToMilesPer10KUSGallon
{
    static NSDecimalNumber *gp10kUsFromLP100 = nil;
    static dispatch_once_t pred;
    
    dispatch_once (&pred, ^{
        
        gp10kUsFromLP100 = [NSDecimalNumber decimalNumberWithMantissa:425170068027 exponent: -10 isNegative:NO];
    });
    
    return gp10kUsFromLP100;
}


+ (NSDecimalNumber *)litersPer100KilometersToMilesPer10KImperialGallon
{
    static NSDecimalNumber *gp10kImperialFromLP100 = nil;
    static dispatch_once_t pred;
    
    dispatch_once (&pred, ^{
        
        gp10kImperialFromLP100 = [NSDecimalNumber decimalNumberWithMantissa:353982300885 exponent: -10 isNegative:NO];
    });
    
    return gp10kImperialFromLP100;
}



#pragma mark -
#pragma mark Conversion to/from Internal Data Format



+ (NSDecimalNumber *)litersForVolume:(NSDecimalNumber *)volume withUnit:(KSVolume)unit
{
    switch (unit) {

        case KSVolumeGalUS: return [volume decimalNumberByMultiplyingBy:[self litersPerUSGallon]];
        case KSVolumeGalUK: return [volume decimalNumberByMultiplyingBy:[self litersPerImperialGallon]];
        default:            return volume;
    }
}


+ (NSDecimalNumber *)volumeForLiters:(NSDecimalNumber *)liters withUnit:(KSVolume)unit
{
    switch (unit) {

        case KSVolumeGalUS: return [liters decimalNumberByDividingBy:[self litersPerUSGallon]];
        case KSVolumeGalUK: return [liters decimalNumberByDividingBy:[self litersPerImperialGallon]];
        default:            return liters;
    }
}


+ (NSDecimalNumber *)kilometersForDistance:(NSDecimalNumber *)distance withUnit:(KSDistance)unit
{
    if (unit == KSDistanceStatuteMile)
        return [distance decimalNumberByMultiplyingBy:[self kilometersPerStatuteMile]];
    else
        return distance;
}


+ (NSDecimalNumber *)distanceForKilometers:(NSDecimalNumber *)kilometers withUnit:(KSDistance)unit
{
    if (unit == KSDistanceStatuteMile)
        return [kilometers decimalNumberByDividingBy:[self kilometersPerStatuteMile]];
    else
        return kilometers;
}


+ (NSDecimalNumber *)pricePerLiter:(NSDecimalNumber *)price withUnit:(KSVolume)unit
{
    switch (unit) {

        case KSVolumeGalUS: return [price decimalNumberByDividingBy:[self litersPerUSGallon]];
        case KSVolumeGalUK: return [price decimalNumberByDividingBy:[self litersPerImperialGallon]];
        default:            return price;
    }
}


+ (NSDecimalNumber *)pricePerUnit:(NSDecimalNumber *)literPrice withUnit:(KSVolume)unit
{
    switch (unit) {

        case KSVolumeGalUS: return [literPrice decimalNumberByMultiplyingBy:[self litersPerUSGallon]];
        case KSVolumeGalUK: return [literPrice decimalNumberByMultiplyingBy:[self litersPerImperialGallon]];
        default:            return literPrice;
    }
}



#pragma mark -
#pragma mark Consumption/Efficiency Computation



+ (NSDecimalNumber *)consumptionForKilometers:(NSDecimalNumber *)kilometers
                                      Liters:(NSDecimalNumber *)liters
                                      inUnit:(KSFuelConsumption)unit
{
    NSDecimalNumberHandler *handler = [AppDelegate sharedConsumptionRoundingHandler];


    if ([kilometers compare:[NSDecimalNumber zero]] != NSOrderedDescending)
       return [NSDecimalNumber notANumber];

    if ([liters compare:[NSDecimalNumber zero]] != NSOrderedDescending)
        return [NSDecimalNumber notANumber];

    if (KSFuelConsumptionIsEfficiency (unit)) {

        NSDecimalNumber *kmPerLiter = [kilometers decimalNumberByDividingBy:liters];
        
        switch (unit) {

            case KSFuelConsumptionKilometersPerLiter:
                return [kmPerLiter decimalNumberByRoundingAccordingToBehavior:handler];
                
            case KSFuelConsumptionMilesPerGallonUS:
                return [kmPerLiter decimalNumberByMultiplyingBy:[self kilometersPerLiterToMilesPerUSGallon] withBehavior:handler];
                
            default: // KSFuelConsumptionMilesPerGallonUK:
                return [kmPerLiter decimalNumberByMultiplyingBy:[self kilometersPerLiterToMilesPerImperialGallon] withBehavior:handler];
        }

    } else {

        NSDecimalNumber *literPer100km = [[liters decimalNumberByMultiplyingByPowerOf10:2] decimalNumberByDividingBy:kilometers];
    
        switch (unit) {

            case KSFuelConsumptionLitersPer100km:
                return [literPer100km decimalNumberByRoundingAccordingToBehavior:handler];

            case KSFuelConsumptionGP10KUS:
                return [literPer100km decimalNumberByMultiplyingBy:[self litersPer100KilometersToMilesPer10KUSGallon] withBehavior:handler];

            default: // KSFuelConsumptionGP10KUK:
                return [literPer100km decimalNumberByMultiplyingBy:[self litersPer100KilometersToMilesPer10KImperialGallon] withBehavior:handler];
        }
    }    
}



#pragma mark -
#pragma mark Unit Strings/Descriptions



+ (NSString *)consumptionUnitString:(KSFuelConsumption)unit
{
    switch (unit) {

        case KSFuelConsumptionLitersPer100km: return NSLocalizedString(@"l/100km", @"");
        case KSFuelConsumptionKilometersPerLiter: return NSLocalizedString(@"km/l", @"");
        case KSFuelConsumptionMilesPerGallonUS: return NSLocalizedString(@"mpg", @"");
        case KSFuelConsumptionMilesPerGallonUK: return NSLocalizedString(@"mpg.uk", @"");
        case KSFuelConsumptionGP10KUS: return NSLocalizedString(@"gp10k", @"");
        case KSFuelConsumptionGP10KUK: return NSLocalizedString(@"gp10k.uk", @"");
        default: return @"";
    }
}


+ (NSString *)consumptionUnitDescription:(KSFuelConsumption)unit
{
    switch (unit) {

        case KSFuelConsumptionLitersPer100km: return NSLocalizedString(@"Liters per 100 Kilometers", @"");
        case KSFuelConsumptionKilometersPerLiter: return NSLocalizedString(@"Kilometers per Liter", @"");
        case KSFuelConsumptionMilesPerGallonUS: return NSLocalizedString(@"Miles per Gallon (US)", @"");
        case KSFuelConsumptionMilesPerGallonUK: return NSLocalizedString(@"Miles per Gallon (UK)", @"");
        case KSFuelConsumptionGP10KUS: return NSLocalizedString(@"Gallons per 10000 Miles (US)", @"");
        case KSFuelConsumptionGP10KUK: return NSLocalizedString(@"Gallons per 10000 Miles (UK)", @"");
        default: return @"";
    }
}


+ (NSString *)consumptionUnitShortDescription:(KSFuelConsumption)unit;
{
    switch (unit) {

        case KSFuelConsumptionLitersPer100km: return NSLocalizedString(@"Liters per 100 Kilometers", @"");
        case KSFuelConsumptionKilometersPerLiter: return NSLocalizedString(@"Kilometers per Liter", @"");
        case KSFuelConsumptionMilesPerGallonUS: return NSLocalizedString(@"Miles per Gallon (US)", @"");
        case KSFuelConsumptionMilesPerGallonUK: return NSLocalizedString(@"Miles per Gallon (UK)", @"");
        case KSFuelConsumptionGP10KUS: return NSLocalizedString(@"gp10k_short_us", @"");
        case KSFuelConsumptionGP10KUK: return NSLocalizedString(@"gp10k_short_uk", @"");
        default: return @"";
    }
}


+ (NSString *)consumptionUnitAccesibilityDescription:(KSFuelConsumption)unit
{
    switch (unit) {

        case KSFuelConsumptionLitersPer100km: return NSLocalizedString(@"Liters per 100 Kilometers", @"");
        case KSFuelConsumptionKilometersPerLiter: return NSLocalizedString(@"Kilometers per Liter", @"");
        case KSFuelConsumptionMilesPerGallonUS:
        case KSFuelConsumptionMilesPerGallonUK: return NSLocalizedString(@"Miles per Gallon", @"");
        case KSFuelConsumptionGP10KUS:
        case KSFuelConsumptionGP10KUK: return NSLocalizedString(@"Gallons per 10000 Miles", @"");
        default: return @"";
    }
}


+ (NSString *)fuelUnitString:(KSVolume)unit
{
    if (unit == KSVolumeLiter)
        return @"l";
    else
        return @"gal";
}


+ (NSString *)fuelUnitDescription:(KSVolume)unit discernGallons:(BOOL)discernGallons pluralization:(BOOL)plural
{
    if (plural) {

        switch (unit) {
            case KSVolumeLiter: return NSLocalizedString(@"Liters", @"");
            case KSVolumeGalUS: return (discernGallons) ? NSLocalizedString(@"Gallons (US)", @"") : NSLocalizedString(@"Gallons", @"");
            default: return (discernGallons) ? NSLocalizedString(@"Gallons (UK)", @"") : NSLocalizedString(@"Gallons", @"");
        }

    } else {

        switch (unit) {
            case KSVolumeLiter: return NSLocalizedString(@"Liter", @"");
            case KSVolumeGalUS: return (discernGallons) ? NSLocalizedString(@"Gallon (US)", @"") : NSLocalizedString(@"Gallon", @"");
            default: return (discernGallons) ? NSLocalizedString(@"Gallon (UK)", @"") : NSLocalizedString(@"Gallon", @"");
        }
    }
}


+ (NSString *)fuelPriceUnitDescription:(KSVolume)unit
{
    if (KSVolumeIsMetric(unit))
        return NSLocalizedString(@"Price per Liter", @"");
    else
        return NSLocalizedString(@"Price per Gallon", @"");
}


+ (NSString *)odometerUnitString:(KSDistance)unit
{
    if (KSDistanceIsMetric(unit))
        return @"km";
    else
        return @"mi";
}


+ (NSString *)odometerUnitDescription:(KSDistance)unit pluralization:(BOOL)plural
{
    if (plural)
        return (KSDistanceIsMetric(unit)) ? NSLocalizedString(@"Kilometers", @"") : NSLocalizedString(@"Miles", @"");
    else
        return (KSDistanceIsMetric(unit)) ? NSLocalizedString(@"Kilometer", @"")  : NSLocalizedString(@"Mile", @"");
}

@end
