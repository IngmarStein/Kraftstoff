// FuelStatisticsPageController.m
//
// Kraftstoff


#import "FuelStatisticsPageController.h"
#import "FuelStatisticsGraphViewController.h"
#import "FuelStatisticsTextViewController.h"
#import "AppDelegate.h"


@interface FuelStatisticsPageController (private)

- (void)updatePageVisibility;
- (void)scrollToPage: (NSInteger)page animated: (BOOL)animated;

- (void)localeChanged: (id)object;

@end


@implementation FuelStatisticsPageController


@synthesize selectedCar;
@synthesize viewControllers;
@synthesize scrollView;
@synthesize pageControl;



#pragma mark -
#pragma mark View Lifecycle



- (void)viewDidLoad
{
    [super viewDidLoad];

    // Configure scroll view
    scrollView.contentSize  = CGSizeMake (scrollView.frame.size.width * pageControl.numberOfPages, scrollView.frame.size.height);
    scrollView.scrollsToTop = NO;

    // Select preferred page
    pageControl.currentPage = [[NSUserDefaults standardUserDefaults] integerForKey: @"preferredStatisticsPage"];
    [self scrollToPage: pageControl.currentPage animated: NO];

    // Load content pages
    self.viewControllers = [[NSMutableArray alloc] init];

    for (NSInteger page = 0; page < pageControl.numberOfPages; page++)
    {
        FuelStatisticsViewController *controller = nil;

        switch (page)
        {
            case 0: controller = [FuelStatisticsViewController_PriceDistance  alloc]; break;
            case 1: controller = [FuelStatisticsViewController_AvgConsumption alloc]; break;
            case 2: controller = [FuelStatisticsViewController_PriceAmount    alloc]; break;
            case 3: controller = [FuelStatisticsTextViewController alloc]; break;                
        }

        controller = [controller initWithNibName: @"FuelStatisticsViewController" bundle: nil];

        controller.selectedCar = self.selectedCar;
        controller.active      = (page == pageControl.currentPage);

        [self.viewControllers addObject: controller];

        CGRect frame          = scrollView.frame;
        frame.origin.x        = frame.size.width * page;
        frame.origin.y        = 0;
        controller.view.frame = frame;

        [scrollView addSubview: controller.view];
    }

    pageControlUsed = NO;

    // Observe locale changes
    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector (localeChanged:)
               name: NSCurrentLocaleDidChangeNotification
             object: nil];

    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector (localeChanged:)
               name: kraftstoffCarsEditedNotification
             object: nil];

    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector (didEnterBackground:)
               name: UIApplicationDidEnterBackgroundNotification
             object: nil];
}


- (void)viewWillAppear: (BOOL)animated
{
    [super viewWillAppear: animated];

    for (FuelStatisticsViewController *controller in self.viewControllers)
    {
        [controller viewWillAppear: animated];
    }
}


- (void)localeChanged: (id)object
{
    [self invalidateCaches];
}


- (void)didEnterBackground: (id)object
{
    for (FuelStatisticsViewController *controller in self.viewControllers)
    {
        [controller purgeDiscardableCacheContent];
    }
}


- (BOOL)shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation)interfaceOrientation
{
    return UIInterfaceOrientationIsLandscape (interfaceOrientation);
}



#pragma mark -
#pragma mark Cache Handling on Changes to Core Data or the User Locale



- (void)invalidateCaches
{
    for (FuelStatisticsViewController *controller in self.viewControllers)
    {
        [controller invalidateCaches];
    }
}



#pragma mark -
#pragma mark Sync ScrollView with Page Indicator



- (void)updatePageVisibility
{
    for (NSInteger page = 0; page < pageControl.numberOfPages; page++)
    {
        FuelStatisticsViewController *controller = [viewControllers objectAtIndex: page];
        controller.active = (page == pageControl.currentPage);
    }
}


- (void)scrollViewDidScroll: (UIScrollView*)sender
{
    if (pageControlUsed == NO)
    {
        NSInteger currentPage   = pageControl.currentPage;
        CGFloat pageWidth       = scrollView.frame.size.width;
        pageControl.currentPage = floor ((scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
        
        if (pageControl.currentPage != currentPage)
            [self updatePageVisibility];
    }

    [[NSUserDefaults standardUserDefaults] setInteger: pageControl.currentPage forKey: @"preferredStatisticsPage"];
}


- (void)scrollViewWillBeginDragging: (UIScrollView*)scrollView
{
    pageControlUsed = NO;
}


- (void)scrollViewDidEndDecelerating: (UIScrollView*)view
{
    pageControlUsed = NO;
}


- (void)scrollToPage: (NSInteger)page animated: (BOOL)animated;
{
    CGRect frame   = scrollView.frame;
    frame.origin.x = frame.size.width * page;
    frame.origin.y = 0;

    pageControlUsed = YES;
    [scrollView scrollRectToVisible: frame animated: animated];

    [self updatePageVisibility];
}


- (IBAction)pageAction: (id)sender
{
    [self scrollToPage: pageControl.currentPage animated: YES];
}



#pragma mark -
#pragma mark Memory Management



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    self.scrollView      = nil;
    self.pageControl     = nil;
    self.viewControllers = nil;

    [super viewDidUnload];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

@end
