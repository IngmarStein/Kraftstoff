// FuelStatisticsViewController.h
//
// Kraftstoff


// Coordinates for the content area
extern CGFloat const StatisticsViewHeight;

extern CGFloat const StatisticsLeftBorder;
extern CGFloat const StatisticsRightBorder;
extern CGFloat const StatisticsTopBorder;
extern CGFloat const StatisticsBottomBorder;
extern CGFloat const StatisticsWidth;
extern CGFloat const StatisticsHeight;



#pragma mark -
#pragma mark Base Class for Statistics View Controller



@interface FuelStatisticsViewController : UIViewController
{
    NSMutableDictionary *contentCache;
    NSInteger displayedNumberOfMonths;

    NSInteger invalidationCounter;
    NSInteger expectedCounter;
}

- (void)invalidateCaches;
- (void)purgeDiscardableCacheContent;

- (IBAction)checkboxButton: (UIButton*)sender;

@property (nonatomic, strong) NSManagedObject *selectedCar;
@property (nonatomic)         BOOL             active;

@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *activityView;

@property (nonatomic, strong) IBOutlet UILabel *leftLabel;
@property (nonatomic, strong) IBOutlet UILabel *rightLabel;
@property (nonatomic, strong) IBOutlet UILabel *centerLabel;

@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;

@end



