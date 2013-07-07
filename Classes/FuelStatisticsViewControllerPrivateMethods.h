// FuelStatisticsViewControllerPrivateMethods.h
//
// Kraftstoff


#import "FuelStatisticsViewController.h"


@protocol DiscardableDataObject <NSObject>

- (void)discardContent;

@end


@interface FuelStatisticsViewController (Kraftstoff)

// Update contentView with new statistics
- (void)displayStatisticsForRecentMonths:(NSInteger)numberOfMonths;

// Update contentView with cached statistics if available
- (BOOL)displayCachedStatisticsForRecentMonths:(NSInteger)numberOfMonths;

// Computes the statistics and returns a state object
- (id<DiscardableDataObject>)computeStatisticsForRecentMonths:(NSInteger)numberOfMonths
                                                       forCar:(NSManagedObject *)car
                                                  withObjects:(NSArray *)fetchedObjects;

@end
