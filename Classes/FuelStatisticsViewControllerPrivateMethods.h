// FuelStatisticsViewControllerPrivateMethods.h
//
// Kraftstoff


#import "FuelStatisticsViewController.h"


// Protocol for objects containing computed statistics data
@protocol DiscardableDataObject <NSObject>

// Throw away easily recomputable content
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
                                                  withObjects:(NSArray *)fetchedObjects
                                       inManagedObjectContext:(NSManagedObjectContext *)moc;

@end
