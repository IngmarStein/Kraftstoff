// FuelStatisticsViewController.m
//
// Kraftstoff


#import "AppDelegate.h"
#import "FuelEventController.h"
#import "FuelStatisticsViewController.h"
#import "FuelStatisticsViewControllerPrivateMethods.h"


// Coordinates for the content area
CGFloat const StatisticsViewHeight     = 268.0;

CGFloat const StatisticsLeftBorder     =  10.0;
CGFloat const StatisticsRightBorder    = 430.0;
CGFloat const StatisticsTopBorder      =  58.0;
CGFloat const StatisticsBottomBorder   = 240.0;
CGFloat const StatisticsWidth          = 420.0;
CGFloat const StatisticsHeight         = 182.0;



#pragma mark -
#pragma mark Base Statistics View Controller



@implementation FuelStatisticsViewController

@synthesize selectedCar;
@synthesize active;
@synthesize activityView;
@synthesize leftLabel;
@synthesize rightLabel;
@synthesize centerLabel;
@synthesize scrollView;


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

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector (timeSpanSelected:)
                                                     name: @"timeSpanChanged"
                                                   object: nil];
    }

    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    leftLabel.text  = [NSString stringWithFormat: @"%@", [selectedCar valueForKey: @"name"]];
    rightLabel.text = @"";
}


- (void)viewWillAppear: (BOOL)animated
{
    [super viewWillAppear: animated];
    [self switchToSelectedTimeSpan: [[NSUserDefaults standardUserDefaults] integerForKey: @"statisticTimeSpan"]];
}


- (BOOL)shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation)interfaceOrientation
{
    return UIInterfaceOrientationIsLandscape (interfaceOrientation);
}



#pragma mark -
#pragma mark Cache Handling on Changes to Core Data or the User Locale



- (void)invalidateCaches
{
    [contentCache removeAllObjects];
    invalidationCounter += 1;
}


- (void)purgeDiscardableCacheContent
{
    // to be implemented by subclasses
}



#pragma mark -
#pragma mark Content Creation



- (NSArray*)fetchObjectsForRecentMonths: (NSInteger)numberOfMonths
                                 forCar: (NSManagedObject*)car
                              inContext: (NSManagedObjectContext*)managedObjectContext
{
    return [AppDelegate objectsForFetchRequest:
                [AppDelegate fetchRequestForEventsForCar: car
                                               afterDate: [AppDelegate dateWithOffsetInMonths: -numberOfMonths fromDate: [NSDate date]]
                                             dateMatches: YES
                                  inManagedObjectContext: managedObjectContext]
                        inManagedObjectContext: managedObjectContext];
}


- (void)displayStatisticsForRecentMonths: (NSInteger)numberOfMonths
{
    // Skip when the selected car no longer exists...
    if ([self.selectedCar isFault])
        return;

    displayedNumberOfMonths = numberOfMonths;

    // Try to display cached data
    if ([self displayCachedStatisticsForRecentMonths: numberOfMonths])
        return;

    // Compute and draw real contents
    expectedCounter = invalidationCounter;
    NSManagedObjectID *selectedCarID = [self.selectedCar objectID];

    dispatch_async (dispatch_get_global_queue (active ? DISPATCH_QUEUE_PRIORITY_DEFAULT : DISPATCH_QUEUE_PRIORITY_LOW, 0),
    ^{
        @autoreleasepool
        {
            NSManagedObjectContext *localObjectContext = [[NSManagedObjectContext alloc] init];
            [localObjectContext setPersistentStoreCoordinator: [[AppDelegate sharedDelegate] persistentStoreCoordinator]];

            NSError *error = nil;
            NSManagedObject *localSelectedCar = [localObjectContext existingObjectWithID: selectedCarID error: &error];

            [self computeAndRedisplayStatisticsForRecentMonths: numberOfMonths
                                                        forCar: localSelectedCar
                                                     inContext: localObjectContext];
        }
    });
}


- (BOOL)displayCachedStatisticsForRecentMonths: (NSInteger)numberOfMonths
{
    // to be implemented by subclasses
    return NO;
}


- (void)computeAndRedisplayStatisticsForRecentMonths: (NSInteger)numberOfMonths
                                              forCar: (NSManagedObject*)car
                                           inContext: (NSManagedObjectContext*)context
{
    // to be implemented by subclasses
}



#pragma mark -
#pragma mark Radio Button Handling



- (IBAction)checkboxButton: (UIButton*)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName: @"timeSpanChanged"
                                                        object: self
                                                      userInfo: [NSDictionary dictionaryWithObject: [NSNumber numberWithInteger: [sender tag]]
                                                                                            forKey: @"span"]];
}


- (void)switchToSelectedTimeSpan: (NSInteger)timeSpan
{
    // Update selection status of all buttons
    for (UIButton *button in [self.view subviews])
        if ([button isKindOfClass: [UIButton class]])
            [button setSelected: [button tag] == timeSpan];

    // Switch dataset to be shown
    [self displayStatisticsForRecentMonths: timeSpan];

}


- (void)timeSpanSelected: (NSNotification*)notification
{
    // Selected timespan in months
    NSInteger timeSpan = [[[notification userInfo] valueForKey: @"span"] integerValue];

    [[NSUserDefaults standardUserDefaults] setInteger: timeSpan forKey: @"statisticTimeSpan"];
    [self switchToSelectedTimeSpan: timeSpan];
}



#pragma mark -
#pragma mark Memory Management



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    [self purgeDiscardableCacheContent];
}


- (void)viewDidUnload
{
    self.activityView   = nil;
    self.leftLabel      = nil;
    self.rightLabel     = nil;

    [super viewDidUnload];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

@end
