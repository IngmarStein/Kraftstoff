// AppDelegate.m
//
// Kraftstoffrechner


#import "AppDelegate.h"
#import "CarViewController.h"
#import "FuelCalculatorController.h"
#import "CSVParser.h"
#import "CSVImporter.h"
#import "kraftstoff-Swift.h"

@interface AppDelegate ()

@property (nonatomic, strong) UIAlertController *importAlert;

@end


@implementation AppDelegate

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
        
        [self.window makeKeyAndVisible];

        // Switch once to the car view for new users
        if (launchOptions[UIApplicationLaunchOptionsURLKey] == nil) {

            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

            if ([defaults boolForKey:@"firstStartup"]) {

				if ([[defaults stringForKey:@"preferredCarID"] isEqualToString:@""]) {
					UITabBarController *tabBarController = (UITabBarController *)self.window.rootViewController;
                    tabBarController.selectedIndex = 1;
				}

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
    if (self.importAlert == nil) {

		self.importAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Importing", @"")
															   message:@""
													preferredStyle:UIAlertControllerStyleAlert];

        UIActivityIndicatorView *progress = [[UIActivityIndicatorView alloc] initWithFrame:self.importAlert.view.bounds];
		progress.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		progress.userInteractionEnabled = NO;
        [progress setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [progress startAnimating];

        [self.importAlert.view addSubview:progress];

		[self.window.rootViewController presentViewController:self.importAlert animated:YES completion:NULL];
    }
}


- (void)hideImportAlert
{
	[self.window.rootViewController dismissViewControllerAnimated:YES completion:NULL];
	self.importAlert = nil;
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
    if (self.importAlert) {
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

								UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
																										 message:message
																								  preferredStyle:UIAlertControllerStyleAlert];
								UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
																						style:UIAlertActionStyleDefault
																					  handler:^(UIAlertAction * action) {}];
								[alertController addAction:defaultAction];
								[self.window.rootViewController presentViewController:alertController animated:YES completion:NULL];
                            });

        } else {

            dispatch_async (dispatch_get_main_queue(),
                            ^{
                                [self hideImportAlert];

								UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Import Failed", @"")
																										 message:NSLocalizedString(@"Can't detect file encoding. Please try to convert your CSV-file to UTF8 encoding.", @"")
																								  preferredStyle:UIAlertControllerStyleAlert];
								UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
																						style:UIAlertActionStyleDefault
																					  handler:^(UIAlertAction * action) {}];
								[alertController addAction:defaultAction];
								[self.window.rootViewController presentViewController:alertController animated:YES completion:NULL];
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


#pragma mark -
#pragma mark Core Data Support


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

			UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Can't Open Database", @"")
																					 message:NSLocalizedString(@"Sorry, the application database cannot be opened. Please quit the application with the Home button.", @"")
																			  preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
																	style:UIAlertActionStyleDefault
																  handler:^(UIAlertAction * action) {
																	  [NSException raise:NSGenericException format:@"%@", [error localizedDescription]];
																	  abort();
																  }];
			[alertController addAction:defaultAction];
			[self.window.rootViewController presentViewController:alertController animated:YES completion:NULL];
        }
    }

    return _persistentStoreCoordinator;
}


- (BOOL)saveContext:(NSManagedObjectContext *)context
{
    if (context != nil && [context hasChanges]) {

        NSError *error = nil;

        if (![context save:&error]) {

			UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Can't Save Database", @"")
																					 message:NSLocalizedString(@"Sorry, the application database cannot be saved. Please quit the application with the Home button.", @"")
																			  preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
																	style:UIAlertActionStyleDefault
																  handler:^(UIAlertAction * action) {
																	  [NSException raise:NSGenericException format:@"%@", [error localizedDescription]];
																	  abort();
																  }];
			[alertController addAction:defaultAction];
			[self.window.rootViewController presentViewController:alertController animated:YES completion:NULL];
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

    NSDecimalNumber *liters        = [Units litersForVolume:fuelVolume withUnit:fuelUnit];
    NSDecimalNumber *kilometers    = [Units kilometersForDistance:distance withUnit:odometerUnit];
    NSDecimalNumber *pricePerLiter = [Units pricePerLiter:price withUnit:fuelUnit];

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

@end
