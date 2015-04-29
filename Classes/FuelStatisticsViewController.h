// FuelStatisticsViewController.h
//
// Kraftstoff

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

extern CGFloat StatisticsViewWidth;
extern CGFloat StatisticsViewHeight;
extern CGFloat StatisticsHeight;
extern CGFloat StatisticTransitionDuration;


#pragma mark -
#pragma mark Base Class for Statistics View Controller


@interface FuelStatisticsViewController : UIViewController

// Set by presenting view controller
@property (nonatomic, strong) NSManagedObject *selectedCar;

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activityView;
@property (nonatomic, weak) IBOutlet UILabel *leftLabel;
@property (nonatomic, weak) IBOutlet UILabel *rightLabel;
@property (nonatomic, weak) IBOutlet UILabel *centerLabel;
@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;

@property (nonatomic, readonly) NSMutableDictionary *contentCache;
@property (nonatomic, readonly) NSInteger displayedNumberOfMonths;


// Throw away all cached content, e.g. on new/updated events
- (void)invalidateCaches;

// Thow away cached image content but keep the sample data
- (void)purgeDiscardableCacheContent;

// Notify the view controller about visibility of its page in the scroll view
- (void)noteStatisticsPageBecomesVisible:(BOOL)visible;

// Update statistics display to selected time period
- (void)setDisplayedNumberOfMonths:(NSInteger)numberOfMonths;

// Handler for time selection buttons
- (IBAction)buttonAction:(UIButton *)sender;

@end
