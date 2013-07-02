//
//  FuelStatisticsScrollView.h
//  kraftstoff
//

@interface FuelStatisticsScrollView : UIScrollView

- (NSInteger)pageForVisiblePage:(NSInteger)visiblePage;
- (NSInteger)visiblePageForPage:(NSInteger)page;

@end
