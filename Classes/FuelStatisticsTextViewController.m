// FuelStatisticsTextViewController.m
//
// Kraftstoff


#import "AppDelegate.h"
#import "FuelStatisticsViewControllerPrivateMethods.h"
#import "FuelStatisticsTextViewController.h"


static CGFloat const GridLeftBorder     =  16.0;
static CGFloat const GridRightBorder    = 464.0;
static CGFloat const GridTopBorder      =  68.0;
static CGFloat const GridBottomBorder   = 253.0;
static CGFloat const GridWidth          = 448.0;
static CGFloat const GridHeight         = 185.0;

static CGFloat const GridDesColumnWidth = (240.0 - GridLeftBorder);
static CGFloat const GridTextXMargin    =  10.0;
static CGFloat const GridTextYMargin    =   3.0;
static CGFloat const GridTextHeight     =  23.0;



#pragma mark -
#pragma mark Disposable Content Objects for ContentCache



@interface FuelStatisticsData : NSObject
{
@public

    NSManagedObject *car;

    NSDate          *firstDate;
    NSDate          *lastDate;

    NSDecimalNumber *totalCost;
    NSDecimalNumber *totalFuelVolume;
    NSDecimalNumber *totalDistance;

    NSDecimalNumber *avgConsumption;
    NSDecimalNumber *bestConsumption;
    NSDecimalNumber *worstConsumption;

    NSInteger numberOfFillups;
    NSInteger numberOfFullFillups;
}

@property (nonatomic, strong) UIImage  *backgroundImage;
@property (nonatomic, strong) UIImage  *contentImage;

@end


@implementation FuelStatisticsData

@synthesize backgroundImage;
@synthesize contentImage;


- (id)init
{
    if ((self = [super init]))
    {
    }

    return self;
}

@end



#pragma mark -
#pragma mark Disposable Content Objects Entry for NSCache



@interface FuelStatisticsTextViewController (private)

// Methods for Graph Computation
- (void)resampleFetchedObjects: (NSArray*)fetchedObjects forCar: (NSManagedObject*)car andState: (FuelStatisticsData*)state;

- (void)drawBackground;
- (void)drawStatisticsForState: (FuelStatisticsData*)state withHeight: (CGFloat)height;

@end



@implementation FuelStatisticsTextViewController


- (void)purgeDiscardableCacheContent
{
    [contentCache enumerateKeysAndObjectsUsingBlock: ^(id key, id data, BOOL *stop)
        {
            if ([key integerValue] != displayedNumberOfMonths)
            {
                [(FuelStatisticsData*)data setBackgroundImage: nil];
                [(FuelStatisticsData*)data setContentImage: nil];
            }
        }];
}



#pragma mark -
#pragma mark Graph Computation



- (void)resampleFetchedObjects: (NSArray*)fetchedObjects
                        forCar: (NSManagedObject*)car
                      andState: (FuelStatisticsData*)state;
{
    state->car                 = car;
    state->firstDate           = nil;
    state->lastDate            = nil;

    state->totalCost           = [NSDecimalNumber zero];
    state->totalFuelVolume     = [NSDecimalNumber zero];
    state->totalDistance       = [NSDecimalNumber zero];

    state->avgConsumption      = [NSDecimalNumber zero];
    state->bestConsumption     = nil;
    state->worstConsumption    = nil;

    state->numberOfFillups     = 0;
    state->numberOfFullFillups = 0;

    NSInteger consumptionUnit = [[car valueForKey: @"fuelConsumptionUnit"] integerValue];

    for (NSInteger i = [fetchedObjects count] - 1; i >= 0; i--)
    {
        @try
        {
            NSManagedObject *managedObject = [fetchedObjects objectAtIndex: i];

            NSDecimalNumber *price      = [managedObject valueForKey: @"price"];
            NSDecimalNumber *distance   = [managedObject valueForKey: @"distance"];
            NSDecimalNumber *fuelVolume = [managedObject valueForKey: @"fuelVolume"];
            NSDecimalNumber *cost       = [fuelVolume decimalNumberByMultiplyingBy: price];

            // Collect dates of events
            NSDate *timestamp = [managedObject valueForKey: @"timestamp"];

            if ([timestamp compare: state->firstDate] != NSOrderedDescending)
                state->firstDate = timestamp;

            if ([timestamp compare: state->lastDate] != NSOrderedAscending)
                state->lastDate  = timestamp;
            
            // Summarize all amounts
            state->totalCost       = [state->totalCost decimalNumberByAdding: cost];
            state->totalFuelVolume = [state->totalFuelVolume decimalNumberByAdding: fuelVolume];
            state->totalDistance   = [state->totalDistance decimalNumberByAdding: distance];

            // Track consumption
            if ([[managedObject valueForKey: @"filledUp"] boolValue])
            {
                NSDecimalNumber *inheritedDistance   = [managedObject valueForKey: @"inheritedDistance"];
                NSDecimalNumber *inheritedFuelVolume = [managedObject valueForKey: @"inheritedFuelVolume"];

                NSDecimalNumber *consumption = [AppDelegate consumptionForKilometers: [distance   decimalNumberByAdding: inheritedDistance]
                                                                              Liters: [fuelVolume decimalNumberByAdding: inheritedFuelVolume]
                                                                              inUnit: consumptionUnit];

                state->avgConsumption = [state->avgConsumption decimalNumberByAdding: consumption];

                if (KSFuelConsumptionIsEfficiency (consumptionUnit))
                {
                    state->bestConsumption  = [consumption max: state->bestConsumption];
                    state->worstConsumption = [consumption min: state->worstConsumption];
                }
                else
                {
                    state->bestConsumption  = [consumption min: state->bestConsumption];
                    state->worstConsumption = [consumption max: state->worstConsumption];
                }

                state->numberOfFullFillups++;
            }

            state->numberOfFillups++;
        }
        @catch (NSException *e)
        {
            continue;
        }
    }

    // compute average consumption    
    state->avgConsumption = [AppDelegate consumptionForKilometers: state->totalDistance
                                                           Liters: state->totalFuelVolume
                                                           inUnit: consumptionUnit];
}


- (void)drawBackground
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
}


- (void)drawStatisticsForState: (FuelStatisticsData*)state withHeight: (CGFloat)height
{
    CGContextRef cgContext = UIGraphicsGetCurrentContext ();

    [[UIColor clearColor] setFill];
    CGContextFillRect (cgContext, CGRectMake (0, 0, 480, height));

    UIFont *font = [UIFont boldSystemFontOfSize: 14];
    CGFloat x, y;


    if (state->numberOfFillups == 0)
    {
        CGContextSaveGState (cgContext);
        {
            CGContextSetShadowWithColor (cgContext, CGSizeMake (0.0, -1.0), 0.0, [[UIColor blackColor] CGColor]);
            [[UIColor whiteColor] setFill];

            NSString *text = _I18N (@"Not enough data to display statistics");
            CGSize size    = [text sizeWithFont: font];

            x = floor ((480.0 -  size.width)/2.0);
            y = floor ((320.0 - (size.height - font.descender))/2.0 - 18.0 - 65.0);

            [text drawAtPoint: CGPointMake (x, y)   withFont: font];
        }
        CGContextRestoreGState (cgContext);
    }
    else
    {
        // Horizontal grid backgrounds
        UIBezierPath *path = [UIBezierPath bezierPath];
        
        path.lineWidth = GridTextHeight - 1;
        
        [[UIColor colorWithWhite: 0.45 alpha: 0.1] setStroke];
        
        CGContextSaveGState (cgContext);
        {
            [path removeAllPoints];
            [path moveToPoint:    CGPointMake (GridLeftBorder,  1.0)];
            [path addLineToPoint: CGPointMake (GridRightBorder, 1.0)];
            
            CGFloat lastY;
            
            for (NSInteger i = 1, y = 0.0; i < 16; i+=2)
            {
                lastY = y;
                y     = rint (GridTextHeight*0.5 + GridTextHeight*i);
                
                CGContextTranslateCTM (cgContext, 0.0, y - lastY);
                [path stroke];
            }                
        }
        CGContextRestoreGState (cgContext);

        [[UIColor colorWithWhite: 0.45 alpha: 0.5] setStroke];


        // Horizontal grid lines
        CGFloat   dashDotPattern [2]   = { 1.0, 1.0 };
        NSInteger dashDotPatternLength = 2;
        
        path.lineWidth = 1;
        [path setLineDash: dashDotPattern count: dashDotPatternLength phase: 0.0];
        
        CGContextSaveGState (cgContext);
        {
            [path removeAllPoints];
            [path moveToPoint:    CGPointMake (GridLeftBorder,  0.5)];
            [path addLineToPoint: CGPointMake (GridRightBorder, 0.5)];
            
            CGFloat lastY;
            
            for (NSInteger i = 1, y = 0.0; i <= 16; i++)
            {
                lastY = y;
                y     = rint (GridTextHeight*i);
                
                CGContextTranslateCTM (cgContext, 0.0, y - lastY);
                [path stroke];
            }                
        }
        CGContextRestoreGState (cgContext);
        
        
        // Vertical grid line
        path.lineWidth = 2;
        [path setLineDash: NULL count: 0 phase: 0.0];
        
        CGContextSaveGState (cgContext);
        {
            [path removeAllPoints];
            [path moveToPoint:    CGPointMake (GridLeftBorder + GridDesColumnWidth, 0.0)];
            [path addLineToPoint: CGPointMake (GridLeftBorder + GridDesColumnWidth, GridTextHeight*16 + 1.0)];
            [path stroke];
        }
        CGContextRestoreGState (cgContext);


        // Textual information
        CGContextSaveGState (cgContext);
        {
            CGContextSetShadowWithColor (cgContext, CGSizeMake (0.0, -1.0), 0.0, [[UIColor blackColor] CGColor]);
            [[UIColor whiteColor] setFill];

            NSString *text;
            CGSize size;

            NSNumberFormatter *nf  = [AppDelegate sharedFuelVolumeFormatter];
            NSNumberFormatter *cf  = [AppDelegate sharedCurrencyFormatter];
            NSNumberFormatter *pcf = [AppDelegate sharedPreciseCurrencyFormatter];            
            NSDecimalNumber *val, *val2, *zero = [NSDecimalNumber zero];

            KSFuelConsumption consumptionUnit = [[state->car valueForKey: @"fuelConsumptionUnit"] integerValue];
            NSString *consumptionUnitString   = [AppDelegate consumptionUnitString: consumptionUnit];

            KSDistance odometerUnit      = [[state->car valueForKey: @"odometerUnit"] integerValue];
            NSString *odometerUnitString = [AppDelegate odometerUnitString: odometerUnit];

            KSVolume fuelUnit        = [[state->car valueForKey: @"fuelUnit"] integerValue];
            NSString *fuelUnitString = [AppDelegate fuelUnitString: fuelUnit];

            NSInteger numberOfDays = [AppDelegate numberOfCalendarDaysFrom: state->firstDate to: state->lastDate];


            // number of days
            {
                y    = GridTextYMargin;

                text = _I18N (@"days");
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];

                text = [NSString stringWithFormat: @"%d", [AppDelegate numberOfCalendarDaysFrom: state->firstDate to: state->lastDate]];
                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }
            
            // avg consumptiom
            {
                y   += GridTextHeight;
                
                text = _I18N (KSFuelConsumptionIsEfficiency (consumptionUnit) ? @"avg_efficiency" : @"avg_consumption");
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
                
                text = [NSString stringWithFormat: @"%@ %@", [nf stringFromNumber: state->avgConsumption], consumptionUnitString];
                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }

            // best consumption
            {
                y   += GridTextHeight;

                text = _I18N (KSFuelConsumptionIsEfficiency (consumptionUnit) ? @"max_efficiency" : @"min_consumption");
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];

                text = [NSString stringWithFormat: @"%@ %@", [nf stringFromNumber: state->bestConsumption], consumptionUnitString];
                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }

            // worst consumption
            {
                y   += GridTextHeight;

                text = _I18N (KSFuelConsumptionIsEfficiency (consumptionUnit) ? @"min_efficiency" : @"max_consumption");
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];

                text = [NSString stringWithFormat: @"%@ %@", [nf stringFromNumber: state->worstConsumption], consumptionUnitString];
                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }

            // total cost
            {
                y   += GridTextHeight;

                text = _I18N (@"ttl_cost");
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];

                text = [NSString stringWithFormat: @"%@", [cf stringFromNumber: state->totalCost]];
                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }

            // total distance
            {
                y   += GridTextHeight;

                text = _I18N (@"ttl_distance");
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];

                val  = [AppDelegate distanceForKilometers: state->totalDistance withUnit: odometerUnit];
                text = [NSString stringWithFormat: @"%@ %@", [[AppDelegate sharedDistanceFormatter] stringFromNumber: val], odometerUnitString];
                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }

            // total volume
            {
                y   += GridTextHeight;

                text = _I18N (@"ttl_volume");
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];

                val  = [AppDelegate volumeForLiters: state->totalFuelVolume withUnit:fuelUnit];
                text = [NSString stringWithFormat: @"%@ %@", [nf stringFromNumber: val], fuelUnitString];
                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }

            // total events
            {
                y   += GridTextHeight;

                text = _I18N (@"ttl_events");
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];

                text = [NSString stringWithFormat: @"%d", state->numberOfFillups];
                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }
            
            // volume per event
            {
                y   += GridTextHeight;
                
                text = _I18N (@"volume_event");
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
                
                if (state->numberOfFillups > 0)
                {
                    val  = [AppDelegate volumeForLiters: state->totalFuelVolume withUnit: fuelUnit];
                    val  = [val decimalNumberByDividingBy: [NSDecimalNumber decimalNumberWithMantissa: state->numberOfFillups exponent: 0 isNegative: NO]];
                    text = [NSString stringWithFormat: @"%@ %@", [nf stringFromNumber: val], fuelUnitString];
                }
                else
                    text = _I18N (@"-");

                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }

            // cost per distance
            {
                y   += GridTextHeight;

                text = [NSString stringWithFormat: _I18N (@"cost_per_x"), [AppDelegate odometerUnitDescription: odometerUnit  pluralization: NO]];
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];

                if ([zero compare: state->totalDistance] == NSOrderedAscending)
                {
                    val  = [AppDelegate distanceForKilometers: state->totalDistance withUnit: odometerUnit];
                    val  = [state->totalCost decimalNumberByDividingBy: val];
                    text = [NSString stringWithFormat: @"%@/%@", [pcf stringFromNumber: val], odometerUnitString];
                }
                else
                    text = _I18N (@"-");

                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }

            // cost per volume
            {
                y   += GridTextHeight;

                text = [NSString stringWithFormat: _I18N (@"cost_per_x"),
                            [AppDelegate fuelUnitDescription: fuelUnit
                                              discernGallons: YES
                                               pluralization: NO]];

                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];

                if ([zero compare: state->totalFuelVolume] == NSOrderedAscending)
                {
                    val  = [AppDelegate volumeForLiters: state->totalFuelVolume withUnit: fuelUnit];
                    val  = [state->totalCost decimalNumberByDividingBy: val];
                    text = [NSString stringWithFormat: @"%@/%@", [pcf stringFromNumber: val], fuelUnitString];
                }
                else
                    text = _I18N (@"-");

                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }

            // cost per day
            {
                y   += GridTextHeight;

                text = [NSString stringWithFormat: _I18N (@"cost_per_x"), _I18N (@"day")];
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];

                if (numberOfDays > 0)
                {
                    val  = [NSDecimalNumber decimalNumberWithMantissa: numberOfDays exponent: 0 isNegative: NO];
                    val  = [state->totalCost decimalNumberByDividingBy: val];
                    text = [NSString stringWithFormat: @"%@", [cf stringFromNumber: val]];
                }
                else
                    text = _I18N (@"-");

                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }

            // cost per event
            {
                y   += GridTextHeight;

                text = [NSString stringWithFormat: _I18N (@"cost_per_x"), _I18N (@"event")];
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];

                if (state->numberOfFillups > 0)
                {
                    val  = [NSDecimalNumber decimalNumberWithMantissa: state->numberOfFillups exponent: 0 isNegative: NO];
                    val  = [state->totalCost decimalNumberByDividingBy: val];
                    text = [NSString stringWithFormat: @"%@", [cf stringFromNumber: val]];
                }
                else
                    text = _I18N (@"-");

                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }

            // distance per event
            {
                y   += GridTextHeight;

                text = [NSString stringWithFormat: _I18N (@"x_per_y"), [AppDelegate odometerUnitDescription: odometerUnit pluralization: YES], _I18N (@"event")];
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
                
                if (state->numberOfFillups > 0)
                {
                    val  = [AppDelegate distanceForKilometers: state->totalDistance withUnit: odometerUnit];
                    val2 = [NSDecimalNumber decimalNumberWithMantissa: state->numberOfFillups exponent: 0 isNegative: NO];
                    val  = [val decimalNumberByDividingBy: val2];
                    text = [NSString stringWithFormat: @"%@ %@", [nf stringFromNumber: val], odometerUnitString];
                }
                else
                    text = _I18N (@"-");

                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }

            // distance per day
            {
                y   += GridTextHeight;

                text = [NSString stringWithFormat: _I18N (@"x_per_y"), [AppDelegate odometerUnitDescription: odometerUnit pluralization: YES], _I18N (@"day")];
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
                
                if (numberOfDays > 0)
                {
                    val  = [AppDelegate distanceForKilometers: state->totalDistance withUnit: odometerUnit];
                    val2 = [NSDecimalNumber decimalNumberWithMantissa: numberOfDays exponent: 0 isNegative: NO];
                    val  = [val decimalNumberByDividingBy: val2];
                    text = [NSString stringWithFormat: @"%@ %@", [nf stringFromNumber: val], odometerUnitString];
                }
                else
                    text = _I18N (@"-");

                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }

            // distance per money
            {
                y   += GridTextHeight;

                text = [NSString stringWithFormat: _I18N (@"x_per_y"), [AppDelegate odometerUnitDescription: odometerUnit pluralization: YES], [cf currencySymbol]];
                size = [text sizeWithFont: font];
                x    = GridLeftBorder + GridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
                
                if ([zero compare: state->totalCost] == NSOrderedAscending)
                {
                    val  = [AppDelegate distanceForKilometers: state->totalDistance withUnit: odometerUnit];
                    val  = [val decimalNumberByDividingBy: state->totalCost];
                    text = [NSString stringWithFormat: @"%@ %@", [nf stringFromNumber: val], odometerUnitString];
                }
                else
                    text = _I18N (@"-");

                x = GridLeftBorder + GridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint: CGPointMake (x, y) withFont: font];
            }
        }
        CGContextRestoreGState (cgContext);
    }
}



#pragma mark -
#pragma mark Graph Display



- (BOOL)displayCachedStatisticsForRecentMonths: (NSInteger)numberOfMonths
{
    // Cache lookup
    FuelStatisticsData *cell = [contentCache objectForKey: [NSNumber numberWithInteger: numberOfMonths]];
    UIImageView *imageView;
        
    // Cache Hit => Update image contents
    if (cell.backgroundImage != nil && cell.contentImage != nil)
    {
        [self.activityView stopAnimating];

        imageView         = (UIImageView*)self.view;
        imageView.image   = cell.backgroundImage;

        CGRect imageFrame = CGRectZero;
        imageFrame.size   = cell.contentImage.size;

        imageView         = (UIImageView*)[self.scrollView viewWithTag: 1];

        if (imageView == nil)
        {
            imageView                   = [[UIImageView alloc] initWithFrame: imageFrame];            
            imageView.tag               = 1;
            imageView.opaque            = NO;
            imageView.backgroundColor   = [UIColor clearColor];
            
            self.scrollView.hidden      = NO;
            [self.scrollView addSubview: imageView];
        }

        imageView.image = cell.contentImage;
        imageView.frame = imageFrame;
        
        self.scrollView.contentSize = imageView.image.size;

        [self.scrollView flashScrollIndicators];
        return YES;
    }

    // Cache Miss => draw prelimary contents
    else
    {
        [self.activityView startAnimating];

        UIGraphicsBeginImageContextWithOptions (CGSizeMake (480.0, StatisticsViewHeight), YES, 0.0);
        {
            [self drawBackground];

            imageView       = (UIImageView*)self.view;
            imageView.image = UIGraphicsGetImageFromCurrentImageContext ();

            imageView         = (UIImageView*)[self.scrollView viewWithTag: 1];
            
            if (imageView )
            {
                imageView.image = nil;
                imageView.frame = CGRectZero;
                self.scrollView.contentSize = CGSizeZero;
            }
        }
        UIGraphicsEndImageContext ();

        return NO;
    }
}


- (void)computeAndRedisplayStatisticsForRecentMonths: (NSInteger)numberOfMonths
                                              forCar: (NSManagedObject*)car
                                           inContext: (NSManagedObjectContext*)context
{
    FuelStatisticsData *state = [contentCache objectForKey: [NSNumber numberWithInteger: numberOfMonths]];
    BOOL stateAllocated = NO;

    // No cache cell exists => resample data and compute average value
    if (state == nil)
    {
        state = [[FuelStatisticsData alloc] init];
        stateAllocated = YES;

        [self resampleFetchedObjects: [self fetchObjectsForRecentMonths: numberOfMonths
                                                                 forCar: car
                                                              inContext: context]
                              forCar: car
                            andState: state];
    }


    // Create image data from resampled data
    if (state.backgroundImage == nil)
    {
        UIGraphicsBeginImageContextWithOptions (CGSizeMake (480.0, StatisticsViewHeight), YES, 0.0);
        {
            [self drawBackground];
            state.backgroundImage = UIGraphicsGetImageFromCurrentImageContext ();
        }
        UIGraphicsEndImageContext ();
    }

    if (state.contentImage == nil)
    {
        CGFloat height = (state->numberOfFillups == 0) ? StatisticsHeight : GridTextHeight*16 + 10;

        UIGraphicsBeginImageContextWithOptions (CGSizeMake (480.0, height), NO, 0.0);
        {
            [self drawStatisticsForState: state withHeight: height];
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
#pragma mark UIView Events



- (void)setActive:(BOOL)active
{
    [super setActive: active];
    
    if (active)
        [self.scrollView flashScrollIndicators];
}

@end
