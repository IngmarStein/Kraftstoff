// FuelStatisticsViewController.m
//
// Kraftstoff


#import "AppDelegate.h"
#import "FuelEventController.h"
#import "FuelStatisticsViewControllerPrivateMethods.h"

#import "NSDate+Kraftstoff.h"


// Coordinates for the content area
CGFloat StatisticsViewWidth  = 480.0;
CGFloat StatisticsViewHeight = 268.0;
CGFloat StatisticsHeight     = 182.0;



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
#pragma mark iPhone 5 ans iOS7 Support



+ (void)initialize
{
    if ([AppDelegate isLongPhone])
        StatisticsViewWidth = 568.0;

    if ([AppDelegate systemMajorVersion] >= 7)
    {
        StatisticsViewHeight = 300.0;
        StatisticsHeight     = 214.0;
    }
}



#pragma mark -
#pragma mark View Lifecycle



- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        contentCache            = [[NSMutableDictionary alloc] init];
        displayedNumberOfMonths = 0;
        invalidationCounter     = 0;
        expectedCounter         = 0;
    }

    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    if ([AppDelegate systemMajorVersion] >= 7)
    {
        UIFont *titleFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:17];
        UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Light" size:14];
        UIFont *fontSelected = [UIFont fontWithName:@"HelveticaNeue-Bold" size:14];

        // Labels on top of view
        self.leftLabel.font          = titleFont;
        self.centerLabel.font        = titleFont;
        self.rightLabel.font         = titleFont;
        self.leftLabel.shadowColor   = nil;
        self.centerLabel.shadowColor = nil;
        self.rightLabel.shadowColor  = nil;

        // Update selection status of all buttons
        for (UIButton *button in [self.view subviews])
            if ([button isKindOfClass:[UIButton class]])
            {
                NSAttributedString *label = [[NSAttributedString alloc]
                                             initWithString:button.titleLabel.text
                                             attributes:@{NSFontAttributeName:font,
                                                          NSForegroundColorAttributeName:[UIColor colorWithWhite:0.78 alpha:1.0]}];

                NSAttributedString *labelSelected = [[NSAttributedString alloc]
                                                     initWithString:button.titleLabel.text
                                                     attributes:@{NSFontAttributeName:fontSelected,
                                                                  NSForegroundColorAttributeName:[UIColor whiteColor]}];

                [button setAttributedTitle:label forState:UIControlStateNormal];
                [button setAttributedTitle:label forState:UIControlStateHighlighted];
                [button setAttributedTitle:labelSelected forState:UIControlStateSelected];

                [button setBackgroundImage:nil forState:UIControlStateNormal];
                [button setBackgroundImage:nil forState:UIControlStateHighlighted];
                [button setBackgroundImage:nil forState:UIControlStateSelected];

                [button setShowsTouchWhenHighlighted:NO];

                button.titleLabel.shadowColor = nil;
            }
    }
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    leftLabel.text  = [NSString stringWithFormat:@"%@", [selectedCar valueForKey:@"name"]];
    rightLabel.text = @"";

    [self setDisplayedNumberOfMonths:[[NSUserDefaults standardUserDefaults] integerForKey:@"statisticTimeSpan"]];
}



#pragma mark -
#pragma mark View Rotation



- (BOOL)shouldAutorotate
{
    return YES;
}


- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}


- (void)noteStatisticsPageBecomesVisible:(BOOL)visible
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



- (void)displayStatisticsForRecentMonths:(NSInteger)numberOfMonths
{
    displayedNumberOfMonths = numberOfMonths;
    expectedCounter         = invalidationCounter;


    // First try to display cached data
    if ([self displayCachedStatisticsForRecentMonths:numberOfMonths])
        return;


    // Compute and draw new contents
    NSManagedObjectID *selectedCarID = [self.selectedCar objectID];

    if (!selectedCarID)
        return;

    NSManagedObjectContext *parentContext = [self.selectedCar managedObjectContext];
    NSManagedObjectContext *sampleContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [sampleContext setParentContext:parentContext];
    [sampleContext performBlock: ^{

        // Get the selected car
        NSError *error = nil;
        NSManagedObject *sampleCar = [sampleContext existingObjectWithID:selectedCarID
                                                                   error:&error];

        if (sampleCar)
        {
            // Fetch some young events to get the most recent fillup date
            NSArray *recentEvents = [AppDelegate objectsForFetchRequest:[AppDelegate fetchRequestForEventsForCar:sampleCar
                                                                                                      beforeDate:[NSDate date]
                                                                                                     dateMatches:YES
                                                                                          inManagedObjectContext:sampleContext]
                                                 inManagedObjectContext:sampleContext];

            NSDate *recentFillupDate = nil;

            @try {
                if ([recentEvents count])
                    recentFillupDate = [[recentEvents objectAtIndex:0] valueForKey:@"timestamp"];
                else
                    recentFillupDate = [NSDate date];
            }
            @catch (NSException *exception) {
                recentFillupDate = [NSDate date];
            }

            // Fetch events for the selected time period
            NSDate *samplingStart = [NSDate dateWithOffsetInMonths: -numberOfMonths fromDate:recentFillupDate];
            NSArray *samplingObjects = [AppDelegate objectsForFetchRequest:[AppDelegate fetchRequestForEventsForCar:sampleCar
                                                                                                          afterDate:samplingStart
                                                                                                        dateMatches:YES
                                                                                             inManagedObjectContext:sampleContext]
                                                    inManagedObjectContext:sampleContext];

            // Compute statistics
            id sampleData = [self computeStatisticsForRecentMonths:numberOfMonths forCar:sampleCar withObjects:samplingObjects];

            // Schedule update of cache and display in main thread
            dispatch_async (dispatch_get_main_queue(),
                           ^{
                               if (invalidationCounter == expectedCounter)
                               {
                                   contentCache[@(numberOfMonths)] = sampleData;

                                   if (displayedNumberOfMonths == numberOfMonths)
                                       [self displayCachedStatisticsForRecentMonths:numberOfMonths];
                               }
                           });
        }
    }];
}



#pragma mark -
#pragma mark Button Handling



- (IBAction)buttonAction:(UIButton *)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"numberOfMonthsSelected"
                                                        object:self
                                                      userInfo:@{@"span":@([sender tag])}];
}


- (void)setDisplayedNumberOfMonths:(NSInteger)numberOfMonths
{
    // Update selection status of all buttons
    for (UIButton *button in [self.view subviews])
        if ([button isKindOfClass:[UIButton class]])
            [button setSelected:[button tag] == numberOfMonths];

    // Switch dataset to be shown
    [self displayStatisticsForRecentMonths:numberOfMonths];

}



#pragma mark -
#pragma mark Memory Management



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    [self purgeDiscardableCacheContent];
}

@end
