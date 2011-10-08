// FuelStatisticsPageController.h
//
// Kraftstoff


@interface FuelStatisticsPageController : UIViewController
{
    BOOL pageControlUsed;
}

- (IBAction)pageAction: (id)sender;

- (void)invalidateCaches;

@property (nonatomic, retain) NSManagedObject *selectedCar;
@property (nonatomic, retain) NSMutableArray  *viewControllers;

@property (nonatomic, retain) IBOutlet UIScrollView  *scrollView;
@property (nonatomic, retain) IBOutlet UIPageControl *pageControl;

@end
