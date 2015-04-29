// FuelStatisticsPageController.m
//
// Kraftstoff


#import "FuelStatisticsPageController.h"
#import "FuelStatisticsGraphViewController.h"
#import "FuelStatisticsTextViewController.h"
#import "AppDelegate.h"



@implementation FuelStatisticsPageController
{
    BOOL pageControlUsed;
}



#pragma mark -
#pragma mark View Lifecycle



- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle
{
    if ((self = [super initWithNibName:nibName bundle:nibBundle])) {

        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }

    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    // Load content pages
    for (NSInteger page = 0; page < _pageControl.numberOfPages; page++) {

        FuelStatisticsViewController *controller = nil;

        switch (page) {

            case 0:controller = [FuelStatisticsViewController_PriceDistance  alloc]; break;
            case 1:controller = [FuelStatisticsViewController_AvgConsumption alloc]; break;
            case 2:controller = [FuelStatisticsViewController_PriceAmount alloc]; break;
            case 3:controller = [FuelStatisticsTextViewController alloc]; break;
        }

        controller = [controller initWithNibName:@"FuelStatisticsViewController" bundle:nil];
        controller.selectedCar = self.selectedCar;

        [self addChildViewController:controller];
        controller.view.frame = [self frameForPage:page];

        [_scrollView addSubview:controller.view];
    }

    // Configure scroll view
    _scrollView.contentSize = CGSizeMake (StatisticsViewWidth * _pageControl.numberOfPages, StatisticsViewHeight);
    _scrollView.scrollsToTop = NO;

    // Enlarge scrollView, hide pageControl
    _scrollView.frame = self.view.frame;
    _pageControl.hidden = YES;

    // Select preferred page
    dispatch_async (dispatch_get_main_queue(), ^{

        _pageControl.currentPage = [[NSUserDefaults standardUserDefaults] integerForKey:@"preferredStatisticsPage"];
        [self scrollToPage:_pageControl.currentPage animated:NO];

        pageControlUsed = NO;
    });
    
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(localeChanged:)
               name:NSCurrentLocaleDidChangeNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(didEnterBackground:)
               name:UIApplicationDidEnterBackgroundNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(didBecomeActive:)
               name:UIApplicationDidBecomeActiveNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(numberOfMonthsSelected:)
               name:@"numberOfMonthsSelected"
             object:nil];
}


- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}


- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [[NSUserDefaults standardUserDefaults] setInteger:_pageControl.currentPage forKey:@"preferredStatisticsPage"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


#pragma mark -
#pragma mark View Rotation



- (BOOL)shouldAutorotate
{
    return YES;
}


- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}



#pragma mark -
#pragma mark Cache Handling



- (void)invalidateCaches
{
    for (FuelStatisticsViewController *controller in self.childViewControllers)
        [controller invalidateCaches];
}



#pragma mark -
#pragma mark System Events



- (void)localeChanged:(id)object
{
    [self invalidateCaches];
}


- (void)didEnterBackground:(id)object
{
    [[NSUserDefaults standardUserDefaults] setInteger:_pageControl.currentPage forKey:@"preferredStatisticsPage"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    for (FuelStatisticsViewController *controller in self.childViewControllers)
        [controller purgeDiscardableCacheContent];
}


- (void)didBecomeActive:(id)object
{
    [self updatePageVisibility];
}



#pragma mark -
#pragma mark User Events



- (void)numberOfMonthsSelected:(NSNotification*)notification
{
    // Remeber selection in preferences
    NSInteger numberOfMonths = [[[notification userInfo] valueForKey:@"span"] integerValue];
    [[NSUserDefaults standardUserDefaults] setInteger:numberOfMonths forKey:@"statisticTimeSpan"];

    // Update all statistics controllers
    for (NSInteger i = 0; i < _pageControl.numberOfPages; i++) {

        NSInteger page = (_pageControl.currentPage + i) % _pageControl.numberOfPages;

        FuelStatisticsViewController *controller = (self.childViewControllers)[page];
        [controller setDisplayedNumberOfMonths:numberOfMonths];
    }
}



#pragma mark -
#pragma mark Frame Computation for Pages



- (CGRect)frameForPage:(NSInteger)page
{
    page = [_scrollView visiblePageForPage:page];

    CGRect frame = _scrollView.frame;
    frame.origin.x = frame.size.width * page;
    frame.origin.y = 0;

    return frame;
}



#pragma mark -
#pragma mark Sync ScrollView with Page Indicator



- (void)scrollViewDidScroll:(UIScrollView*)sender
{
    if (pageControlUsed == NO) {

        NSInteger newPage = floor ((_scrollView.contentOffset.x - StatisticsViewWidth*0.5) / StatisticsViewWidth) + 1;
        newPage = [self.scrollView pageForVisiblePage:newPage];

        if (_pageControl.currentPage != newPage) {

            _pageControl.currentPage = newPage;
            [self updatePageVisibility];
        }
    }
}


- (void)scrollViewWillBeginDragging:(UIScrollView*)scrollView
{
    pageControlUsed = NO;
}


- (void)scrollViewDidEndDecelerating:(UIScrollView*)view
{
    pageControlUsed = NO;
}



#pragma mark -
#pragma mark Page Control Handling



- (void)updatePageVisibility
{
    for (NSInteger page = 0; page < _pageControl.numberOfPages; page++) {

        FuelStatisticsViewController *controller = (self.childViewControllers)[page];
        [controller noteStatisticsPageBecomesVisible:(page == _pageControl.currentPage)];
    }
}


- (void)scrollToPage:(NSInteger)page animated:(BOOL)animated;
{
    pageControlUsed = YES;

    [_scrollView scrollRectToVisible:[self frameForPage:page] animated:animated];
    [self updatePageVisibility];
}


- (IBAction)pageAction:(id)sender
{
    [self scrollToPage:_pageControl.currentPage animated:YES];
}



#pragma mark -
#pragma mark Memory Management


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
