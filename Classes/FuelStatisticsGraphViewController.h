// FuelStatisticsGraphViewController.h
//
// Kraftstoff


#import "FuelStatisticsViewControllerPrivateMethods.h"


@protocol FuelStatisticsViewControllerDelegate

@property (NS_NONATOMIC_IOSONLY, readonly) CGGradientRef curveGradient;

- (NSNumberFormatter*)averageFormatter:(BOOL)precise forCar:(Car *)car;
- (NSString *)averageFormatString:(BOOL)avgPrefix forCar:(Car *)car;
- (NSString *)noAverageStringForCar:(Car *)car;

- (NSNumberFormatter*)axisFormatterForCar:(Car *)car;
- (CGFloat)valueForManagedObject:(NSManagedObject *)managedObject forCar:(Car *)car;

@optional
- (CGFloat)graphRightBorder:(CGFloat)rightBorder forCar:(Car *)car;
- (CGFloat)graphWidth:(CGFloat)graphWidth forCar:(Car *)car;

@end

#pragma mark -
#pragma mark Graphical Statistics View Controller


@interface FuelStatisticsGraphViewController : FuelStatisticsViewController

@property (nonatomic) BOOL zooming;
@property (nonatomic, strong) UILongPressGestureRecognizer *zoomRecognizer;
@property (nonatomic, strong) NSObject<FuelStatisticsViewControllerDelegate> *delegate;

// Location and dimension of actual graph, customizable by subclasses
@property (readonly, nonatomic) CGFloat graphRightBorder;
@property (readonly, nonatomic) CGFloat graphTopBorder;
@property (readonly, nonatomic) CGFloat graphBottomBorder;
@property (readonly, nonatomic) CGFloat graphWidth;
@property (readonly, nonatomic) CGFloat graphHeight;

@end

#pragma mark -
#pragma mark Delegates for Different Statistic Graphs


@interface FuelStatisticsViewControllerDelegateAvgConsumption : NSObject<FuelStatisticsViewControllerDelegate>
@end

@interface FuelStatisticsViewControllerDelegatePriceAmount : NSObject<FuelStatisticsViewControllerDelegate>
@end

@interface FuelStatisticsViewControllerDelegatePriceDistance : NSObject<FuelStatisticsViewControllerDelegate>
@end
