// FuelStatisticsViewControllerPrivateMethods.h
//
// Kraftstoff


#import "FuelStatisticsViewController.h"


@interface FuelStatisticsViewController (private)

// Fetch the events to be displayed
- (NSArray*)fetchObjectsForRecentMonths: (NSInteger)numberOfMonths
                                 forCar: (NSManagedObject*)car
                              inContext: (NSManagedObjectContext*)context;

// Update contentView with new statistics
- (void)displayStatisticsForRecentMonths: (NSInteger)numberOfMonths;

// Helpers used by 'displayStatisticsForRecentMonths'
- (BOOL)displayCachedStatisticsForRecentMonths: (NSInteger)numberOfMonths;
- (void)computeAndRedisplayStatisticsForRecentMonths: (NSInteger)numberOfMonths
                                              forCar: (NSManagedObject*)car
                                           inContext: (NSManagedObjectContext*)context;

@end
