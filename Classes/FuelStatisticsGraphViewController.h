// FuelStatisticsGraphViewController.h
//
// Kraftstoff


#import "FuelStatisticsViewControllerPrivateMethods.h"


#pragma mark -
#pragma mark Base Class for Graphical Statistics View Controller


@interface FuelStatisticsGraphViewController : FuelStatisticsViewController

@property (nonatomic) BOOL zooming;
@property (nonatomic, strong) UILongPressGestureRecognizer *zoomRecognizer;

// Location and dimension of actual graph, customizable by subclasses
@property (readonly, nonatomic) CGFloat graphRightBorder;
@property (readonly, nonatomic) CGFloat graphTopBorder;
@property (readonly, nonatomic) CGFloat graphBottomBorder;
@property (readonly, nonatomic) CGFloat graphWidth;
@property (readonly, nonatomic) CGFloat graphHeight;

@end


#pragma mark -
#pragma mark Subclasses for Different Statistic Graphs


@interface FuelStatisticsViewController_AvgConsumption : FuelStatisticsGraphViewController
@end

@interface FuelStatisticsViewController_PriceAmount : FuelStatisticsGraphViewController
@end

@interface FuelStatisticsViewController_PriceDistance : FuelStatisticsGraphViewController
@end
