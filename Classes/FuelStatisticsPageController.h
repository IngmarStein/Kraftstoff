// FuelStatisticsPageController.h
//
// Kraftstoff

#import "FuelStatisticsScrollView.h"

@interface FuelStatisticsPageController : UIViewController
{
    BOOL pageControlUsed;
}

// Throw away all cached content, e.g. on updates to CoreData
- (void)invalidateCaches;

- (IBAction)pageAction: (id)sender;

@property (nonatomic, weak) IBOutlet FuelStatisticsScrollView *scrollView;
@property (nonatomic, weak) IBOutlet UIPageControl *pageControl;

@property (nonatomic, strong) NSManagedObject *selectedCar;

@end
