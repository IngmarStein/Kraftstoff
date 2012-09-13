// FuelStatisticsViewController.h
//
// Kraftstoff


#pragma mark -
#pragma mark Base Class for Statistics View Controller


extern CGFloat       StatisticsViewWidth;
extern CGFloat const StatisticsViewHeight;
extern CGFloat const StatisticsHeight;


@interface FuelStatisticsViewController : UIViewController
{
    NSMutableDictionary *contentCache;

    NSInteger displayedNumberOfMonths;
    NSInteger invalidationCounter;
    NSInteger expectedCounter;
}

// Throw away all cached content, e.g. on new/updated events
- (void)invalidateCaches;

// Thow away cached image content but keep the sample data
- (void)purgeDiscardableCacheContent;

// Notify the view controller about visibility of its page in the scroll view
- (void)noteStatisticsPageBecomesVisible: (BOOL)visible;

// Update statistics display to selected time period
- (void)setDisplayedNumberOfMonths: (NSInteger)numberOfMonths;


- (IBAction)buttonAction: (UIButton*)sender;

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activityView;

@property (nonatomic, weak) IBOutlet UILabel *leftLabel;
@property (nonatomic, weak) IBOutlet UILabel *rightLabel;
@property (nonatomic, weak) IBOutlet UILabel *centerLabel;

@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;

@property (nonatomic, strong) NSManagedObject *selectedCar;

@end
