// FuelStatisticsViewController.h
//
// Kraftstoff



#pragma mark -
#pragma mark Base Statistics View Controller



@interface FuelStatisticsViewController : UIViewController
{
    NSMutableDictionary *contentCache;
    NSInteger  displayedNumberOfMonths;
    NSInteger  invalidationCounter;
}

- (IBAction)checkboxButton: (UIButton*)sender;

- (void)invalidateCaches;
- (void)purgeDiscardableCacheContent;

@property (nonatomic, retain) NSManagedObject *selectedCar;
@property (nonatomic)         BOOL             active;

@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *activityView;
@property (nonatomic, retain) IBOutlet UILabel                 *leftLabel;
@property (nonatomic, retain) IBOutlet UILabel                 *rightLabel;

@end



#pragma mark -
#pragma mark Subclasses for Statistics Pages



@interface FuelStatisticsViewController_AvgConsumption : FuelStatisticsViewController {}
@end

@interface FuelStatisticsViewController_PriceAmount : FuelStatisticsViewController {}
@end

@interface FuelStatisticsViewController_PriceDistance : FuelStatisticsViewController {}
@end



#pragma mark -
#pragma mark Disposable Content Objects Entry for NSCache



#define MAX_SAMPLES   128

@interface FuelStatisticsSamplingData : NSObject
{
@public

    // Curve data
    CGPoint   data [MAX_SAMPLES];
    NSInteger dataCount;

    // Data for marker positions
    CGFloat   hMarkPositions [5];
    NSString* hMarkNames [5];
    NSInteger hMarkCount;

    CGFloat   vMarkPositions [3];
    NSString* vMarkNames [3];
    NSInteger vMarkCount;
}

@property (nonatomic, retain) UIImage  *contentImage;
@property (nonatomic, retain) NSNumber *contentAverage;

@end