// FuelStatisticsViewController.m
//
// Kraftstoff


#import "AppDelegate.h"
#import "FuelEventController.h"
#import "FuelStatisticsViewController.h"


// Coordinates for the graph area
static CGFloat const StatisticsViewHeight   = 268.0;

static CGFloat const StatisticsLeftBorder   =  10.0;
static CGFloat const StatisticsRightBorder  = 430.0;
static CGFloat const StatisticsTopBorder    =  58.0;
static CGFloat const StatisticsBottomBorder = 240.0;
static CGFloat const StatisticsWidth        = 420.0;
static CGFloat const StatisticsHeight       = 182.0;



#pragma mark -
#pragma mark Sampling State / Discardable Cache Objects



@implementation FuelStatisticsSamplingData

@synthesize contentImage;
@synthesize contentAverage;


- (id)init
{
    if ((self = [super init]))
    {
        int i;

        dataCount  = 0;
        hMarkCount = 0;
        vMarkCount = 0;

        for (i = 0; i < 5; i++)
            hMarkNames [i] = nil;

        for (i = 0; i < 3; i++)
            vMarkNames [i] = nil;
    }

    return self;
}

@end



#pragma mark -
#pragma mark Private View Controller API



@interface FuelStatisticsViewController (private)

// Provided by subclasses for statistics
- (CGGradientRef)curveGradient;

- (NSNumberFormatter*)averageFormatter;
- (NSString*)averageFormatString;
- (NSString*)noAverageString;

- (NSNumberFormatter*)axisFormatterForCar: (NSManagedObject*)car;
- (CGFloat)valueForManagedObject: (NSManagedObject*)managedObject forCar: (NSManagedObject*)car;

// Computations done in dispatched block
- (NSArray*)fetchObjectsForRecentMonths: (NSInteger)numberOfMonths
                                 forCar: (NSManagedObject*)car
                              inContext: (NSManagedObjectContext*)context;

- (CGFloat)resampleFetchedObjects: (NSArray*)fetchedObjects
                           forCar: (NSManagedObject*)car
                         andState: (FuelStatisticsSamplingData*)state;

- (void)drawStatisticsForState: (FuelStatisticsSamplingData*)state;

- (void)displayStatisticsForRecentMonths: (NSInteger)numberOfMonths;
- (void)switchToSelectedTimeSpan: (NSInteger)timeSpan;

// Backgroundhandler
- (void)didEnterBackground: (NSNotification*)notification;

@end



#pragma mark -
#pragma mark Base Statistics View Controller



@implementation FuelStatisticsViewController

@synthesize selectedCar;
@synthesize active;
@synthesize activityView;
@synthesize leftLabel;
@synthesize rightLabel;



#pragma mark -
#pragma mark View Lifecycle



- (id)initWithNibName: (NSString*)nibNameOrNil bundle: (NSBundle*)nibBundleOrNil
{
    if ((self = [super initWithNibName: nibNameOrNil bundle: nibBundleOrNil]))
    {
        contentCache            = [[NSMutableDictionary alloc] init];
        displayedNumberOfMonths = 0;
        invalidationCounter     = 0;

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector (timeSpanSelected:)
                                                     name: @"timeSpanChanged"
                                                   object: nil];

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector (didEnterBackground:)
                                                     name: UIApplicationDidEnterBackgroundNotification
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
    [contentCache enumerateKeysAndObjectsUsingBlock:
        ^(id key, id data, BOOL *stop)
        {
            [(FuelStatisticsSamplingData*)data setContentImage: nil];
        }];
}


#pragma mark -
#pragma mark Graph Computation



- (NSArray*)fetchObjectsForRecentMonths: (NSInteger)numberOfMonths
                                 forCar: (NSManagedObject*)car
                              inContext: (NSManagedObjectContext*)managedObjectContext
{
    return [AppDelegate objectsForFetchRequest: [AppDelegate fetchRequestForEventsForCar: car
                                                                               afterDate: [AppDelegate dateWithOffsetInMonths: -numberOfMonths
                                                                                                                     fromDate: [NSDate date]]
                                                                             dateMatches: YES
                                                                  inManagedObjectContext: managedObjectContext]
                        inManagedObjectContext: managedObjectContext];
}


- (CGFloat)resampleFetchedObjects: (NSArray*)fetchedObjects
                           forCar: (NSManagedObject*)car
                         andState: (FuelStatisticsSamplingData*)state;
{
    // Compute vertical range of curve
    NSInteger valCount      =  0;
    NSInteger valFirstIndex = -1;
    NSInteger valLastIndex  = -1;

    CGFloat valAverage = 0.0;

    CGFloat valMin =  INFINITY;
    CGFloat valMax = -INFINITY;
    CGFloat valRange;

    for (NSInteger i = [fetchedObjects count] - 1; i >= 0; i--)
    {
        NSManagedObject *object = [fetchedObjects objectAtIndex: i];

        CGFloat value = [self valueForManagedObject: object forCar: car];

        if (!isnan (value))
        {
            valCount   += 1;
            valAverage += value;

            if (valMin > value)
                valMin = value;

            if (valMax < value)
                valMax = value;

            if (valLastIndex < 0)
                valLastIndex  = i;
            else
                valFirstIndex = i;
        }
    }

    // Not enough data
    if (valCount < 2)
    {
        state->dataCount  = 0;
        state->hMarkCount = 0;
        state->vMarkCount = 0;

        return valCount == 0 ? NAN : valAverage;
    }

    valAverage /= valCount;

    valMin   = floor (valMin * 2.0) / 2.0;
    valMax   = ceil  (valMax * 2.0) / 2.0;
    valRange = valMax - valMin;

    if (valRange > 40)
    {
        valMin   = floor (valMin / 10.0) * 10.0;
        valMax   = ceil  (valMax / 10.0) * 10.0;
    }
    else if (valRange > 8)
    {
        valMin   = floor (valMin / 2.0) * 2.0;
        valMax   = ceil  (valMax / 2.0) * 2.0;
    }
    else if (valRange > 4)
    {
        valMin   = floor (valMin);
        valMax   = ceil  (valMax);
    }
    else if (valRange < 0.25)
    {
        valMin   = floor (valMin * 4.0 - 0.001) / 4.0;
        valMax   = ceilf (valMax * 4.0 + 0.001) / 4.0;
    }

    valRange = valMax - valMin;

    // Resampling of fetched data
    CGFloat   samples      [MAX_SAMPLES];
    NSInteger samplesCount [MAX_SAMPLES];

    for (NSInteger i = 0; i < MAX_SAMPLES; i++)
    {
        samples      [i] = 0.0;
        samplesCount [i] = 0;
    }

    NSDate *mostRecentDate = [[fetchedObjects objectAtIndex: valFirstIndex] valueForKey: @"timestamp"];
    NSDate *sampleDate     = [[fetchedObjects objectAtIndex: valLastIndex]  valueForKey: @"timestamp"];

    NSTimeInterval rangeInterval = [mostRecentDate timeIntervalSinceDate: sampleDate];

    for (NSInteger i = valLastIndex; i >= valFirstIndex; i--)
    {
        NSManagedObject *managedObject = [fetchedObjects objectAtIndex: i];
        CGFloat value = [self valueForManagedObject: managedObject forCar: car];

        if (!isnan (value))
        {
            NSTimeInterval sampleInterval = [mostRecentDate timeIntervalSinceDate: [managedObject valueForKey: @"timestamp"]];
            NSInteger sampleIndex = (NSInteger)rint ((MAX_SAMPLES-1) * (1.0 - sampleInterval/rangeInterval));

            if (valRange < 0.0001)
                samples [sampleIndex] += 0.5;
            else
                samples [sampleIndex] += (value - valMin) / valRange;

            samplesCount [sampleIndex] += 1;
        }
    }


    // Build curve data from resampled values
    state->dataCount = 0;

    for (NSInteger i = 0; i < MAX_SAMPLES; i++)
        if (samplesCount [i])
            state->data [state->dataCount++] = CGPointMake ((CGFloat)i / (MAX_SAMPLES-1), 1.0 - samples [i] / samplesCount [i]);


    // Markers for vertical axis
    NSNumberFormatter *numberFormatter = [self axisFormatterForCar: car];

    state->hMarkPositions [0] = 0.0;
    state->hMarkNames     [0] = [numberFormatter stringFromNumber: [NSNumber numberWithFloat: valMin + valRange]];
    state->hMarkPositions [1] = 0.25;
    state->hMarkNames     [1] = [numberFormatter stringFromNumber: [NSNumber numberWithFloat: valMin + valRange*0.75]];
    state->hMarkPositions [2] = 0.5;
    state->hMarkNames     [2] = [numberFormatter stringFromNumber: [NSNumber numberWithFloat: valMin + valRange*0.5]];
    state->hMarkPositions [3] = 0.75;
    state->hMarkNames     [3] = [numberFormatter stringFromNumber: [NSNumber numberWithFloat: valMin + valRange*0.25]];
    state->hMarkPositions [4] = 1.0;
    state->hMarkNames     [4] = [numberFormatter stringFromNumber: [NSNumber numberWithFloat: valMin]];
    state->hMarkCount = 5;


    // Markers for horizontal axis
    NSDate *midDate = [NSDate dateWithTimeInterval: [mostRecentDate timeIntervalSinceDate: sampleDate]/2.0
                                         sinceDate: sampleDate];

    NSDateFormatter *dateFormatter = [AppDelegate sharedDateFormatter];

    state->vMarkPositions [0] = 0.0;
    state->vMarkNames     [0] = [dateFormatter stringForObjectValue: sampleDate];
    state->vMarkPositions [1] = 0.5;
    state->vMarkNames     [1] = [dateFormatter stringForObjectValue: midDate];
    state->vMarkPositions [2] = 1.0;
    state->vMarkNames     [2] = [dateFormatter stringForObjectValue: mostRecentDate];
    state->vMarkCount = 3;

    return valAverage;
}


- (void)drawStatisticsForState: (FuelStatisticsSamplingData*)state
{
    CGContextRef cgContext = UIGraphicsGetCurrentContext ();


    // Background shade with rounded corners
    [[UIColor blackColor] setFill];
    CGContextFillRect (cgContext, self.view.bounds);

    [[UIBezierPath bezierPathWithRoundedRect: CGRectMake (1.0, 0.0, self.view.bounds.size.width - 2.0, self.view.bounds.size.height)
                           byRoundingCorners: UIRectCornerAllCorners
                                 cornerRadii: CGSizeMake (12.0, 12.0)] addClip];

    CGContextDrawLinearGradient (cgContext,
                                 [AppDelegate backGradient],
                                 CGPointMake (0.0, StatisticsViewHeight + StatusBarHeight),
                                 CGPointMake (0.0, 0.0),
                                 kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);


    // Contents if there is a valid state
    if (state == nil)
        return;

    UIFont *font       = [UIFont boldSystemFontOfSize: 14];
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat x, y;

    if (state->dataCount == 0)
    {
        CGContextSaveGState (cgContext);
        {
            CGContextSetShadowWithColor (cgContext, CGSizeMake (0.0, -1.0), 0.0, [[UIColor blackColor] CGColor]);
            [[UIColor whiteColor] setFill];

            NSString *text = _I18N (@"Not enough data to display statistics");
            CGSize size    = [text sizeWithFont: font];

            x = floor ((480.0 -  size.width)/2.0);
            y = floor ((320.0 - (size.height - font.descender))/2.0 - 18.0);

            [text drawAtPoint: CGPointMake (x, y)   withFont: font];
        }
        CGContextRestoreGState (cgContext);
    }
    else
    {
        // Color for coordinate-axes
        [[UIColor colorWithWhite: 0.45 alpha: 1.0] setStroke];


        // Horizontal marker lines (clipped away below the curve)
        CGContextSaveGState (cgContext);
        {
            CGFloat   dashDotPattern [2]   = { 1.0, 1.0 };
            NSInteger dashDotPatternLength = 2;

            // Clipping
            [path removeAllPoints];
            [path moveToPoint: CGPointMake (StatisticsLeftBorder, StatisticsTopBorder)];

            for (NSInteger i = 0; i < state->dataCount; i++)
            {
                x = rint (StatisticsLeftBorder + StatisticsWidth  * state->data [i].x);
                y = rint (StatisticsTopBorder  + StatisticsHeight * state->data [i].y);

                [path addLineToPoint: CGPointMake (x, y)];
            }

            [path addLineToPoint: CGPointMake (StatisticsRightBorder, StatisticsTopBorder)];
            [path closePath];
            [path addClip];

            // Marker lines
            path.lineWidth = 1;
            [path setLineDash: dashDotPattern count: dashDotPatternLength phase: 0.0];

            [path removeAllPoints];
            [path moveToPoint:    CGPointMake (StatisticsLeftBorder,  0.5)];
            [path addLineToPoint: CGPointMake (StatisticsRightBorder, 0.5)];

            CGContextSaveGState (cgContext);
            {
                CGFloat lastY;

                for (NSInteger i = 0, y = 0.0; i < state->hMarkCount; i++)
                {
                    lastY = y;
                    y     = rint (StatisticsTopBorder + StatisticsHeight * state->hMarkPositions [i]);

                    CGContextTranslateCTM (cgContext, 0.0, y - lastY);
                    [path stroke];
                }
            }
            CGContextRestoreGState (cgContext);
        }
        CGContextRestoreGState (cgContext);


        // Axis decription for horizontal marker lines markers
        CGContextSaveGState (cgContext);
        {
            CGContextSetShadowWithColor (cgContext, CGSizeMake (0.0, -1.0), 0.0, [[UIColor blackColor] CGColor]);
            [[UIColor whiteColor] setFill];

            for (NSInteger i = 0; i < state->hMarkCount; i++)
                if (state->hMarkNames [i] != nil)
                {
                    CGSize size = [state->hMarkNames[i] sizeWithFont: font];

                    x = StatisticsRightBorder + 6;
                    y = floor (StatisticsTopBorder + 0.5 + StatisticsHeight * state->hMarkPositions [i] - size.height - font.descender) + 0.5;

                    [state->hMarkNames[i] drawAtPoint: CGPointMake (x, y)   withFont: font];
                }
        }
        CGContextRestoreGState (cgContext);


        // Vertical marker lines
        path.lineWidth = 2;
        [path setLineDash: NULL count: 0 phase: 0.0];

        [path removeAllPoints];
        [path moveToPoint:    CGPointMake (0, StatisticsTopBorder)];
        [path addLineToPoint: CGPointMake (0, StatisticsBottomBorder)];

        CGContextSaveGState (cgContext);
        {
            CGFloat lastX;

            for (NSInteger i = 0, x = 0.0; i < state->vMarkCount; i++)
            {
                lastX = x;
                x     = rint (StatisticsLeftBorder + StatisticsWidth * state->vMarkPositions [i]);

                CGContextTranslateCTM (cgContext, x - lastX, 0.0);
                [path stroke];
            }
        }
        CGContextRestoreGState (cgContext);


        // Axis description for vertical marker lines
        CGContextSaveGState (cgContext);
        {
            CGContextSetShadowWithColor (cgContext, CGSizeMake (0.0, -1.0), 0.0, [[UIColor blackColor] CGColor]);
            [[UIColor whiteColor] setFill];

            for (NSInteger i = 0; i < state->vMarkCount; i++)
                if (state->vMarkNames [i] != nil)
                {
                    CGSize size = [state->vMarkNames[i] sizeWithFont: font];

                    x = floor (StatisticsLeftBorder + 0.5 + StatisticsWidth * state->vMarkPositions [i] - size.width/2.0);
                    y = StatisticsBottomBorder + 5;

                    if (x < StatisticsLeftBorder)
                        x = StatisticsLeftBorder;

                    if (x > StatisticsRightBorder - size.width)
                        x = StatisticsRightBorder - size.width;

                    [state->vMarkNames[i] drawAtPoint: CGPointMake (x, y)   withFont: font];
                }
        }
        CGContextRestoreGState (cgContext);


        // Pattern fill below cure
        CGContextSaveGState (cgContext);
        {
            [path removeAllPoints];
            [path moveToPoint: CGPointMake (StatisticsLeftBorder + 1, StatisticsBottomBorder)];

            for (NSInteger i = 0; i < state->dataCount; i++)
            {
                x = rint (StatisticsLeftBorder + StatisticsWidth  * state->data [i].x);
                y = rint (StatisticsTopBorder  + StatisticsHeight * state->data [i].y);

                [path addLineToPoint: CGPointMake (x, y)];
            }

            [path addLineToPoint: CGPointMake (StatisticsRightBorder, StatisticsBottomBorder)];
            [path closePath];

            // Color gradient
            [path addClip];
            CGContextDrawLinearGradient (cgContext,
                                         [self curveGradient],
                                         CGPointMake (  0, StatisticsBottomBorder),
                                         CGPointMake (320, StatisticsTopBorder),
                                         kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);

            // Stripe pattern
            [path removeAllPoints];
            [path moveToPoint:    CGPointMake (StatisticsLeftBorder,  0)];
            [path addLineToPoint: CGPointMake (StatisticsRightBorder, 0)];

            CGContextSaveGState (cgContext);
            {
                CGContextTranslateCTM (cgContext, 0.0, StatisticsTopBorder-2);

                for (NSInteger i = 0; i < (NSInteger)StatisticsHeight; i += 4)
                {
                    CGContextTranslateCTM (cgContext, 0.0, 4.0);
                    [[UIColor colorWithWhite: 0.8 alpha: 0.28 - 0.20 * i/StatisticsHeight] setStroke];
                    [path stroke];
                }
            }
            CGContextRestoreGState (cgContext);
        }
        CGContextRestoreGState (cgContext);


        // Bottom line
        path.lineWidth = 2;
        [path removeAllPoints];
        [path moveToPoint:    CGPointMake (StatisticsLeftBorder  - 1, StatisticsBottomBorder)];
        [path addLineToPoint: CGPointMake (StatisticsRightBorder + 1, StatisticsBottomBorder)];
        [path stroke];

        // Left line
        [path removeAllPoints];
        [path moveToPoint:    CGPointMake (StatisticsLeftBorder, StatisticsTopBorder)];
        [path addLineToPoint: CGPointMake (StatisticsLeftBorder, StatisticsBottomBorder)];
        [path stroke];

        // Right line
        [path removeAllPoints];
        [path moveToPoint:    CGPointMake (StatisticsRightBorder, StatisticsTopBorder)];
        [path addLineToPoint: CGPointMake (StatisticsRightBorder, StatisticsBottomBorder)];
        [path stroke];


        // The curve
        path.lineWidth    = 4;
        path.lineCapStyle = kCGLineCapRound;
        [[UIColor whiteColor] setStroke];

        [path removeAllPoints];
        [path moveToPoint: CGPointMake (rint (StatisticsLeftBorder + StatisticsWidth  * state->data [0].x),
                                        rint (StatisticsTopBorder  + StatisticsHeight * state->data [0].y))];

        for (NSInteger i = 1; i < state->dataCount; i++)
        {
            x = rint (StatisticsLeftBorder + StatisticsWidth  * state->data [i].x);
            y = rint (StatisticsTopBorder  + StatisticsHeight * state->data [i].y);

            [path addLineToPoint: CGPointMake (x, y)];
        }

        [path stroke];
    }
}


- (void)displayStatisticsForRecentMonths: (NSInteger)numberOfMonths
{
    UIImageView *imageView = (UIImageView*)self.view;


    // Skip when the selected car no longer exists...
    if ([self.selectedCar isFault])
        return;

    displayedNumberOfMonths = numberOfMonths;


    // Cache lookup
    FuelStatisticsSamplingData *cell = [contentCache objectForKey: [NSNumber numberWithInteger: numberOfMonths]];
    NSNumber *averageValue = cell.contentAverage;
    UIImage  *cachedImage  = cell.contentImage;

    // Summary in top right of view
    if (averageValue != nil && !isnan ([averageValue floatValue]))
        rightLabel.text = [NSString stringWithFormat: [self averageFormatString], [[self averageFormatter] stringFromNumber: averageValue]];
    else
        rightLabel.text = [self noAverageString];

    // Image contents on Cache Hit
    if (cachedImage != nil && averageValue != nil)
    {
        [activityView stopAnimating];

        imageView.image = cachedImage;
        return;
    }


    // Cache Miss => draw prelimary contents
    [activityView startAnimating];

    UIGraphicsBeginImageContextWithOptions (CGSizeMake (480.0, StatisticsViewHeight), YES, 0.0);
    {
        [self drawStatisticsForState: nil];
        imageView.image = UIGraphicsGetImageFromCurrentImageContext ();
    }
    UIGraphicsEndImageContext ();


    // Compute and draw real contents
    NSInteger expectedCounter = invalidationCounter;
    NSManagedObjectID *selectedCarID = [self.selectedCar objectID];

    dispatch_async (dispatch_get_global_queue (active ? DISPATCH_QUEUE_PRIORITY_DEFAULT : DISPATCH_QUEUE_PRIORITY_LOW, 0),
    ^{
        @autoreleasepool
        {
            // Thread local managed object context
            NSManagedObjectContext *localObjectContext = [[NSManagedObjectContext alloc] init];
            [localObjectContext setPersistentStoreCoordinator: [[AppDelegate sharedDelegate] persistentStoreCoordinator]];

            NSError *error = nil;
            NSManagedObject *localSelectedCar = [localObjectContext existingObjectWithID: selectedCarID error: &error];

            if (localSelectedCar != nil)
            {
                FuelStatisticsSamplingData *state = cell;
                BOOL stateAllocated = NO;


                // No cache cell exists => resample data and compute average value
                if (state == nil)
                {
                    state = [[FuelStatisticsSamplingData alloc] init];

                    NSArray *fetchedObjects = [self fetchObjectsForRecentMonths: numberOfMonths
                                                                         forCar: localSelectedCar
                                                                      inContext: localObjectContext];

                    state.contentAverage = [NSNumber numberWithFloat:
                                                [self resampleFetchedObjects: fetchedObjects
                                                                      forCar: localSelectedCar
                                                                    andState: state]];

                    stateAllocated = YES;
                }


                // Create image data from resampled data
                if (state.contentImage == nil)
                {
                    UIGraphicsBeginImageContextWithOptions (CGSizeMake (480.0, StatisticsViewHeight), YES, 0.0);
                    {
                        [self drawStatisticsForState: state];
                        state.contentImage = UIGraphicsGetImageFromCurrentImageContext ();
                    }
                    UIGraphicsEndImageContext ();
                }


                // Schedule update of cache display in main thread
                dispatch_sync (dispatch_get_main_queue (),
                               ^{
                                   if (invalidationCounter == expectedCounter)
                                   {
                                       if (stateAllocated)
                                           [contentCache setObject: state forKey: [NSNumber numberWithInteger: numberOfMonths]];

                                       if (displayedNumberOfMonths == numberOfMonths)
                                           [self displayStatisticsForRecentMonths: numberOfMonths];
                                   }
                               });
            }
        }
    });
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



- (void)didEnterBackground: (NSNotification*)notification
{
    [self purgeDiscardableCacheContent];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    [self purgeDiscardableCacheContent];
}


- (void)viewDidUnload
{
    self.activityView = nil;
    self.leftLabel    = nil;
    self.rightLabel   = nil;

    [super viewDidUnload];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

@end



#pragma mark -
#pragma mark Average Consumption/Efficiency View Controller



@implementation FuelStatisticsViewController_AvgConsumption


- (CGGradientRef)curveGradient
{
    return [AppDelegate greenGradient];
}


- (NSNumberFormatter*)averageFormatter
{
    return [AppDelegate sharedFuelVolumeFormatter];
}


- (NSString*)averageFormatString
{
    KSFuelConsumption consumptionUnit = [[self.selectedCar valueForKey: @"fuelConsumptionUnit"] integerValue];

    return [NSString stringWithFormat: @"∅ %%@ %@", [AppDelegate consumptionUnitString: consumptionUnit]];
}


- (NSString*)noAverageString
{
    KSFuelConsumption consumptionUnit = [[self.selectedCar valueForKey: @"fuelConsumptionUnit"] integerValue];

    return [AppDelegate consumptionUnitString: consumptionUnit];
}


- (NSNumberFormatter*)axisFormatterForCar: (NSManagedObject*)car
{
    return [AppDelegate sharedFuelVolumeFormatter];
}


- (CGFloat)valueForManagedObject: (NSManagedObject*)managedObject forCar: (NSManagedObject*)car
{
    @try
    {
        if ([[managedObject valueForKey: @"filledUp"] boolValue] == NO)
            return NAN;

        NSInteger consumptionUnit   = [[car valueForKey: @"fuelConsumptionUnit"] integerValue];
        NSDecimalNumber *distance   = [[managedObject valueForKey: @"distance"]   decimalNumberByAdding: [managedObject valueForKey: @"inheritedDistance"]];
        NSDecimalNumber *fuelVolume = [[managedObject valueForKey: @"fuelVolume"] decimalNumberByAdding: [managedObject valueForKey: @"inheritedFuelVolume"]];

        return [[AppDelegate consumptionForDistance: distance
                                             Volume: fuelVolume
                                           withUnit: consumptionUnit] floatValue];
    }
    @catch (NSException *e)
    {
        return NAN;
    }
}

@end



#pragma mark -
#pragma mark Price History View Controller




@implementation FuelStatisticsViewController_PriceAmount


- (CGGradientRef)curveGradient
{
    return [AppDelegate orangeGradient];
}


- (NSNumberFormatter*)averageFormatter
{
    return [AppDelegate sharedCurrencyFormatter];
}


- (NSString*)averageFormatString
{
    NSInteger fuelUnit = [[self.selectedCar valueForKey: @"fuelUnit"] integerValue];

    return [NSString stringWithFormat: @"∅ %%@/%@", [AppDelegate fuelUnitString: fuelUnit]];
}


- (NSString*)noAverageString
{
    NSInteger fuelUnit = [[self.selectedCar valueForKey: @"fuelUnit"] integerValue];

    return [NSString stringWithFormat: @"%@/%@",
                [[AppDelegate sharedCurrencyFormatter] currencySymbol],
                [AppDelegate fuelUnitString: fuelUnit]];
}


- (NSNumberFormatter*)axisFormatterForCar: (NSManagedObject*)car
{
    return [AppDelegate sharedAxisCurrencyFormatter];
}


- (CGFloat)valueForManagedObject: (NSManagedObject*)managedObject forCar: (NSManagedObject*)car
{
    @try
    {
        NSDecimalNumber *price = [managedObject valueForKey: @"price"];

        if ([price compare: [NSDecimalNumber zero]] == NSOrderedSame)
            return NAN;

        return [[AppDelegate pricePerUnit: price withUnit: [[car valueForKey: @"fuelUnit"] integerValue]] floatValue];
    }
    @catch (NSException *e)
    {
        return NAN;
    }
}

@end



#pragma mark -
#pragma mark Average Cost per Distance View Controller



@implementation FuelStatisticsViewController_PriceDistance


- (CGGradientRef)curveGradient
{
    return [AppDelegate blueGradient];
}



- (NSNumberFormatter*)averageFormatter
{
    KSFuelConsumption consumptionUnit = [[self.selectedCar valueForKey: @"fuelConsumptionUnit"] integerValue];

    if (KSFuelConsumptionIsMetric (consumptionUnit))
        return [AppDelegate sharedCurrencyFormatter];
    else
        return [AppDelegate sharedDistanceFormatter];
}


- (NSString*)averageFormatString
{
    KSFuelConsumption consumptionUnit = [[self.selectedCar valueForKey: @"fuelConsumptionUnit"] integerValue];

    if (KSFuelConsumptionIsMetric (consumptionUnit))
        return @"∅ %@/100km";
    else
        return [NSString stringWithFormat: @"∅ %%@ mi/%@", [[AppDelegate sharedCurrencyFormatter] currencySymbol]];
}


- (NSString*)noAverageString
{
    KSFuelConsumption consumptionUnit = [[self.selectedCar valueForKey: @"fuelConsumptionUnit"] integerValue];

    return [NSString stringWithFormat: KSFuelConsumptionIsMetric (consumptionUnit)
                                            ? @"%@/100km"
                                            : @"mi/%@",
                        [[AppDelegate sharedCurrencyFormatter] currencySymbol]];
}


- (NSNumberFormatter*)axisFormatterForCar: (NSManagedObject*)car
{
    KSFuelConsumption consumptionUnit = [[car valueForKey: @"fuelConsumptionUnit"] integerValue];

    if (KSFuelConsumptionIsMetric (consumptionUnit))
        return [AppDelegate sharedAxisCurrencyFormatter];
    else
        return [AppDelegate sharedDistanceFormatter];
}


- (CGFloat)valueForManagedObject: (NSManagedObject*)managedObject forCar: (NSManagedObject*)car
{
    @try
    {
        if ([[managedObject valueForKey: @"filledUp"] boolValue] == NO)
            return NAN;

        NSDecimalNumberHandler *handler = [AppDelegate sharedConsumptionRoundingHandler];
        KSFuelConsumption consumptionUnit = [[car valueForKey: @"fuelConsumptionUnit"] integerValue];

        NSDecimalNumber *price = [managedObject valueForKey: @"price"];

        NSDecimalNumber *distance   = [managedObject valueForKey: @"distance"];
        NSDecimalNumber *fuelVolume = [managedObject valueForKey: @"fuelVolume"];
        NSDecimalNumber *cost       = [fuelVolume decimalNumberByMultiplyingBy: price];

        distance = [distance decimalNumberByAdding: [managedObject valueForKey: @"inheritedDistance"]];
        cost     = [cost     decimalNumberByAdding: [managedObject valueForKey: @"inheritedCost"]];

        if ([cost compare: [NSDecimalNumber zero]] == NSOrderedSame)
            return NAN;

        if (KSFuelConsumptionIsMetric (consumptionUnit))
            return [[[cost decimalNumberByMultiplyingByPowerOf10: 2]
                     decimalNumberByDividingBy: distance
                                  withBehavior: handler] floatValue];
        else
            return [[[distance decimalNumberByDividingBy: [AppDelegate kilometersPerStatuteMile]]
                     decimalNumberByDividingBy: cost
                                  withBehavior: handler] floatValue];
    }
    @catch (NSException *e)
    {
        return NAN;
    }
}

@end
