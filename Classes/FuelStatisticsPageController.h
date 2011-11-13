// FuelStatisticsPageController.h
//
// Kraftstoff


@interface FuelStatisticsPageController : UIViewController
{
    BOOL pageControlUsed;
}

- (IBAction)pageAction: (id)sender;

- (void)invalidateCaches;

@property (nonatomic, strong) NSManagedObject *selectedCar;
@property (nonatomic, strong) NSMutableArray  *viewControllers;

@property (nonatomic, strong) IBOutlet UIScrollView  *scrollView;
@property (nonatomic, strong) IBOutlet UIPageControl *pageControl;

@end
