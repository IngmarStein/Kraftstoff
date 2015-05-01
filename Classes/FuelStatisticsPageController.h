// FuelStatisticsPageController.h
//
// Kraftstoff

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "FuelStatisticsScrollView.h"

@interface FuelStatisticsPageController : UIViewController

// Set by presenting view controller
@property (nonatomic, strong) NSManagedObject *selectedCar;

@property (nonatomic, weak) IBOutlet FuelStatisticsScrollView *scrollView;
@property (nonatomic, weak) IBOutlet UIPageControl *pageControl;

- (IBAction)pageAction:(id)sender;

// Throw away all cached content, e.g. on updates to CoreData
- (void)invalidateCaches;

@end
