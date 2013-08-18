// FuelStatisticsGraphViewController.m
//
// Kraftstoff


#import "AppDelegate.h"
#import "FuelStatisticsViewControllerPrivateMethods.h"
#import "FuelStatisticsGraphViewController.h"
#import "AppDelegate.h"


// Coordinates for statistics graph
static CGFloat const StatisticGraphLeftBorder = 10.0;
static CGFloat const StatisticGraphRightBorder = 430.0;
static CGFloat const StatisticGraphTopBorder = 58.0;
static CGFloat const StatisticGraphBottomBorder = 240.0;
static CGFloat const StatisticGraphWidth = 420.0;
static CGFloat const StatisticGraphHeight = 182.0;

// Coordinates for the zoom-track
static CGFloat const StatisticTrackYPosition = 40.0;
static CGFloat const StatisticTrackThickness = 4.0;
static CGFloat const StatisticTrackInfoXMargin = 9.0;
static CGFloat const StatisticTrackInfoYMargin = 3.0;
static CGFloat const StatisticTrackInfoXMarginFlat = 4.0;
static CGFloat const StatisticTrackInfoYMarginFlat = 3.0;



#pragma mark -
#pragma mark Disposable Sampling Data Objects for ContentCache



#define MAX_SAMPLES 256

@interface FuelStatisticsSamplingData : NSObject <DiscardableDataObject>
{
@public

    // Curve data
    CGPoint data [MAX_SAMPLES];
    NSInteger dataCount;

    // Lens data
    NSTimeInterval lensDate [MAX_SAMPLES][2];
    CGFloat lensValue [MAX_SAMPLES];

    // Data for marker positions
    CGFloat hMarkPositions [5];
    NSString* hMarkNames [5];
    NSInteger hMarkCount;

    CGFloat vMarkPositions [3];
    NSString* vMarkNames [3];
    NSInteger vMarkCount;
}

@property (nonatomic, strong) UIImage *contentImage;
@property (nonatomic, strong) NSNumber *contentAverage;

@end



@implementation FuelStatisticsSamplingData

- (id)init
{
    if ((self = [super init]))
    {
        dataCount  = 0;
        hMarkCount = 0;
        vMarkCount = 0;

        for (int i = 0; i < 5; i++)
            hMarkNames [i] = nil;

        for (int i = 0; i < 3; i++)
            vMarkNames [i] = nil;
    }

    return self;
}

- (void)discardContent;
{
    self.contentImage = nil;
}

@end



#pragma mark -
#pragma mark Base Class for Graphical Statistics View Controller



// Provided by subclasses for statistics
@interface FuelStatisticsGraphViewController (private)

- (CGGradientRef)curveGradient;

- (NSNumberFormatter*)averageFormatter:(BOOL)precise;
- (NSString *)averageFormatString:(BOOL)avgPrefix;
- (NSString *)noAverageString;

- (NSNumberFormatter*)axisFormatterForCar:(NSManagedObject *)car;
- (CGFloat)valueForManagedObject:(NSManagedObject *)managedObject forCar:(NSManagedObject *)car;

@end



@implementation FuelStatisticsGraphViewController
{
    NSInteger zoomIndex;
}



#pragma mark -
#pragma mark Default Position/Dimension Data for Graphs



- (CGFloat)graphLeftBorder
{
    return StatisticGraphLeftBorder;
}

- (CGFloat)graphRightBorder
{
    return StatisticGraphRightBorder + ([AppDelegate isLongPhone] ? 88.0 : 0.0);
}

- (CGFloat)graphTopBorder
{
    return StatisticGraphTopBorder;
}

- (CGFloat)graphBottomBorder
{
    return StatisticGraphBottomBorder + ([AppDelegate systemMajorVersion] >= 7 ? 32.0 : 0.0);
}

- (CGFloat)graphWidth
{
    return StatisticGraphWidth + ([AppDelegate isLongPhone] ? 88.0 : 0.0);
}

- (CGFloat)graphHeight
{
    return StatisticGraphHeight + ([AppDelegate systemMajorVersion] >= 7 ? 32.0 : 0.0);
}



#pragma mark -
#pragma mark View Lifecycle



- (void)viewDidLoad
{
    [super viewDidLoad];

    self.zoomRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressChanged:)];
    _zoomRecognizer.minimumPressDuration = 0.4;
    _zoomRecognizer.numberOfTouchesRequired = 1;
    _zoomRecognizer.enabled = NO;

    [self.view addGestureRecognizer:_zoomRecognizer];
}



#pragma mark -
#pragma mark Graph Computation



- (CGFloat)resampleFetchedObjects:(NSArray *)fetchedObjects
                           forCar:(NSManagedObject *)car
                         andState:(FuelStatisticsSamplingData*)state
           inManagedObjectContext:(NSManagedObjectContext *)moc
{
    NSDate *firstDate = nil;
    NSDate *midDate = nil;
    NSDate *lastDate = nil;

    // Compute vertical range of curve
    NSInteger valCount =  0;
    NSInteger valFirstIndex = -1;
    NSInteger valLastIndex = -1;

    CGFloat valAverage = 0.0;

    CGFloat valMin = +INFINITY;
    CGFloat valMax = -INFINITY;
    CGFloat valRange, valStretchFactorForDisplay;

    for (NSInteger i = [fetchedObjects count] - 1; i >= 0; i--) {

        NSManagedObject *managedObject = [AppDelegate existingObject:fetchedObjects[i] inManagedObjectContext:moc];

        if (managedObject) {

            CGFloat value = [self valueForManagedObject:managedObject forCar:car];

            if (!isnan (value)) {

                valCount   += 1;
                valAverage += value;

                if (valMin > value)
                    valMin = value;

                if (valMax < value)
                    valMax = value;

                if (valLastIndex < 0) {

                    valLastIndex = i;
                    lastDate = [managedObject valueForKey:@"timestamp"];

                } else {

                    valFirstIndex = i;
                    firstDate = [managedObject valueForKey:@"timestamp"];
                }
            }
        }
    }

    // Not enough data
    if (valCount < 2) {

        state->dataCount = 0;
        state->hMarkCount = 0;
        state->vMarkCount = 0;

        return valCount == 0 ? NAN : valAverage;
    }

    valAverage /= valCount;

    valMin = floor (valMin * 2.0) / 2.0;
    valMax = ceil  (valMax / 2.0) * 2.0;
    valRange = valMax - valMin;

    if (valRange > 40) {

        valMin = floor (valMin / 10.0) * 10.0;
        valMax = ceil  (valMax / 10.0) * 10.0;

    } else if (valRange > 8) {

        valMin = floor (valMin / 2.0) * 2.0;
        valMax = ceil  (valMax / 2.0) * 2.0;

    } else if (valRange > 4) {

        valMin = floor (valMin);
        valMax = ceil  (valMax);

    } else if (valRange < 0.25) {

        valMin = floor (valMin * 4.0 - 0.001) / 4.0;
        valMax = ceilf (valMax * 4.0 + 0.001) / 4.0;
    }

    valRange = valMax - valMin;

    // iOS7:shrink the computed graph to keep the top h-marker below the top-border
    if ([AppDelegate systemMajorVersion] >= 7 && valRange > 0.0001)
        valStretchFactorForDisplay = StatisticsHeight / (StatisticsHeight + 18);
    else
        valStretchFactorForDisplay = 1.0;

    // Resampling of fetched data
    CGFloat samples [MAX_SAMPLES];
    NSInteger samplesCount [MAX_SAMPLES];

    for (NSInteger i = 0; i < MAX_SAMPLES; i++) {

        samples [i] = 0.0;
        samplesCount [i] = 0;

        state->lensDate  [i][0] = 0.0;
        state->lensDate  [i][1] = 0.0;
        state->lensValue [i]    = 0.0;
    }

    NSTimeInterval rangeInterval = [firstDate timeIntervalSinceDate:lastDate];

    for (NSInteger i = valLastIndex; i >= valFirstIndex; i--) {

        NSManagedObject *managedObject = [AppDelegate existingObject:fetchedObjects[i] inManagedObjectContext:moc];

        if (managedObject) {

            CGFloat value = [self valueForManagedObject:managedObject forCar:car];

            if (!isnan (value)) {

                // Collect sample data
                NSTimeInterval sampleInterval = [firstDate timeIntervalSinceDate:[managedObject valueForKey:@"timestamp"]];
                NSInteger sampleIndex = (NSInteger)rint ((MAX_SAMPLES-1) * (1.0 - sampleInterval/rangeInterval));

                if (valRange < 0.0001)
                    samples [sampleIndex] += 0.5;
                else
                    samples [sampleIndex] += (value - valMin) / valRange * valStretchFactorForDisplay;

                // Collect lens data
                state->lensDate  [sampleIndex][(samplesCount [sampleIndex] != 0)] = [[managedObject valueForKey:@"timestamp"] timeIntervalSince1970];
                state->lensValue [sampleIndex] += value;

                samplesCount [sampleIndex] += 1;
            }
        }
    }


    // Build curve data from resampled values
    state->dataCount = 0;

    for (NSInteger i = 0; i < MAX_SAMPLES; i++)
        if (samplesCount [i]) {

            state->data [state->dataCount] = CGPointMake ((CGFloat)i / (MAX_SAMPLES-1), 1.0 - samples [i] / samplesCount [i]);

            state->lensDate [state->dataCount][0] = state->lensDate [i][0];
            state->lensDate [state->dataCount][1] = state->lensDate [i][(samplesCount [i] > 1)];
            state->lensValue [state->dataCount] = state->lensValue [i] / samplesCount [i];

            state->dataCount++;
        }

    // Markers for vertical axis
    NSNumberFormatter *numberFormatter = [self axisFormatterForCar:car];

    state->hMarkPositions [0] = 1.0 - (1.0  * valStretchFactorForDisplay);
    state->hMarkNames [0] = [numberFormatter stringFromNumber:@(valMin + valRange)];

    state->hMarkPositions [1] = 1.0 - (0.75 * valStretchFactorForDisplay);
    state->hMarkNames [1] = [numberFormatter stringFromNumber:@((float)(valMin + valRange*0.75))];

    state->hMarkPositions [2] = 1.0 - (0.5  * valStretchFactorForDisplay);
    state->hMarkNames [2] = [numberFormatter stringFromNumber:@((float)(valMin + valRange*0.5))];

    state->hMarkPositions [3] = 1.0 - (0.25 * valStretchFactorForDisplay);
    state->hMarkNames [3] = [numberFormatter stringFromNumber:@((float)(valMin + valRange*0.25))];

    state->hMarkPositions [4] = 1.0;
    state->hMarkNames [4] = [numberFormatter stringFromNumber:@(valMin)];
    state->hMarkCount = 5;


    // Markers for horizontal axis
    NSDateFormatter *dateFormatter = nil;

    if (state->dataCount < 3 || [firstDate timeIntervalSinceDate:lastDate] < 604800) {

        dateFormatter = [AppDelegate sharedDateTimeFormatter];
        midDate = nil;

    } else {

        dateFormatter = [AppDelegate sharedDateFormatter];
        midDate = [NSDate dateWithTimeInterval:[firstDate timeIntervalSinceDate:lastDate]/2.0 sinceDate:lastDate];
    }

    state->vMarkCount = 0;
    state->vMarkPositions [state->vMarkCount] = 0.0;
    state->vMarkNames [state->vMarkCount] = [dateFormatter stringForObjectValue:lastDate];
    state->vMarkCount++;

    if (midDate) {

        state->vMarkPositions [state->vMarkCount] = 0.5;
        state->vMarkNames [state->vMarkCount] = [dateFormatter stringForObjectValue:midDate];
        state->vMarkCount++;
    }

    state->vMarkPositions [state->vMarkCount] = 1.0;
    state->vMarkNames [state->vMarkCount] = [dateFormatter stringForObjectValue:firstDate];
    state->vMarkCount++;

    return valAverage;
}


- (id<DiscardableDataObject>)computeStatisticsForRecentMonths:(NSInteger)numberOfMonths
                                                       forCar:(NSManagedObject *)car
                                                  withObjects:(NSArray *)fetchedObjects
                                       inManagedObjectContext:(NSManagedObjectContext *)moc
                                   
{
    // No cache cell exists => resample data and compute average value
    FuelStatisticsSamplingData *state = self.contentCache[@(numberOfMonths)];
    
    if (state == nil) {

        state = [[FuelStatisticsSamplingData alloc] init];
        state.contentAverage = @([self resampleFetchedObjects:fetchedObjects forCar:car andState:state inManagedObjectContext:moc]);
    }
    
    
    // Create image data from resampled data
    if (state.contentImage == nil) {

        UIGraphicsBeginImageContextWithOptions (CGSizeMake (StatisticsViewWidth, StatisticsViewHeight), YES, 0.0);
        {
            if ([AppDelegate systemMajorVersion] < 7)
                [self drawStatisticsForState:state];
            else
                [self drawFlatStatisticsForState:state];

            state.contentImage = UIGraphicsGetImageFromCurrentImageContext();
        }
        UIGraphicsEndImageContext();
    }
    
    return state;
}



#pragma mark -
#pragma mark Graph Display



- (void)drawStatisticsForState:(FuelStatisticsSamplingData*)state
{
    CGContextRef cgContext = UIGraphicsGetCurrentContext();


    // Background shade with rounded corners
    [[UIColor blackColor] setFill];
    CGContextFillRect (cgContext, CGRectMake (0.0, 0.0, StatisticsViewWidth, StatisticsViewHeight));

    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake (1.0, 0.0, StatisticsViewWidth - 2.0, StatisticsViewHeight)
                           byRoundingCorners:UIRectCornerAllCorners
                                 cornerRadii:CGSizeMake (12.0, 12.0)] addClip];

    CGContextDrawLinearGradient (cgContext,
                                 [AppDelegate backGradient],
                                 CGPointMake (0.0, StatisticsViewHeight + StatusBarHeight),
                                 CGPointMake (0.0, 0.0),
                                 kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);


    // Contents if there is a valid state
    if (state == nil)
        return;

    UIFont *font       = [UIFont boldSystemFontOfSize:14];
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat x, y;

    if (state->dataCount == 0) {

        CGContextSaveGState (cgContext);
        {
            CGContextSetShadowWithColor (cgContext, CGSizeMake (0.0, -1.0), 0.0, [[UIColor blackColor] CGColor]);
            [[UIColor whiteColor] setFill];

            NSString *text = _I18N(@"Not enough data to display statistics");
            CGSize size    = [text sizeWithFont:font];

            x = floor ((StatisticsViewWidth -  size.width)/2.0);
            y = floor ((320.0 - (size.height - font.descender))/2.0 - 18.0);

            [text drawAtPoint:CGPointMake (x, y)   withFont:font];
        }
        CGContextRestoreGState (cgContext);

    } else {

        // Color for coordinate-axes
        [[UIColor colorWithWhite:0.45 alpha:1.0] setStroke];


        // Horizontal marker lines (clipped away below the curve)
        CGContextSaveGState (cgContext);
        {
            CGFloat   dashDotPattern [2]   = { 1.0, 1.0 };
            NSInteger dashDotPatternLength = 2;

            // Clipping
            [path removeAllPoints];
            [path moveToPoint:CGPointMake (self.graphLeftBorder, self.graphTopBorder)];

            for (NSInteger i = 0; i < state->dataCount; i++) {

                x = rint (self.graphLeftBorder + self.graphWidth  * state->data [i].x);
                y = rint (self.graphTopBorder  + self.graphHeight * state->data [i].y);

                [path addLineToPoint:CGPointMake (x, y)];
            }

            [path addLineToPoint:CGPointMake (self.graphRightBorder, self.graphTopBorder)];
            [path closePath];
            [path addClip];

            // Marker lines
            path.lineWidth = 1;
            [path setLineDash:dashDotPattern count:dashDotPatternLength phase:0.0];

            [path removeAllPoints];
            [path moveToPoint:CGPointMake (self.graphLeftBorder, 0.5)];
            [path addLineToPoint:CGPointMake (self.graphRightBorder, 0.5)];

            CGContextSaveGState (cgContext);
            {
                CGFloat lastY;

                for (NSInteger i = 0, y = 0.0; i < state->hMarkCount; i++) {

                    lastY = y;
                    y = rint (self.graphTopBorder + self.graphHeight * state->hMarkPositions [i]);

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
                if (state->hMarkNames [i] != nil) {

                    CGSize size = [state->hMarkNames[i] sizeWithFont:font];

                    x = self.graphRightBorder + 6;
                    y = floor (self.graphTopBorder + 0.5 + self.graphHeight * state->hMarkPositions [i] - size.height - font.descender) + 0.5;

                    [state->hMarkNames[i] drawAtPoint:CGPointMake (x, y) withFont:font];
                }
        }
        CGContextRestoreGState (cgContext);


        // Vertical marker lines
        path.lineWidth = 2;
        [path setLineDash:NULL count:0 phase:0.0];

        [path removeAllPoints];
        [path moveToPoint:CGPointMake (0, self.graphTopBorder)];
        [path addLineToPoint:CGPointMake (0, self.graphBottomBorder)];

        CGContextSaveGState (cgContext);
        {
            CGFloat lastX;

            for (NSInteger i = 0, x = 0.0; i < state->vMarkCount; i++) {

                lastX = x;
                x = rint (self.graphLeftBorder + self.graphWidth * state->vMarkPositions [i]);

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
                if (state->vMarkNames [i] != nil) {

                    CGSize size = [state->vMarkNames[i] sizeWithFont:font];

                    x = floor (self.graphLeftBorder + 0.5 + self.graphWidth * state->vMarkPositions [i] - size.width/2.0);
                    y = self.graphBottomBorder + 5;

                    if (x < self.graphLeftBorder)
                        x = self.graphLeftBorder;

                    if (x > self.graphRightBorder - size.width)
                        x = self.graphRightBorder - size.width;

                    [state->vMarkNames[i] drawAtPoint:CGPointMake (x, y) withFont:font];
                }
        }
        CGContextRestoreGState (cgContext);


        // Pattern fill below cure
        CGContextSaveGState (cgContext);
        {
            [path removeAllPoints];
            [path moveToPoint:CGPointMake (self.graphLeftBorder + 1, self.graphBottomBorder)];

            for (NSInteger i = 0; i < state->dataCount; i++) {

                x = rint (self.graphLeftBorder + self.graphWidth * state->data [i].x);
                y = rint (self.graphTopBorder + self.graphHeight * state->data [i].y);

                [path addLineToPoint:CGPointMake (x, y)];
            }

            [path addLineToPoint:CGPointMake (self.graphRightBorder, self.graphBottomBorder)];
            [path closePath];

            // Color gradient
            [path addClip];
            CGContextDrawLinearGradient (cgContext,
                                         [self curveGradient],
                                         CGPointMake (0, self.graphBottomBorder),
                                         CGPointMake (320, self.graphTopBorder),
                                         kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);

            // Stripe pattern
            [path removeAllPoints];
            [path moveToPoint:CGPointMake (self.graphLeftBorder, 0)];
            [path addLineToPoint:CGPointMake (self.graphRightBorder, 0)];

            CGContextSaveGState (cgContext);
            {
                CGContextTranslateCTM (cgContext, 0.0, self.graphTopBorder-2);

                for (NSInteger i = 0; i < (NSInteger)self.graphHeight; i += 4) {

                    CGContextTranslateCTM (cgContext, 0.0, 4.0);
                    [[UIColor colorWithWhite:0.8 alpha:0.28 - 0.20 * i/self.graphHeight] setStroke];
                    [path stroke];
                }
            }
            CGContextRestoreGState (cgContext);
        }
        CGContextRestoreGState (cgContext);


        // Bottom line
        path.lineWidth = 2;
        [path removeAllPoints];
        [path moveToPoint:CGPointMake (self.graphLeftBorder - 1, self.graphBottomBorder)];
        [path addLineToPoint:CGPointMake (self.graphRightBorder + 1, self.graphBottomBorder)];
        [path stroke];

        // Left line
        [path removeAllPoints];
        [path moveToPoint:CGPointMake (self.graphLeftBorder, self.graphTopBorder)];
        [path addLineToPoint:CGPointMake (self.graphLeftBorder, self.graphBottomBorder)];
        [path stroke];

        // Right line
        [path removeAllPoints];
        [path moveToPoint:CGPointMake (self.graphRightBorder, self.graphTopBorder)];
        [path addLineToPoint:CGPointMake (self.graphRightBorder, self.graphBottomBorder)];
        [path stroke];


        // The curve
        path.lineWidth    = 4;
        path.lineCapStyle = kCGLineCapRound;
        [[UIColor whiteColor] setStroke];

        [path removeAllPoints];
        [path moveToPoint:CGPointMake (rint (self.graphLeftBorder + self.graphWidth * state->data [0].x),
                                       rint (self.graphTopBorder + self.graphHeight * state->data [0].y))];

        for (NSInteger i = 1; i < state->dataCount; i++) {

            x = rint (self.graphLeftBorder + self.graphWidth * state->data [i].x);
            y = rint (self.graphTopBorder + self.graphHeight * state->data [i].y);

            [path addLineToPoint:CGPointMake (x, y)];
        }

        [path stroke];
    }
}


- (void)drawFlatStatisticsForState:(FuelStatisticsSamplingData*)state
{
    CGContextRef cgContext = UIGraphicsGetCurrentContext();


    // Background colors
    [[UIColor colorWithWhite:0.082 alpha:1.0] setFill];
    CGContextFillRect (cgContext, CGRectMake(0, 0, StatisticsViewWidth, StatisticsViewHeight));

    [[UIColor blackColor] setFill];
    CGContextFillRect (cgContext, CGRectMake(0, 0, StatisticsViewWidth, 28.0));


    // Contents if there is a valid state
    if (state == nil)
        return;

    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Light" size:12.0];
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat x, y;

    if (state->dataCount == 0) {

        CGContextSaveGState (cgContext);
        {
            [[UIColor whiteColor] setFill];

            NSString *text = _I18N(@"Not enough data to display statistics");
            CGSize size    = [text sizeWithFont:font];

            x = floor ((StatisticsViewWidth - size.width)/2.0);
            y = floor ((320.0 - (size.height - font.descender))/2.0 - 18.0);

            [text drawAtPoint:CGPointMake (x, y) withFont:font];
        }
        CGContextRestoreGState (cgContext);

    } else {

        // Color for coordinate-axes
        [[UIColor colorWithWhite:0.224 alpha:1.0] setStroke];


        // Horizontal marker lines
        CGContextSaveGState (cgContext);
        {
            CGFloat dashDotPattern [2]   = { 0.5, 0.5 };
            NSInteger dashDotPatternLength = 1;

            // Marker lines
            path.lineWidth = 0.5;
            [path setLineDash:dashDotPattern count:dashDotPatternLength phase:0.0];

            [path removeAllPoints];
            [path moveToPoint:CGPointMake (self.graphLeftBorder,  0.25)];
            [path addLineToPoint:CGPointMake (StatisticsViewWidth - self.graphLeftBorder, 0.25)];

            CGContextSaveGState (cgContext);
            {
                CGFloat lastY;

                for (NSInteger i = 0, y = 0.0; i < state->hMarkCount; i++) {

                    lastY = y;
                    y = rint (self.graphTopBorder + self.graphHeight * state->hMarkPositions [i]);

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
            [[UIColor whiteColor] setFill];

            for (NSInteger i = 0; i < state->hMarkCount; i++)
                if (state->hMarkNames [i] != nil) {

                    CGSize size = [state->hMarkNames[i] sizeWithFont:font];

                    x = self.graphRightBorder + 6;
                    y = floor (self.graphTopBorder + 0.5 + self.graphHeight * state->hMarkPositions [i] - size.height) + 0.5;

                    [state->hMarkNames[i] drawAtPoint:CGPointMake (x, y) withFont:font];
                }
        }
        CGContextRestoreGState (cgContext);

        
        // Vertical marker lines
        path.lineWidth = 0.5;
        [path setLineDash:NULL count:0 phase:0.0];

        [path removeAllPoints];
        [path moveToPoint:CGPointMake (0.25, self.graphTopBorder)];
        [path addLineToPoint:CGPointMake (0.25, self.graphBottomBorder + 6)];

        CGContextSaveGState (cgContext);
        {
            CGFloat lastX;

            for (NSInteger i = 0, x = 0.0; i < state->vMarkCount; i++) {

                lastX = x;
                x = rint (self.graphLeftBorder + self.graphWidth * state->vMarkPositions [i]);

                CGContextTranslateCTM (cgContext, x - lastX, 0.0);
                [path stroke];
            }
        }
        CGContextRestoreGState (cgContext);


        // Axis description for vertical marker lines
        CGContextSaveGState (cgContext);
        {
            [[UIColor colorWithWhite:0.78 alpha:1.0] setFill];

            for (NSInteger i = 0; i < state->vMarkCount; i++)
                if (state->vMarkNames [i] != nil) {

                    CGSize size = [state->vMarkNames[i] sizeWithFont:font];

                    x = floor (self.graphLeftBorder + 0.5 + self.graphWidth * state->vMarkPositions [i] - size.width/2.0);
                    y = self.graphBottomBorder + 5;

                    if (x < self.graphLeftBorder)
                        x = self.graphLeftBorder;

                    if (x > self.graphRightBorder - size.width)
                        x = self.graphRightBorder - size.width;

                    [state->vMarkNames[i] drawAtPoint:CGPointMake (x, y)   withFont:font];
                }
        }
        CGContextRestoreGState (cgContext);

        
        // Pattern fill below cure
        CGContextSaveGState (cgContext);
        {
            [path removeAllPoints];
            [path moveToPoint:CGPointMake (self.graphLeftBorder + 1, self.graphBottomBorder)];

            CGFloat minY = self.graphBottomBorder - 6;

            for (NSInteger i = 0; i < state->dataCount; i++) {

                x = rint (self.graphLeftBorder + self.graphWidth * state->data [i].x);
                y = rint (self.graphTopBorder + self.graphHeight * state->data [i].y);

                [path addLineToPoint:CGPointMake (x, y)];

                if (y < minY)
                    minY = y;
            }

            if (minY == self.graphBottomBorder - 6)
                minY = self.graphTopBorder;

            [path addLineToPoint:CGPointMake (self.graphRightBorder, self.graphBottomBorder)];
            [path closePath];

            // Color gradient
            [path addClip];
            CGContextDrawLinearGradient (cgContext,
                                         [self curveGradient],
                                         CGPointMake (0, self.graphBottomBorder - 6),
                                         CGPointMake (0, minY),
                                         kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);

        }
        CGContextRestoreGState (cgContext);

        
        // Top and bottom lines
        [[UIColor colorWithWhite:0.78 alpha:1.0] setStroke];
        path.lineWidth = 0.5;

        [path removeAllPoints];
        [path moveToPoint:CGPointMake (self.graphLeftBorder, self.graphTopBorder + 0.25)];
        [path addLineToPoint:CGPointMake (StatisticsViewWidth - self.graphLeftBorder, self.graphTopBorder + 0.25)];
        [path stroke];

        [path removeAllPoints];
        [path moveToPoint:CGPointMake (self.graphLeftBorder, self.graphBottomBorder + 0.25)];
        [path addLineToPoint:CGPointMake (StatisticsViewWidth - self.graphLeftBorder, self.graphBottomBorder + 0.25)];
        [path stroke];


        // The curve
        path.lineWidth    = 1;
        path.lineCapStyle = kCGLineCapRound;
        [[UIColor whiteColor] setStroke];
        
        [path removeAllPoints];
        [path moveToPoint:CGPointMake (rint (self.graphLeftBorder + self.graphWidth * state->data [0].x),
                                       rint (self.graphTopBorder + self.graphHeight * state->data [0].y))];
        
        for (NSInteger i = 1; i < state->dataCount; i++) {

            x = rint (self.graphLeftBorder + self.graphWidth * state->data [i].x);
            y = rint (self.graphTopBorder + self.graphHeight * state->data [i].y);
            
            [path addLineToPoint:CGPointMake (x, y)];
        }
        
        [path stroke];
    }
}


- (BOOL)displayCachedStatisticsForRecentMonths:(NSInteger)numberOfMonths
{
    UIImageView *imageView = (UIImageView*)self.view;


    // Cache lookup
    FuelStatisticsSamplingData *cell = self.contentCache[@(numberOfMonths)];
    NSNumber *average = cell.contentAverage;
    UIImage *image = cell.contentImage;

    // Update summary in top right of view
    if (average != nil && !isnan ([average floatValue]))
        self.rightLabel.text = [NSString stringWithFormat:[self averageFormatString:YES], [[self averageFormatter:NO] stringFromNumber:average]];
    else
        self.rightLabel.text = [self noAverageString];

    // Update image contents on cache hit
    if (image != nil && average != nil) {

        [self.activityView stopAnimating];

        [UIView transitionWithView:imageView
                          duration:StatisticTransitionDuration
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{ imageView.image = image; }
                        completion:nil];

        _zoomRecognizer.enabled = (cell->dataCount > 0);
        return YES;

    // Cache Miss => draw prelimary contents
    } else {

        UIGraphicsBeginImageContextWithOptions (CGSizeMake (StatisticsViewWidth, StatisticsViewHeight), YES, 0.0);
        {
            if ([AppDelegate systemMajorVersion] < 7)
                [self drawStatisticsForState:nil];
            else
                [self drawFlatStatisticsForState:nil];

            image = UIGraphicsGetImageFromCurrentImageContext();
        }
        UIGraphicsEndImageContext();

        [UIView transitionWithView:imageView
                          duration:StatisticTransitionDuration
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{ imageView.image = image; }
                        completion:^(BOOL finished){

                            if (finished)
                                [self.activityView startAnimating];
                        }];

        _zoomRecognizer.enabled = NO;
        return NO;
    }
}



#pragma mark -
#pragma mark Zoom Lens Handling



@synthesize zooming;

- (void)setZooming:(BOOL)flag
{
    for (UIView *subview in [self.view subviews])
        if (subview.tag > 0) {

            if (subview.tag < 1000)
                subview.hidden = flag;
            else
                subview.hidden = !flag;
        }

    if (!flag)
        [self displayStatisticsForRecentMonths:self.displayedNumberOfMonths];
}


- (void)longPressChanged:(id)sender
{
    switch ([_zoomRecognizer state])
    {
        case UIGestureRecognizerStatePossible:
            break;

        case UIGestureRecognizerStateBegan:
        {
            // Cancel long press gesture when located above the graph (new the radio buttons)
            if ([_zoomRecognizer locationInView:self.view].y < self.graphTopBorder) {

                _zoomRecognizer.enabled = NO;
                _zoomRecognizer.enabled = YES;
                break;
            }

            self.zooming = YES;
            zoomIndex    = -1;
        }

            // no break

        case UIGestureRecognizerStateChanged:
        {
            CGPoint lensLocation = [_zoomRecognizer locationInView:self.view];

            // Keep horizontal position above graphics
            if (lensLocation.x < self.graphLeftBorder)
                lensLocation.x = self.graphLeftBorder;

            else if (lensLocation.x > self.graphLeftBorder + self.graphWidth)
                lensLocation.x = self.graphLeftBorder + self.graphWidth;

            lensLocation.x -= self.graphLeftBorder;
            lensLocation.x /= self.graphWidth;

            // Match nearest data point
            FuelStatisticsSamplingData *cell = self.contentCache[@(self.displayedNumberOfMonths)];

            if (cell) {

                int lb = 0, ub = cell->dataCount - 1;

                while (ub - lb > 1) {

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
                if (minIndex >= 0 && minIndex != zoomIndex) {

                    zoomIndex = minIndex;

                    // Date information
                    NSDateFormatter *df = [AppDelegate sharedLongDateFormatter];

                    if (cell->lensDate [minIndex][0] == cell->lensDate [minIndex][1])
                        self.centerLabel.text = [df stringFromDate:[NSDate dateWithTimeIntervalSince1970:cell->lensDate [minIndex][0]]];
                    else
                        self.centerLabel.text = [NSString stringWithFormat:@"%@  ➡  %@",
                                                    [df stringFromDate:[NSDate dateWithTimeIntervalSince1970:cell->lensDate [minIndex][0]]],
                                                    [df stringFromDate:[NSDate dateWithTimeIntervalSince1970:cell->lensDate [minIndex][1]]]];

                    // Knob position
                    lensLocation.x = rint (self.graphLeftBorder + self.graphWidth * cell->data [minIndex].x);
                    lensLocation.y = rint (self.graphTopBorder + self.graphHeight * cell->data [minIndex].y);

                    // Image with value information
                    UIGraphicsBeginImageContextWithOptions (CGSizeMake (StatisticsViewWidth, StatisticsViewHeight), YES, 0.0);
                    {
                        NSString *valueString = [NSString stringWithFormat:
                                                    [self averageFormatString:NO],
                                                        [[self averageFormatter:YES]
                                                            stringFromNumber:@(cell->lensValue [minIndex])]];

                        if ([AppDelegate systemMajorVersion] < 7)
                            [self drawLensWithBGImage:cell.contentImage lensLocation:lensLocation info:valueString];
                        else
                            [self drawFlatLensWithBGImage:cell.contentImage lensLocation:lensLocation info:valueString];

                        UIImageView *imageView = (UIImageView*)self.view;
                        imageView.image = UIGraphicsGetImageFromCurrentImageContext();
                    }
                    UIGraphicsEndImageContext();
                }
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



- (void)drawLensWithBGImage:(UIImage*)background lensLocation:(CGPoint)location info:(NSString *)info
{
    CGContextRef cgContext = UIGraphicsGetCurrentContext();

    UIBezierPath *path;


    // Graph as background
    [background drawAtPoint:CGPointZero blendMode:kCGBlendModeCopy alpha:1.0];


    // Slider track
    CGContextSaveGState (cgContext);
    {
        path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake (self.graphLeftBorder, StatisticTrackYPosition, self.graphWidth, StatisticTrackThickness)
                                     byRoundingCorners:UIRectCornerAllCorners
                                           cornerRadii:CGSizeMake (2.0, 2.0)];

        CGFloat scale = [[UIScreen mainScreen] scale];

        CGContextTranslateCTM (cgContext, 0.0, -1.0 / scale);
        [[UIColor blackColor] setFill];
        [path fill];

        CGContextTranslateCTM (cgContext, 0.0, +2.0 / scale);
        [[UIColor colorWithWhite:0.5 alpha:1.0] setFill];
        [path fill];

        CGContextTranslateCTM (cgContext, 0.0, -1.0 / scale);
        [[UIColor colorWithWhite:0.28 alpha:1.0] setFill];
        [path fill];
    }
    CGContextRestoreGState (cgContext);


    // Marker line
    CGContextSaveGState (cgContext);
    {
        CGContextSetShadowWithColor (cgContext, CGSizeMake (0.0, +2.0), 2.0, [[UIColor colorWithWhite:0.0 alpha:0.6] CGColor]);

        [[UIColor colorWithRed:1.0 green:0.756 blue:0.188 alpha:1.0] set];

        // Knob shadow
        [path removeAllPoints];
        [path addArcWithCenter:location radius:8.0 startAngle:0.0 endAngle:M_PI*2.0 clockwise:NO];
        [path fill];

        // Marker line
        path.lineWidth = 2;

        [path removeAllPoints];
        [path moveToPoint:CGPointMake (location.x, StatisticTrackYPosition + StatisticTrackThickness)];
        [path addLineToPoint:CGPointMake (location.x, self.graphBottomBorder)];
        [path stroke];
    }
    CGContextRestoreGState (cgContext);


    // Marker knob
    CGContextSaveGState (cgContext);
    {
        [[UIBezierPath bezierPathWithArcCenter:location radius:8.0 startAngle:0.0 endAngle:M_PI*2.0 clockwise:NO] addClip];

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
    UIFont *font = [UIFont boldSystemFontOfSize:14];
    CGRect infoRect;

    infoRect.size = [info sizeWithFont:font];
    infoRect.size.width  += StatisticTrackInfoXMargin * 2.0;
    infoRect.size.height += StatisticTrackInfoYMargin * 2.0;
    infoRect.origin.x = rint (location.x - infoRect.size.width/2);
    infoRect.origin.y = StatisticTrackYPosition + rint ((StatisticTrackThickness - infoRect.size.height) / 2);

    if (infoRect.origin.x < self.graphLeftBorder - 1)
        infoRect.origin.x = self.graphLeftBorder - 1;

    if (infoRect.origin.x > self.graphRightBorder - infoRect.size.width + 1)
        infoRect.origin.x = self.graphRightBorder - infoRect.size.width + 1;

    // Info box
    path = [UIBezierPath bezierPathWithRoundedRect:infoRect
                                 byRoundingCorners:UIRectCornerAllCorners
                                       cornerRadii:CGSizeMake (6.0, 6.0)];

    // Box background
    CGContextSaveGState (cgContext);
    {
        CGContextSetShadowWithColor (cgContext, CGSizeMake (0.0, +1.0), 2.0, [[UIColor colorWithWhite:0.0 alpha:0.6] CGColor]);

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
    [info drawAtPoint:CGPointMake (infoRect.origin.x + StatisticTrackInfoXMargin, infoRect.origin.y + StatisticTrackInfoYMargin) withFont:font];
}



- (void)drawFlatLensWithBGImage:(UIImage*)background lensLocation:(CGPoint)location info:(NSString *)info
{
    UIBezierPath *path = [UIBezierPath bezierPath];


    // Graph as background
    [background drawAtPoint:CGPointZero blendMode:kCGBlendModeCopy alpha:1.0];

    // Marker line
    [[self.view tintColor] set];

    path.lineWidth = 0.5;

    [path removeAllPoints];
    [path moveToPoint:    CGPointMake (location.x + 0.25, self.graphTopBorder + 0.5)];
    [path addLineToPoint:CGPointMake (location.x + 0.25, self.graphBottomBorder)];
    [path stroke];

    // Marker knob
    path = [UIBezierPath bezierPathWithArcCenter:location radius:5.5 startAngle:0.0 endAngle:M_PI*2.0 clockwise:NO];
    [[UIColor blackColor] set];
    [path fill];

    path = [UIBezierPath bezierPathWithArcCenter:location radius:5.0 startAngle:0.0 endAngle:M_PI*2.0 clockwise:NO];
    [[self.view tintColor] set];
    [path fill];

    // Layout for info box
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Light" size:17];
    CGRect infoRect;

    infoRect.size = [info sizeWithFont:font];
    infoRect.size.width += StatisticTrackInfoXMarginFlat * 2.0;
    infoRect.size.height += StatisticTrackInfoYMarginFlat * 2.0;
    infoRect.origin.x = rint (location.x - infoRect.size.width/2);
    infoRect.origin.y = StatisticTrackYPosition + rint ((StatisticTrackThickness - infoRect.size.height) / 2);

    if (infoRect.origin.x < self.graphLeftBorder)
        infoRect.origin.x = self.graphLeftBorder;

    if (infoRect.origin.x > StatisticsViewWidth - self.graphLeftBorder - infoRect.size.width)
        infoRect.origin.x = StatisticsViewWidth - self.graphLeftBorder - infoRect.size.width;

    // Info box
    path = [UIBezierPath bezierPathWithRoundedRect:infoRect
                                 byRoundingCorners:UIRectCornerAllCorners
                                       cornerRadii:CGSizeMake (4.0, 4.0)];

    [[self.view tintColor] set];
    [path fill];

    // Info text
    [[UIColor whiteColor] set];
    [info drawAtPoint:CGPointMake (infoRect.origin.x + StatisticTrackInfoXMarginFlat, infoRect.origin.y + StatisticTrackInfoYMarginFlat) withFont:font];
}



#pragma mark -
#pragma mark Memory Management



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    self.zoomRecognizer = nil;
}


@end



#pragma mark -
#pragma mark Average Consumption/Efficiency View Controller



@implementation FuelStatisticsViewController_AvgConsumption



- (CGFloat)graphRightBorder
{
    KSFuelConsumption consumptionUnit = [[self.selectedCar valueForKey:@"fuelConsumptionUnit"] integerValue];
    
    return [super graphRightBorder] - (KSFuelConsumptionIsGP10K (consumptionUnit) ? 16.0 : 0.0);
}



- (CGFloat)graphWidth
{
    KSFuelConsumption consumptionUnit = [[self.selectedCar valueForKey:@"fuelConsumptionUnit"] integerValue];
    
    return [super graphWidth] - (KSFuelConsumptionIsGP10K (consumptionUnit) ? 16.0 : 0.0);
}


- (CGGradientRef)curveGradient
{
    return [AppDelegate greenGradient];
}


- (NSNumberFormatter*)averageFormatter:(BOOL)precise
{
    return [AppDelegate sharedFuelVolumeFormatter];
}


- (NSString *)averageFormatString:(BOOL)avgPrefix
{
    KSFuelConsumption consumptionUnit = [[self.selectedCar valueForKey:@"fuelConsumptionUnit"] integerValue];

    return [NSString stringWithFormat:@"%@%%@ %@", avgPrefix ? @"∅ " : @"", [AppDelegate consumptionUnitString:consumptionUnit]];
}


- (NSString *)noAverageString
{
    KSFuelConsumption consumptionUnit = [[self.selectedCar valueForKey:@"fuelConsumptionUnit"] integerValue];

    return [AppDelegate consumptionUnitString:consumptionUnit];
}


- (NSNumberFormatter*)axisFormatterForCar:(NSManagedObject *)car
{
    return [AppDelegate sharedFuelVolumeFormatter];
}


- (CGFloat)valueForManagedObject:(NSManagedObject *)managedObject forCar:(NSManagedObject *)car
{
    if ([[managedObject valueForKey:@"filledUp"] boolValue] == NO)
        return NAN;

    NSInteger consumptionUnit = [[car valueForKey:@"fuelConsumptionUnit"] integerValue];
    NSDecimalNumber *distance = [[managedObject valueForKey:@"distance"]   decimalNumberByAdding:[managedObject valueForKey:@"inheritedDistance"]];
    NSDecimalNumber *fuelVolume = [[managedObject valueForKey:@"fuelVolume"] decimalNumberByAdding:[managedObject valueForKey:@"inheritedFuelVolume"]];

    return [[AppDelegate consumptionForKilometers:distance Liters:fuelVolume inUnit:consumptionUnit] floatValue];
}

@end



#pragma mark -
#pragma mark Price History View Controller



@implementation FuelStatisticsViewController_PriceAmount


- (CGGradientRef)curveGradient
{
    return [AppDelegate orangeGradient];
}


- (NSNumberFormatter*)averageFormatter:(BOOL)precise
{
    return (precise) ? [AppDelegate sharedPreciseCurrencyFormatter] : [AppDelegate sharedCurrencyFormatter];
}


- (NSString *)averageFormatString:(BOOL)avgPrefix
{
    NSInteger fuelUnit = [[self.selectedCar valueForKey:@"fuelUnit"] integerValue];

    return [NSString stringWithFormat:@"%@%%@/%@", avgPrefix ? @"∅ " : @"", [AppDelegate fuelUnitString:fuelUnit]];
}


- (NSString *)noAverageString
{
    NSInteger fuelUnit = [[self.selectedCar valueForKey:@"fuelUnit"] integerValue];

    return [NSString stringWithFormat:@"%@/%@",
            [[AppDelegate sharedCurrencyFormatter] currencySymbol],
            [AppDelegate fuelUnitString:fuelUnit]];
}


- (NSNumberFormatter*)axisFormatterForCar:(NSManagedObject *)car
{
    return [AppDelegate sharedAxisCurrencyFormatter];
}


- (CGFloat)valueForManagedObject:(NSManagedObject *)managedObject forCar:(NSManagedObject *)car
{
    NSDecimalNumber *price = [managedObject valueForKey:@"price"];

    if ([price compare:[NSDecimalNumber zero]] == NSOrderedSame)
        return NAN;

    return [[AppDelegate pricePerUnit:price withUnit:[[car valueForKey:@"fuelUnit"] integerValue]] floatValue];
}

@end



#pragma mark -
#pragma mark Average Cost per Distance View Controller



@implementation FuelStatisticsViewController_PriceDistance


- (CGGradientRef)curveGradient
{
    return [AppDelegate blueGradient];
}


- (NSNumberFormatter*)averageFormatter:(BOOL)precise
{
    KSDistance distanceUnit = [[self.selectedCar valueForKey:@"odometerUnit"] integerValue];

    if (KSDistanceIsMetric (distanceUnit))
        return [AppDelegate sharedCurrencyFormatter];
    else
        return [AppDelegate sharedDistanceFormatter];
}


- (NSString *)averageFormatString:(BOOL)avgPrefix
{
    KSDistance distanceUnit = [[self.selectedCar valueForKey:@"odometerUnit"] integerValue];

    if (KSDistanceIsMetric (distanceUnit))
        return [NSString stringWithFormat:@"%@%%@/100km", avgPrefix ? @"∅ " : @""];
    else
        return [NSString stringWithFormat:@"%@%%@ mi/%@", avgPrefix ? @"∅ " : @"", [[AppDelegate sharedCurrencyFormatter] currencySymbol]];
}


- (NSString *)noAverageString
{
    KSDistance distanceUnit = [[self.selectedCar valueForKey:@"odometerUnit"] integerValue];

    return [NSString stringWithFormat:KSDistanceIsMetric (distanceUnit) ? @"%@/100km" : @"mi/%@",
            [[AppDelegate sharedCurrencyFormatter] currencySymbol]];
}


- (NSNumberFormatter*)axisFormatterForCar:(NSManagedObject *)car
{
    KSDistance distanceUnit = [[self.selectedCar valueForKey:@"odometerUnit"] integerValue];

    if (KSDistanceIsMetric (distanceUnit))
        return [AppDelegate sharedAxisCurrencyFormatter];
    else
        return [AppDelegate sharedDistanceFormatter];
}


- (CGFloat)valueForManagedObject:(NSManagedObject *)managedObject forCar:(NSManagedObject *)car
{
    if ([[managedObject valueForKey:@"filledUp"] boolValue] == NO)
        return NAN;

    NSDecimalNumberHandler *handler = [AppDelegate sharedConsumptionRoundingHandler];
    KSDistance distanceUnit = [[self.selectedCar valueForKey:@"odometerUnit"] integerValue];

    NSDecimalNumber *price = [managedObject valueForKey:@"price"];

    NSDecimalNumber *distance = [managedObject valueForKey:@"distance"];
    NSDecimalNumber *fuelVolume = [managedObject valueForKey:@"fuelVolume"];
    NSDecimalNumber *cost = [fuelVolume decimalNumberByMultiplyingBy:price];

    distance = [distance decimalNumberByAdding:[managedObject valueForKey:@"inheritedDistance"]];
    cost     = [cost     decimalNumberByAdding:[managedObject valueForKey:@"inheritedCost"]];

    if ([cost compare:[NSDecimalNumber zero]] == NSOrderedSame)
        return NAN;

    if (KSDistanceIsMetric (distanceUnit))
        return [[[cost decimalNumberByMultiplyingByPowerOf10:2]
                    decimalNumberByDividingBy:distance
                                 withBehavior:handler] floatValue];
    else
        return [[[distance decimalNumberByDividingBy:[AppDelegate kilometersPerStatuteMile]]
                    decimalNumberByDividingBy:cost
                                 withBehavior:handler] floatValue];
}

@end
