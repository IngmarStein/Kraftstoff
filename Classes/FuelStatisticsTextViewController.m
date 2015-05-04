// FuelStatisticsTextViewController.m
//
// Kraftstoff


#import "AppDelegate.h"
#import "FuelStatisticsViewControllerPrivateMethods.h"
#import "FuelStatisticsTextViewController.h"
#import "kraftstoff-Swift.h"


static CGFloat const GridMargin =  16.0;
static CGFloat const GridTextXMargin = 10.0;
static CGFloat const GridTextYMargin = 3.0;
static CGFloat const GridTextHeight = 23.0;



#pragma mark -
#pragma mark Disposable Sampling Data Objects for ContentCache



@interface FuelStatisticsData : NSObject <DiscardableDataObject> {

@public

    Car *car;

    NSDate *firstDate;
    NSDate *lastDate;

    NSDecimalNumber *totalCost;
    NSDecimalNumber *totalFuelVolume;
    NSDecimalNumber *totalDistance;

    NSDecimalNumber *avgConsumption;
    NSDecimalNumber *bestConsumption;
    NSDecimalNumber *worstConsumption;

    NSInteger numberOfFillups;
    NSInteger numberOfFullFillups;
}

@property (nonatomic, strong) UIImage  *contentImage;

@end


@implementation FuelStatisticsData

- (void)discardContent;
{
    self.contentImage = nil;
}

@end



#pragma mark -
#pragma mark Textual Statistics View Controller

@interface FuelStatisticsTextViewController ()

@property (nonatomic) CGFloat gridLeftBorder;
@property (nonatomic) CGFloat gridRightBorder;
@property (nonatomic) CGFloat gridDesColumnWidth;

@end

@implementation FuelStatisticsTextViewController

- (void)noteStatisticsPageBecomesVisible:(BOOL)visible
{
    if (visible)
        [self.scrollView flashScrollIndicators];
}


#pragma mark -
#pragma mark Graph Computation



- (void)resampleFetchedObjects:(NSArray *)fetchedObjects
                        forCar:(Car *)car
                      andState:(FuelStatisticsData*)state
        inManagedObjectContext:(NSManagedObjectContext *)moc
{
    state->car = car;
    state->firstDate = nil;
    state->lastDate = nil;

    state->totalCost = [NSDecimalNumber zero];
    state->totalFuelVolume = [NSDecimalNumber zero];
    state->totalDistance = [NSDecimalNumber zero];

    state->avgConsumption = [NSDecimalNumber zero];
    state->bestConsumption = nil;
    state->worstConsumption = nil;

    state->numberOfFillups = 0;
    state->numberOfFullFillups = 0;

    KSFuelConsumption consumptionUnit = car.ksFuelConsumptionUnit;

    for (NSInteger i = [fetchedObjects count] - 1; i >= 0; i--) {

        FuelEvent *managedObject = (FuelEvent *)[AppDelegate existingObject:fetchedObjects[i] inManagedObjectContext:moc];

        if (!managedObject)
            continue;

        NSDecimalNumber *price = managedObject.price;
        NSDecimalNumber *distance = managedObject.distance;
        NSDecimalNumber *fuelVolume = managedObject.fuelVolume;
        NSDecimalNumber *cost = [fuelVolume decimalNumberByMultiplyingBy:price];

        // Collect dates of events
        NSDate *timestamp = managedObject.timestamp;

        if ([timestamp compare:state->firstDate] != NSOrderedDescending)
            state->firstDate = timestamp;

        if ([timestamp compare:state->lastDate] != NSOrderedAscending)
            state->lastDate = timestamp;

        // Summarize all amounts
        state->totalCost = [state->totalCost decimalNumberByAdding:cost];
        state->totalFuelVolume = [state->totalFuelVolume decimalNumberByAdding:fuelVolume];
        state->totalDistance = [state->totalDistance decimalNumberByAdding:distance];

        // Track consumption
        if (managedObject.filledUp) {

            NSDecimalNumber *inheritedDistance = managedObject.inheritedDistance;
            NSDecimalNumber *inheritedFuelVolume = managedObject.inheritedFuelVolume;

            NSDecimalNumber *consumption = [Units consumptionForKilometers:[distance decimalNumberByAdding:inheritedDistance]
                                                                          liters:[fuelVolume decimalNumberByAdding:inheritedFuelVolume]
                                                                          inUnit:consumptionUnit];

            state->avgConsumption = [state->avgConsumption decimalNumberByAdding:consumption];

            if (KSFuelConsumptionIsEfficiency (consumptionUnit)) {

                state->bestConsumption  = [consumption max:state->bestConsumption];
                state->worstConsumption = [consumption min:state->worstConsumption];

            } else {

                state->bestConsumption  = [consumption min:state->bestConsumption];
                state->worstConsumption = [consumption max:state->worstConsumption];
            }

            state->numberOfFullFillups++;
        }

        state->numberOfFillups++;
    }

    // Compute average consumption
    if ([state->totalDistance isEqualToNumber:@(0)] == NO && [state->totalFuelVolume isEqualToNumber:@(0)] == NO)
        state->avgConsumption = [Units consumptionForKilometers:state->totalDistance
                                                               liters:state->totalFuelVolume
                                                               inUnit:consumptionUnit];
}


- (id<DiscardableDataObject>)computeStatisticsForRecentMonths:(NSInteger)numberOfMonths
                                                       forCar:(Car *)car
                                                  withObjects:(NSArray *)fetchedObjects
                                       inManagedObjectContext:(NSManagedObjectContext *)moc
{
    // No cache cell exists => resample data and compute average value
    FuelStatisticsData *state = self.contentCache[@(numberOfMonths)];

    if (state == nil) {

        state = [[FuelStatisticsData alloc] init];
        [self resampleFetchedObjects:fetchedObjects forCar:car andState:state inManagedObjectContext:moc];
    }


    // Create image data from resampled data
    if (state.contentImage == nil) {

        CGFloat height = (state->numberOfFillups == 0) ? StatisticsHeight : GridTextHeight*16 + 10;

        UIGraphicsBeginImageContextWithOptions (CGSizeMake (self.view.bounds.size.width, height), NO, 0.0);
        {
            [self drawStatisticsForState:state withHeight:height];
            state.contentImage = UIGraphicsGetImageFromCurrentImageContext();
        }
        UIGraphicsEndImageContext();
    }

    return state;
}



#pragma mark -
#pragma mark Graph Display

- (void)viewDidLayoutSubviews
{
	[super viewDidLayoutSubviews];

	self.gridLeftBorder = GridMargin;
	self.gridRightBorder = self.view.bounds.size.width - GridMargin;
	self.gridDesColumnWidth = (self.view.bounds.size.width - GridMargin - GridMargin) / 2.0;

	// Initialize contents of background view
	UIGraphicsBeginImageContextWithOptions (self.view.bounds.size, YES, 0.0);
	{
		[self drawBackground];

		UIImageView *imageView = (UIImageView*)self.view;
		imageView.image = UIGraphicsGetImageFromCurrentImageContext();
	}
	UIGraphicsEndImageContext();
}

- (void)drawBackground
{
    CGContextRef cgContext = UIGraphicsGetCurrentContext();

    // Background colors
    [[UIColor colorWithWhite:0.082 alpha:1.0] setFill];
    CGContextFillRect (cgContext, self.view.bounds);

    [[UIColor blackColor] setFill];
    CGContextFillRect (cgContext, CGRectMake(0, 0, self.view.bounds.size.width, 28));
}


- (void)drawStatisticsForState:(FuelStatisticsData*)state withHeight:(CGFloat)height
{
    CGContextRef cgContext = UIGraphicsGetCurrentContext();

    [[UIColor clearColor] setFill];
    CGContextFillRect (cgContext, CGRectMake (0, 0, self.view.bounds.size.width, height));

    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Light" size:14];
    NSDictionary *labelAttributes = @{NSFontAttributeName:font, NSForegroundColorAttributeName:[UIColor colorWithWhite:0.78 alpha:1.0]};
    NSDictionary *valueAttributes = @{NSFontAttributeName:font, NSForegroundColorAttributeName:[UIColor whiteColor]};

    CGFloat x, y;

    if (state->numberOfFillups == 0) {

        CGContextSaveGState (cgContext);
        {
            [[UIColor whiteColor] setFill];

            NSString *text = NSLocalizedString(@"Not enough data to display statistics", @"");
            CGSize size = [text sizeWithAttributes:valueAttributes];

            x = floor ((self.view.bounds.size.width -  size.width)/2.0);
            y = floor ((self.view.bounds.size.height - (size.height - font.descender))/2.0);

            [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
        }
        CGContextRestoreGState (cgContext);

    } else {

        // Horizontal grid backgrounds
        UIBezierPath *path = [UIBezierPath bezierPath];

        path.lineWidth = GridTextHeight - 1;
        [[UIColor colorWithWhite:0.224 alpha:0.1] setStroke];

        CGContextSaveGState (cgContext);
        {
            [path removeAllPoints];
            [path moveToPoint:   CGPointMake (self.gridLeftBorder,  1.0)];
            [path addLineToPoint:CGPointMake (self.gridRightBorder, 1.0)];

            CGFloat lastY;

            for (NSInteger i = 1, y = 0.0; i < 16; i+=2) {

                lastY = y;
                y = rint (GridTextHeight*0.5 + GridTextHeight*i);

                CGContextTranslateCTM (cgContext, 0.0, y - lastY);
                [path stroke];
            }
        }
        CGContextRestoreGState (cgContext);

        [[UIColor colorWithWhite:0.45 alpha:0.5] setStroke];


        // Horizontal grid lines
        CGFloat   dashDotPattern [2] = { 0.5, 0.5 };
        NSInteger dashDotPatternLength = 1;
        path.lineWidth = 0.5;

        [path setLineDash:dashDotPattern count:dashDotPatternLength phase:0.0];

        CGContextSaveGState (cgContext);
        {
            [path removeAllPoints];
            [path moveToPoint:   CGPointMake (self.gridLeftBorder,  0.25)];
            [path addLineToPoint:CGPointMake (self.gridRightBorder, 0.25)];

            CGFloat lastY;

            for (NSInteger i = 1, y = 0.0; i <= 16; i++) {

                lastY = y;
                y = rint (GridTextHeight*i);

                CGContextTranslateCTM (cgContext, 0.0, y - lastY);
                [path stroke];
            }
        }
        CGContextRestoreGState (cgContext);


        // Vertical grid line
        path.lineWidth = 0.5;
        [path setLineDash:NULL count:0 phase:0.0];

        CGContextSaveGState (cgContext);
        {
            [path removeAllPoints];
            [path moveToPoint:   CGPointMake (self.gridLeftBorder + self.gridDesColumnWidth + 0.25, 0.0)];
            [path addLineToPoint:CGPointMake (self.gridLeftBorder + self.gridDesColumnWidth + 0.25, GridTextHeight*16)];
            [path stroke];
        }
        CGContextRestoreGState (cgContext);


        // Textual information
        CGContextSaveGState (cgContext);
        {
            CGContextSetShadowWithColor (cgContext, CGSizeMake (0.0, -1.0), 0.0, [[UIColor blackColor] CGColor]);

            NSString *text;
            CGSize size;

            NSNumberFormatter *nf = [Formatters sharedFuelVolumeFormatter];
            NSNumberFormatter *cf = [Formatters sharedCurrencyFormatter];
            NSNumberFormatter *pcf = [Formatters sharedPreciseCurrencyFormatter];
            NSDecimalNumber *val, *val2, *zero = [NSDecimalNumber zero];

            KSFuelConsumption consumptionUnit = state->car.ksFuelConsumptionUnit;
            NSString *consumptionUnitString = [Units consumptionUnitString:consumptionUnit];

            KSDistance odometerUnit = state->car.ksOdometerUnit;
            NSString *odometerUnitString = [Units odometerUnitString:odometerUnit];

            KSVolume fuelUnit = state->car.ksFuelUnit;
            NSString *fuelUnitString = [Units fuelUnitString:fuelUnit];

            NSInteger numberOfDays = [NSDate numberOfCalendarDaysFrom:state->firstDate to:state->lastDate];

            // number of days
            {
                y = GridTextYMargin;

                text = NSLocalizedString(@"days", @"");
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                text = [NSString stringWithFormat:@"%ld", (long)[NSDate numberOfCalendarDaysFrom:state->firstDate to:state->lastDate]];
                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // avg consumptiom
            {
                y += GridTextHeight;

                text = NSLocalizedString(KSFuelConsumptionIsEfficiency (consumptionUnit) ? @"avg_efficiency" : @"avg_consumption", @"");
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                text = [NSString stringWithFormat:@"%@ %@", [nf stringFromNumber:state->avgConsumption], consumptionUnitString];
                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // best consumption
            {
                y += GridTextHeight;

                text = NSLocalizedString(KSFuelConsumptionIsEfficiency (consumptionUnit) ? @"max_efficiency" : @"min_consumption", @"");
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                text = [NSString stringWithFormat:@"%@ %@", [nf stringFromNumber:state->bestConsumption], consumptionUnitString];
                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // worst consumption
            {
                y += GridTextHeight;

                text = NSLocalizedString(KSFuelConsumptionIsEfficiency (consumptionUnit) ? @"min_efficiency" : @"max_consumption", @"");
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                text = [NSString stringWithFormat:@"%@ %@", [nf stringFromNumber:state->worstConsumption], consumptionUnitString];
                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // total cost
            {
                y += GridTextHeight;

                text = NSLocalizedString(@"ttl_cost", @"");
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                text = [NSString stringWithFormat:@"%@", [cf stringFromNumber:state->totalCost]];
                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // total distance
            {
                y += GridTextHeight;

                text = NSLocalizedString(@"ttl_distance", @"");
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                val = [Units distanceForKilometers:state->totalDistance withUnit:odometerUnit];
                text = [NSString stringWithFormat:@"%@ %@", [[Formatters sharedDistanceFormatter] stringFromNumber:val], odometerUnitString];
                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // total volume
            {
                y += GridTextHeight;

                text = NSLocalizedString(@"ttl_volume", @"");
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                val = [Units volumeForLiters:state->totalFuelVolume withUnit:fuelUnit];
                text = [NSString stringWithFormat:@"%@ %@", [nf stringFromNumber:val], fuelUnitString];
                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // total events
            {
                y += GridTextHeight;

                text = NSLocalizedString(@"ttl_events", @"");
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                text = [NSString stringWithFormat:@"%ld", (long)state->numberOfFillups];
                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // volume per event
            {
                y += GridTextHeight;

                text = NSLocalizedString(@"volume_event", @"");
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                if (state->numberOfFillups > 0) {

                    val = [Units volumeForLiters:state->totalFuelVolume withUnit:fuelUnit];
                    val = [val decimalNumberByDividingBy:[NSDecimalNumber decimalNumberWithMantissa:state->numberOfFillups exponent:0 isNegative:NO]];
                    text = [NSString stringWithFormat:@"%@ %@", [nf stringFromNumber:val], fuelUnitString];
                }
                else
                    text = NSLocalizedString(@"-", @"");

                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // cost per distance
            {
                y += GridTextHeight;

                text = [NSString stringWithFormat:NSLocalizedString(@"cost_per_x", @""), [Units odometerUnitDescription:odometerUnit pluralization:NO]];
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                if ([zero compare:state->totalDistance] == NSOrderedAscending) {

                    val = [Units distanceForKilometers:state->totalDistance withUnit:odometerUnit];
                    val = [state->totalCost decimalNumberByDividingBy:val];
                    text = [NSString stringWithFormat:@"%@/%@", [pcf stringFromNumber:val], odometerUnitString];
                }
                else
                    text = NSLocalizedString(@"-", @"");

                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // cost per volume
            {
                y += GridTextHeight;

                text = [NSString stringWithFormat:NSLocalizedString(@"cost_per_x", @""), [Units fuelUnitDescription:fuelUnit discernGallons:YES pluralization:NO]];
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                if ([zero compare:state->totalFuelVolume] == NSOrderedAscending) {

                    val = [Units volumeForLiters:state->totalFuelVolume withUnit:fuelUnit];
                    val = [state->totalCost decimalNumberByDividingBy:val];
                    text = [NSString stringWithFormat:@"%@/%@", [pcf stringFromNumber:val], fuelUnitString];
                }
                else
                    text = NSLocalizedString(@"-", @"");

                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // cost per day
            {
                y += GridTextHeight;

                text = [NSString stringWithFormat:NSLocalizedString(@"cost_per_x", @""), NSLocalizedString(@"day", @"")];
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                if (numberOfDays > 0) {

                    val = [NSDecimalNumber decimalNumberWithMantissa:numberOfDays exponent:0 isNegative:NO];
                    val = [state->totalCost decimalNumberByDividingBy:val];
                    text = [NSString stringWithFormat:@"%@", [cf stringFromNumber:val]];
                }
                else
                    text = NSLocalizedString(@"-", @"");

                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // cost per event
            {
                y += GridTextHeight;

                text = [NSString stringWithFormat:NSLocalizedString(@"cost_per_x", @""), NSLocalizedString(@"event", @"")];
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                if (state->numberOfFillups > 0) {

                    val  = [NSDecimalNumber decimalNumberWithMantissa:state->numberOfFillups exponent:0 isNegative:NO];
                    val  = [state->totalCost decimalNumberByDividingBy:val];
                    text = [NSString stringWithFormat:@"%@", [cf stringFromNumber:val]];
                }
                else
                    text = NSLocalizedString(@"-", @"");

                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // distance per event
            {
                y += GridTextHeight;

                text = [NSString stringWithFormat:NSLocalizedString(@"x_per_y", @""), [Units odometerUnitDescription:odometerUnit pluralization:YES], NSLocalizedString(@"event", @"")];
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                if (state->numberOfFillups > 0) {

                    val = [Units distanceForKilometers:state->totalDistance withUnit:odometerUnit];
                    val2 = [NSDecimalNumber decimalNumberWithMantissa:state->numberOfFillups exponent:0 isNegative:NO];
                    text = [NSString stringWithFormat:@"%@ %@", [nf stringFromNumber:[val decimalNumberByDividingBy:val2]], odometerUnitString];
                }
                else
                    text = NSLocalizedString(@"-", @"");

                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // distance per day
            {
                y += GridTextHeight;

                text = [NSString stringWithFormat:NSLocalizedString(@"x_per_y", @""), [Units odometerUnitDescription:odometerUnit pluralization:YES], NSLocalizedString(@"day", @"")];
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                if (numberOfDays > 0) {

                    val = [Units distanceForKilometers:state->totalDistance withUnit:odometerUnit];
                    val2 = [NSDecimalNumber decimalNumberWithMantissa:numberOfDays exponent:0 isNegative:NO];
                    text = [NSString stringWithFormat:@"%@ %@", [nf stringFromNumber:[val decimalNumberByDividingBy:val2]], odometerUnitString];
                }
                else
                    text = NSLocalizedString(@"-", @"");

                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }

            // distance per money
            {
                y += GridTextHeight;

                text = [NSString stringWithFormat:NSLocalizedString(@"x_per_y", @""), [Units odometerUnitDescription:odometerUnit pluralization:YES], [cf currencySymbol]];
                size = [text sizeWithAttributes:labelAttributes];
                x = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:labelAttributes];

                if ([zero compare:state->totalCost] == NSOrderedAscending) {

                    val = [Units distanceForKilometers:state->totalDistance withUnit:odometerUnit];
                    val = [val decimalNumberByDividingBy:state->totalCost];
                    text = [NSString stringWithFormat:@"%@ %@", [nf stringFromNumber:val], odometerUnitString];
                }
                else
                    text = NSLocalizedString(@"-", @"");

                x = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin;
                [text drawAtPoint:CGPointMake (x, y) withAttributes:valueAttributes];
            }
        }
        CGContextRestoreGState (cgContext);
    }
}


- (BOOL)displayCachedStatisticsForRecentMonths:(NSInteger)numberOfMonths
{
    FuelStatisticsData *cell = self.contentCache[@(numberOfMonths)];

    // Cache Hit => Update image contents
    if (cell.contentImage != nil) {

        [self.activityView stopAnimating];

        CGRect imageFrame = CGRectZero;
        imageFrame.size = cell.contentImage.size;

        UIImageView *imageView = (UIImageView*)[self.scrollView viewWithTag:1];

        if (imageView == nil) {

            imageView = [[UIImageView alloc] initWithFrame:imageFrame];
            imageView.tag = 1;
            imageView.opaque = NO;
            imageView.backgroundColor = [UIColor clearColor];

            self.scrollView.hidden = NO;
            [self.scrollView addSubview:imageView];
        }

        if (CGRectIsEmpty (imageView.frame)) {

            imageView.image = cell.contentImage;
            imageView.frame = imageFrame;

        } else {

            [UIView transitionWithView:imageView
                              duration:StatisticTransitionDuration
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                                imageView.image = cell.contentImage;
                                imageView.frame = imageFrame; }
                            completion:nil];
        }

        self.scrollView.contentSize = imageView.image.size;

        [UIView animateWithDuration:StatisticTransitionDuration
                         animations:^{ self.scrollView.alpha = 1.0; }
                         completion:^(BOOL finished){

                             if (finished)
                                 [self.scrollView flashScrollIndicators];
                         }];

        return YES;

    // Cache Miss => draw preliminary contents
    } else {

        [UIView animateWithDuration:StatisticTransitionDuration
                         animations:^{ self.scrollView.alpha = 0.0; }
                         completion:^(BOOL finished){

                             if (finished ) {

                                [self.activityView startAnimating];

                                 UIImageView *imageView = (UIImageView*)[self.scrollView viewWithTag:1];

                                 if (imageView) {

                                     imageView.image = nil;
                                     imageView.frame = CGRectZero;
                                     self.scrollView.contentSize = CGSizeZero;
                                 }
                             }
                         }];

        return NO;
    }
}

@end
