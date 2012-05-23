// FuelStatisticsGraphViewController.m
//
// Kraftstoff


#import "AppDelegate.h"
#import "FuelStatisticsViewControllerPrivateMethods.h"
#import "FuelStatisticsGraphViewController.h"



// Coordinates for the zoom-track
static CGFloat const StatisticsTrackYPosition =  40.0;
static CGFloat const StatisticsTrackThickness =   4.0;
static CGFloat const StatisticsInfoXMargin    =   9.0;
static CGFloat const StatisticsInfoYMargin    =   3.0;



#pragma mark -
#pragma mark Disposable Content Objects for ContentCache



#define MAX_SAMPLES   128

@interface FuelStatisticsSamplingData : NSObject
{
@public

    // Curve data
    CGPoint   data [MAX_SAMPLES];
    NSInteger dataCount;

    // Lens data
    NSTimeInterval lensDate [MAX_SAMPLES][2];
    CGFloat lensValue [MAX_SAMPLES];

    // Data for marker positions
    CGFloat   hMarkPositions [5];
    NSString* hMarkNames [5];
    NSInteger hMarkCount;

    CGFloat   vMarkPositions [3];
    NSString* vMarkNames [3];
    NSInteger vMarkCount;
}

@property (nonatomic, strong) UIImage  *contentImage;
@property (nonatomic, strong) NSNumber *contentAverage;

@end


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
#pragma mark Disposable Content Objects Entry for NSCache



@interface FuelStatisticsGraphViewController (private)

// Provided by subclasses for statistics
- (CGGradientRef)curveGradient;

- (NSNumberFormatter*)averageFormatter;
- (NSString*)averageFormatString: (BOOL)avgPrefix;
- (NSString*)noAverageString;

- (NSNumberFormatter*)axisFormatterForCar: (NSManagedObject*)car;
- (CGFloat)valueForManagedObject: (NSManagedObject*)managedObject forCar: (NSManagedObject*)car;

// Methods for Graph Computation
- (CGFloat)resampleFetchedObjects: (NSArray*)fetchedObjects forCar: (NSManagedObject*)car andState: (FuelStatisticsSamplingData*)state;
- (void)drawStatisticsForState: (FuelStatisticsSamplingData*)state;

// Zoom Lens Handling
- (void)longPressChanged: (id)sender;
- (void)drawLensWithBGImage: (UIImage*)background lensLocation: (CGPoint)location info: (NSString*)info;

@end



@implementation FuelStatisticsGraphViewController

@synthesize zoomRecognizer;


- (void)viewDidLoad
{
    [super viewDidLoad];

    self.zoomRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget: self action: @selector (longPressChanged:)];
    zoomRecognizer.minimumPressDuration    = 0.6;
    zoomRecognizer.numberOfTouchesRequired = 1;
    zoomRecognizer.enabled                 = NO;

    [self.view addGestureRecognizer: zoomRecognizer];
}


- (void)viewDidUnload
{
    [super viewDidUnload];

    self.zoomRecognizer = nil;
}


- (void)purgeDiscardableCacheContent
{
    [contentCache enumerateKeysAndObjectsUsingBlock: ^(id key, id data, BOOL *stop)
        {
            FuelStatisticsSamplingData *cell = (FuelStatisticsSamplingData*)data;

            if (self.zooming == NO || [key integerValue] != displayedNumberOfMonths)
                [cell setContentImage: nil];
        }];
}



#pragma mark -
#pragma mark Graph Computation



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

        state->lensDate  [i][0] = 0.0;
        state->lensDate  [i][1] = 0.0;
        state->lensValue [i]    = 0.0;
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
            // Collect sample data
            NSTimeInterval sampleInterval = [mostRecentDate timeIntervalSinceDate: [managedObject valueForKey: @"timestamp"]];
            NSInteger sampleIndex = (NSInteger)rint ((MAX_SAMPLES-1) * (1.0 - sampleInterval/rangeInterval));

            if (valRange < 0.0001)
                samples [sampleIndex] += 0.5;
            else
                samples [sampleIndex] += (value - valMin) / valRange;

            // Collect lens data
            state->lensDate  [sampleIndex][(samplesCount [sampleIndex] != 0)] = [[managedObject valueForKey: @"timestamp"] timeIntervalSince1970];
            state->lensValue [sampleIndex] += value;

            samplesCount [sampleIndex] += 1;
        }
    }


    // Build curve data from resampled values
    state->dataCount = 0;

    for (NSInteger i = 0; i < MAX_SAMPLES; i++)
        if (samplesCount [i])
        {
            state->data [state->dataCount] = CGPointMake ((CGFloat)i / (MAX_SAMPLES-1), 1.0 - samples [i] / samplesCount [i]);

            state->lensDate  [state->dataCount][0] = state->lensDate [i][0];
            state->lensDate  [state->dataCount][1] = state->lensDate [i][(samplesCount [i] > 1)];
            state->lensValue [state->dataCount]    = state->lensValue [i] / samplesCount [i];

            state->dataCount++;
        }

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
    NSDateFormatter *dateFormatter;
    NSDate *midDate;

    if (state->dataCount < 3 || [mostRecentDate timeIntervalSinceDate: sampleDate] < 604800)
    {
        dateFormatter = [AppDelegate sharedDateTimeFormatter];
        midDate       = nil;
    }
    else
    {
        dateFormatter = [AppDelegate sharedDateFormatter];
        midDate       = [NSDate dateWithTimeInterval: [mostRecentDate timeIntervalSinceDate: sampleDate]/2.0 sinceDate: sampleDate];
    }

    state->vMarkCount = 0;
    state->vMarkPositions [state->vMarkCount] = 0.0;
    state->vMarkNames     [state->vMarkCount] = [dateFormatter stringForObjectValue: sampleDate];
    state->vMarkCount++;

    if (midDate)
    {
        state->vMarkPositions [state->vMarkCount] = 0.5;
        state->vMarkNames     [state->vMarkCount] = [dateFormatter stringForObjectValue: midDate];
        state->vMarkCount++;
    }

    state->vMarkPositions [state->vMarkCount] = 1.0;
    state->vMarkNames     [state->vMarkCount] = [dateFormatter stringForObjectValue: mostRecentDate];
    state->vMarkCount++;

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



#pragma mark -
#pragma mark Graph Display



- (BOOL)displayCachedStatisticsForRecentMonths: (NSInteger)numberOfMonths
{
    // Cache lookup
    FuelStatisticsSamplingData *cell = [contentCache objectForKey: [NSNumber numberWithInteger: numberOfMonths]];
    NSNumber *averageValue = cell.contentAverage;
    UIImage  *cachedImage  = cell.contentImage;

    // Update summary in top right of view
    if (averageValue != nil && !isnan ([averageValue floatValue]))
        self.rightLabel.text = [NSString stringWithFormat: [self averageFormatString: YES], [[self averageFormatter] stringFromNumber: averageValue]];
    else
        self.rightLabel.text = [self noAverageString];

    // Update image contents on cache hit
    if (cachedImage != nil && averageValue != nil)
    {
        [self.activityView stopAnimating];

        UIImageView *imageView = (UIImageView*)self.view;
        imageView.image        = cachedImage;

        zoomRecognizer.enabled = (cell->dataCount > 0);
        return YES;
    }

    // Cache Miss => draw prelimary contents
    else
    {
        [self.activityView startAnimating];

        UIGraphicsBeginImageContextWithOptions (CGSizeMake (480.0, StatisticsViewHeight), YES, 0.0);
        {
            [self drawStatisticsForState: nil];

            UIImageView *imageView = (UIImageView*)self.view;
            imageView.image        = UIGraphicsGetImageFromCurrentImageContext ();
        }
        UIGraphicsEndImageContext ();

        zoomRecognizer.enabled = NO;
        return NO;
    }
}


- (void)computeAndRedisplayStatisticsForRecentMonths: (NSInteger)numberOfMonths
                                              forCar: (NSManagedObject*)car
                                           inContext: (NSManagedObjectContext*)context
{
    FuelStatisticsSamplingData *state = [contentCache objectForKey: [NSNumber numberWithInteger: numberOfMonths]];
    BOOL stateAllocated = NO;

    // No cache cell exists => resample data and compute average value
    if (state == nil)
    {
        state = [[FuelStatisticsSamplingData alloc] init];
        stateAllocated = YES;

        state.contentAverage = [NSNumber numberWithFloat:
                                    [self resampleFetchedObjects: [self fetchObjectsForRecentMonths: numberOfMonths
                                                                                             forCar: car
                                                                                          inContext: context]
                                                          forCar: car
                                                        andState: state]];
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



#pragma mark -
#pragma mark Zoom Lens Handling



@synthesize zooming;

- (void)setZooming: (BOOL)flag
{
    for (UIView *subview in [self.view subviews])
        if (subview.tag > 0)
        {
            if (subview.tag < 1000)
                subview.hidden = flag;
            else
                subview.hidden = !flag;
        }

    if (!flag)
        [self displayStatisticsForRecentMonths: displayedNumberOfMonths];
}


- (void)longPressChanged: (id)sender
{
    switch ([zoomRecognizer state])
    {
        case UIGestureRecognizerStatePossible:
            break;

        case UIGestureRecognizerStateBegan:
            self.zooming = YES;
            zoomIndex    = -1;

            // no break

        case UIGestureRecognizerStateChanged:
        {
            CGPoint lensLocation = [zoomRecognizer locationInView: self.view];

            // Keep horizontal position above graphics
            if (lensLocation.x < StatisticsLeftBorder)
                lensLocation.x = StatisticsLeftBorder;

            else if (lensLocation.x > StatisticsLeftBorder + StatisticsWidth)
                lensLocation.x = StatisticsLeftBorder + StatisticsWidth;

            lensLocation.x -= StatisticsLeftBorder;
            lensLocation.x /= StatisticsWidth;

            // Match nearest data point
            FuelStatisticsSamplingData *cell = [contentCache objectForKey: [NSNumber numberWithInteger: displayedNumberOfMonths]];

            int lb = 0, ub = cell->dataCount - 1;

            while (ub - lb > 1)
            {
                int mid = (lb+ub)/2;

                if (lensLocation.x < cell->data [mid].x)
                    ub = mid;
                else if (lensLocation.x > cell->data [mid].x)
                    lb = mid;
                else
                    lb = ub = mid;
            }

            int minIndex = (fabs (cell->data [lb].x - lensLocation.x) < fabs (cell->data [ub].x - lensLocation.x)) ? lb : ub;

            // Update screen contents
            if (minIndex >= 0 && minIndex != zoomIndex)
            {
                zoomIndex = minIndex;

                // Date information
                NSDateFormatter *df = [AppDelegate sharedLongDateFormatter];

                if (cell->lensDate [minIndex][0] == cell->lensDate [minIndex][1])
                    self.centerLabel.text = [df stringFromDate: [NSDate dateWithTimeIntervalSince1970: cell->lensDate [minIndex][0]]];
                else
                    self.centerLabel.text = [NSString stringWithFormat: @"%@  ➡  %@",
                                                [df stringFromDate: [NSDate dateWithTimeIntervalSince1970: cell->lensDate [minIndex][0]]],
                                                [df stringFromDate: [NSDate dateWithTimeIntervalSince1970: cell->lensDate [minIndex][1]]]];

                // Knob position
                lensLocation.x = rint (StatisticsLeftBorder + StatisticsWidth  * cell->data [minIndex].x);
                lensLocation.y = rint (StatisticsTopBorder  + StatisticsHeight * cell->data [minIndex].y);

                // Image with value information
                UIGraphicsBeginImageContextWithOptions (CGSizeMake (480.0, StatisticsViewHeight), YES, 0.0);
                {
                    NSString *valueString = [NSString stringWithFormat:
                                             [self averageFormatString: NO],
                                             [self.averageFormatter stringFromNumber: [NSNumber numberWithFloat: cell->lensValue [minIndex]]]];

                    [self drawLensWithBGImage: cell.contentImage lensLocation: lensLocation info: valueString];

                    UIImageView *imageView = (UIImageView*)self.view;
                    imageView.image = UIGraphicsGetImageFromCurrentImageContext ();
                }
                UIGraphicsEndImageContext ();
            }
        }
            break;

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            self.zooming = NO;
            break;
    }
}


- (void)drawLensWithBGImage: (UIImage*)background lensLocation: (CGPoint)location info: (NSString*)info
{
    CGContextRef cgContext = UIGraphicsGetCurrentContext ();

    UIBezierPath *path;


    // Graph as background
    [background drawAtPoint: CGPointZero blendMode: kCGBlendModeCopy alpha: 1.0];


    // Slider track
    CGContextSaveGState (cgContext);
    {
        path = [UIBezierPath bezierPathWithRoundedRect: CGRectMake (StatisticsLeftBorder, StatisticsTrackYPosition, StatisticsWidth, StatisticsTrackThickness)
                                     byRoundingCorners: UIRectCornerAllCorners
                                           cornerRadii: CGSizeMake (2.0, 2.0)];

        CGFloat scale = [[UIScreen mainScreen] scale];

        CGContextTranslateCTM (cgContext, 0.0, -1.0 / scale);
        [[UIColor blackColor] setFill];
        [path fill];

        CGContextTranslateCTM (cgContext, 0.0, +2.0 / scale);
        [[UIColor colorWithWhite: 0.5 alpha: 1.0] setFill];
        [path fill];

        CGContextTranslateCTM (cgContext, 0.0, -1.0 / scale);
        [[UIColor colorWithWhite: 0.28 alpha: 1.0] setFill];
        [path fill];
    }
    CGContextRestoreGState (cgContext);


    // Marker line
    CGContextSaveGState (cgContext);
    {
        CGContextSetShadowWithColor (cgContext, CGSizeMake (0.0, +2.0), 2.0, [[UIColor colorWithWhite: 0.0 alpha: 0.6] CGColor]);

        [[UIColor colorWithRed: 1.0 green: 0.756 blue: 0.188 alpha: 1.0] set];

        // Knob shadow
        [path removeAllPoints];
        [path addArcWithCenter: location radius: 8.0 startAngle: 0.0 endAngle: M_PI*2.0 clockwise: NO];
        [path fill];

        // Marker line
        path.lineWidth = 2;

        [path removeAllPoints];
        [path moveToPoint:    CGPointMake (location.x, StatisticsTrackYPosition + StatisticsTrackThickness)];
        [path addLineToPoint: CGPointMake (location.x, StatisticsBottomBorder)];
        [path stroke];
    }
    CGContextRestoreGState (cgContext);


    // Marker knob
    CGContextSaveGState (cgContext);
    {
        [[UIBezierPath bezierPathWithArcCenter: location radius: 8.0 startAngle: 0.0 endAngle: M_PI*2.0 clockwise: NO] addClip];

        CGContextDrawRadialGradient (cgContext,
                                     [AppDelegate knobGradient],
                                     CGPointMake (location.x, location.y - 2),
                                     0.0,
                                     location,
                                     8.0,
                                     kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    }
    CGContextRestoreGState (cgContext);


    // Layout for info box
    UIFont *font = [UIFont boldSystemFontOfSize: 14];
    CGRect infoRect;

    infoRect.size         = [info sizeWithFont: font];
    infoRect.size.width  += StatisticsInfoXMargin * 2.0;
    infoRect.size.height += StatisticsInfoYMargin * 2.0;
    infoRect.origin.x     = rint (location.x - infoRect.size.width/2);
    infoRect.origin.y     = StatisticsTrackYPosition + rint ((StatisticsTrackThickness - infoRect.size.height) / 2);

    if (infoRect.origin.x < StatisticsLeftBorder - 1)
        infoRect.origin.x = StatisticsLeftBorder - 1;

    if (infoRect.origin.x > StatisticsRightBorder - infoRect.size.width + 1)
        infoRect.origin.x = StatisticsRightBorder - infoRect.size.width + 1;

    // Info box
    path = [UIBezierPath bezierPathWithRoundedRect: infoRect
                                 byRoundingCorners: UIRectCornerAllCorners
                                       cornerRadii: CGSizeMake (6.0, 6.0)];

    // Box background
    CGContextSaveGState (cgContext);
    {
        CGContextSetShadowWithColor (cgContext, CGSizeMake (0.0, +1.0), 2.0, [[UIColor colorWithWhite: 0.0 alpha: 0.6] CGColor]);

        [[UIColor blackColor] set];
        [path fill];
    }
    CGContextRestoreGState (cgContext);

    // Box gradient
    CGContextSaveGState (cgContext);
    {
        [path addClip];

        CGContextDrawLinearGradient (cgContext,
                                     [AppDelegate infoGradient],
                                     infoRect.origin,
                                     CGPointMake (infoRect.origin.x, infoRect.origin.y + infoRect.size.height),
                                     kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    }
    CGContextRestoreGState (cgContext);


    // Info text
    CGContextSetShadowWithColor (cgContext, CGSizeMake (0.0, +1.0), 0.0, [[UIColor whiteColor] CGColor]);

    [[UIColor darkGrayColor] set];
    [info drawAtPoint: CGPointMake (infoRect.origin.x + StatisticsInfoXMargin, infoRect.origin.y + StatisticsInfoYMargin) withFont: font];
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


- (NSString*)averageFormatString: (BOOL)avgPrefix
{
    KSFuelConsumption consumptionUnit = [[self.selectedCar valueForKey: @"fuelConsumptionUnit"] integerValue];

    return [NSString stringWithFormat: @"%@%%@ %@", avgPrefix ? @"∅ " : @"", [AppDelegate consumptionUnitString: consumptionUnit]];
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

        return [[AppDelegate consumptionForKilometers: distance
                                               Liters: fuelVolume
                                               inUnit: consumptionUnit] floatValue];
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


- (NSString*)averageFormatString: (BOOL)avgPrefix
{
    NSInteger fuelUnit = [[self.selectedCar valueForKey: @"fuelUnit"] integerValue];

    return [NSString stringWithFormat: @"%@%%@/%@", avgPrefix ? @"∅ " : @"", [AppDelegate fuelUnitString: fuelUnit]];
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


- (NSString*)averageFormatString: (BOOL)avgPrefix
{
    KSFuelConsumption consumptionUnit = [[self.selectedCar valueForKey: @"fuelConsumptionUnit"] integerValue];

    if (KSFuelConsumptionIsMetric (consumptionUnit))
        return [NSString stringWithFormat: @"%@%%@/100km", avgPrefix ? @"∅ " : @""];
    else
        return [NSString stringWithFormat: @"%@%%@ mi/%@", avgPrefix ? @"∅ " : @"", [[AppDelegate sharedCurrencyFormatter] currencySymbol]];
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
