// FuelStatisticsGraphViewController.h
//
// Kraftstoff


#import "FuelStatisticsViewControllerPrivateMethods.h"


#pragma mark -
#pragma mark Base Class for Graphical Statistics View Controller


@interface FuelStatisticsGraphViewController : FuelStatisticsViewController
{
    NSInteger zoomIndex;
}

@property (nonatomic)         BOOL zooming;
@property (nonatomic, strong) UILongPressGestureRecognizer *zoomRecognizer;

@end


#pragma mark -
#pragma mark Subclasses for different Statistic Graphs


@interface FuelStatisticsViewController_AvgConsumption : FuelStatisticsGraphViewController
{
}
@end

@interface FuelStatisticsViewController_PriceAmount : FuelStatisticsGraphViewController
{
}
@end

@interface FuelStatisticsViewController_PriceDistance : FuelStatisticsGraphViewController
{
}
@end
