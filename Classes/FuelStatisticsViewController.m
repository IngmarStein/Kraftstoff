// FuelStatisticsViewController.m
//
// Kraftstoff


#import "AppDelegate.h"
#import "FuelEventController.h"
#import "FuelStatisticsViewControllerPrivateMethods.h"

#import "NSDate+Kraftstoff.h"


// Coordinates for the content area
CGFloat const StatisticsViewWidth  = 480.0;
CGFloat const StatisticsViewHeight = 268.0;
CGFloat const StatisticsHeight     = 182.0;



#pragma mark -
#pragma mark Base Statistics View Controller



@implementation FuelStatisticsViewController

@synthesize activityView;
@synthesize leftLabel;
@synthesize rightLabel;
@synthesize centerLabel;
@synthesize scrollView;
@synthesize selectedCar;



#pragma mark -
#pragma mark View Lifecycle



- (id)initWithNibName: (NSString*)nibNameOrNil bundle: (NSBundle*)nibBundleOrNil
{
    if ((self = [super initWithNibName: nibNameOrNil bundle: nibBundleOrNil]))
    {
        contentCache            = [[NSMutableDictionary alloc] init];
        displayedNumberOfMonths = 0;
        invalidationCounter     = 0;
        expectedCounter         = 0;
    }

    return self;
}


- (void)viewWillAppear: (BOOL)animated
{
    [super viewWillAppear: animated];

    leftLabel.text  = [NSString stringWithFormat: @"%@", [selectedCar valueForKey: @"name"]];
    rightLabel.text = @"";

    [self setDisplayedNumberOfMonths: [[NSUserDefaults standardUserDefaults] integerForKey: @"statisticTimeSpan"]];
}



#pragma mark -
#pragma mark View Rotation



- (BOOL)shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation)interfaceOrientation
{
    return UIInterfaceOrientationIsLandscape (interfaceOrientation);
}


- (BOOL)shouldAutorotate
{
    return YES;
}


- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}


- (void)noteStatisticsPageBecomesVisible: (BOOL)visible
{
}



#pragma mark -
#pragma mark Cache Handling



- (void)invalidateCaches
{
    [contentCache removeAllObjects];
    invalidationCounter += 1;
}


- (void)purgeDiscardableCacheContent
{
    [contentCache enumerateKeysAndObjectsUsingBlock: ^(id key, id<DiscardableDataObject> data, BOOL *stop)
        {
            if ([key integerValue] != displayedNumberOfMonths)
                [data discardContent];
        }];
}



#pragma mark -
#pragma mark Statistics Computation and Display



- (void)displayStatisticsForRecentMonths: (NSInteger)numberOfMonths
{
    displayedNumberOfMonths = numberOfMonths;
    expectedCounter         = invalidationCounter;


    // First try to display cached data
    if ([self displayCachedStatisticsForRecentMonths: numberOfMonths])
        return;


    // Compute and draw new contents
    NSManagedObjectID *selectedCarID = [self.selectedCar objectID];

    if (!selectedCarID)
        return;

#   if 1
    NSManagedObjectContext *parentContext = [self.selectedCar managedObjectContext];
    NSManagedObjectContext *sampleContext = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSPrivateQueueConcurrencyType];
    [sampleContext setParentContext: parentContext];
    [sampleContext performBlock: ^{

        // Get the selected car
        NSError *error = nil;
        NSManagedObject *sampleCar = [sampleContext existingObjectWithID: selectedCarID
                                                                   error: &error];

        if (sampleCar)
        {
            // Fetch events for the selected time period
            NSFetchRequest *fetchRequest = [AppDelegate fetchRequestForEventsForCar: sampleCar
                                                                          afterDate: [NSDate dateWithOffsetInMonths: -numberOfMonths fromDate: [NSDate date]]
                                                                        dateMatches: YES
                                                             inManagedObjectContext: sampleContext];

            NSArray *samplingObjects = [AppDelegate objectsForFetchRequest: fetchRequest
                                                    inManagedObjectContext: sampleContext];


            // Compute statistics
            id sampleData = [self computeStatisticsForRecentMonths: numberOfMonths
                                                            forCar: sampleCar
                                                       withObjects: samplingObjects];


            // Schedule update of cache and display in main thread
            dispatch_async (dispatch_get_main_queue (),
                           ^{
                               if (invalidationCounter == expectedCounter)
                               {
                                   [contentCache setObject: sampleData forKey: @(numberOfMonths)];

                                   if (displayedNumberOfMonths == numberOfMonths)
                                       [self displayCachedStatisticsForRecentMonths: numberOfMonths];
                               }
                           });
        }
    }];
#else
    dispatch_async (dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                    ^{
                        @autoreleasepool
                        {
                            NSManagedObjectContext *sampleContext = [[NSManagedObjectContext alloc] init];
                            [sampleContext setPersistentStoreCoordinator: [[AppDelegate sharedDelegate] persistentStoreCoordinator]];

                            // Get the selected car
                            NSError *error = nil;
                            NSManagedObject *sampleCar = [sampleContext existingObjectWithID: selectedCarID
                                                                                       error: &error];
                            
                            if (sampleCar)
                            {
                                // Fetch events for the selected time period
                                NSFetchRequest *fetchRequest = [AppDelegate fetchRequestForEventsForCar: sampleCar
                                                                                              afterDate: [NSDate dateWithOffsetInMonths: -numberOfMonths fromDate: [NSDate date]]
                                                                                            dateMatches: YES
                                                                                 inManagedObjectContext: sampleContext];
                                
                                NSArray *samplingObjects = [AppDelegate objectsForFetchRequest: fetchRequest
                                                                        inManagedObjectContext: sampleContext];
                                
                                
                                // Compute statistics
                                id sampleData = [self computeStatisticsForRecentMonths: numberOfMonths
                                                                                forCar: sampleCar
                                                                           withObjects: samplingObjects];
                                
                                
                                // Schedule update of cache and display in main thread
                                dispatch_async (dispatch_get_main_queue (),
                                               ^{
                                                   if (invalidationCounter == expectedCounter)
                                                   {
                                                       [contentCache setObject: sampleData forKey: @(numberOfMonths)];
                                                       
                                                       if (displayedNumberOfMonths == numberOfMonths)
                                                           [self displayCachedStatisticsForRecentMonths: numberOfMonths];
                                                   }
                                               });
                            }
                        }
                    });
#endif
}



#pragma mark -
#pragma mark Button Handling



- (IBAction)buttonAction: (UIButton*)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName: @"numberOfMonthsSelected"
                                                        object: self
                                                      userInfo: @{@"span": @([sender tag])}];
}


- (void)setDisplayedNumberOfMonths: (NSInteger)numberOfMonths
{
    // Update selection status of all buttons
    for (UIButton *button in [self.view subviews])
        if ([button isKindOfClass: [UIButton class]])
            [button setSelected: [button tag] == numberOfMonths];

    // Switch dataset to be shown
    [self displayStatisticsForRecentMonths: numberOfMonths];

}



#pragma mark -
#pragma mark Memory Management



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    [self purgeDiscardableCacheContent];
}

@end
