//
//  FuelStatisticsScrollView.h
//  Scrollview that allows infinite circular scrolling through 3 or more pages
//

#import <UIKit/UIKit.h>

@interface FuelStatisticsScrollView : UIScrollView

// Returns the logical page that is displayed in the currently visible actual page
- (NSInteger)pageForVisiblePage:(NSInteger)visiblePage;

// Returns the visible page that displays a given logical page
- (NSInteger)visiblePageForPage:(NSInteger)page;

@end
