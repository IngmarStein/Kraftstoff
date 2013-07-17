//
//  FuelStatisticsScrollView.m
//  Scrollview that allows infinite circular scrolling through 3 or more pages
//

#import "FuelStatisticsScrollView.h"

@implementation FuelStatisticsScrollView
{
    // Offset between logical and currently visible pages
    NSInteger pageOffset;
}


- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {

        pageOffset = 0;
    }

    return self;
}


- (NSInteger)pageForVisiblePage:(NSInteger)visiblePage
{
    NSInteger numberOfPages = rint (self.contentSize.width / self.bounds.size.width);

    if (numberOfPages)
        return (visiblePage + pageOffset + numberOfPages) % numberOfPages;
    else
        return visiblePage;
}


- (NSInteger)visiblePageForPage:(NSInteger)page
{
    NSInteger numberOfPages = rint (self.contentSize.width / self.bounds.size.width);

    if (numberOfPages)
        return (page - pageOffset + numberOfPages) % numberOfPages;
    else
        return page;
}


// Updates the internal pageOffset between logical and visible pages such that such that the actual offset of the scrollview can be kept at the second page.
- (void)recenterIfNecessary
{
    CGPoint currentOffset = [self contentOffset];
    CGFloat contentWidth = [self contentSize].width;
    CGFloat pageWidth = self.bounds.size.width;
    CGFloat centerOffsetX = pageWidth;
    NSInteger numOfPages = rint (contentWidth / pageWidth);

    // Distance from center is large enough for recentering
    if (fabs (currentOffset.x - centerOffsetX) >= pageWidth) {

        // Constrain shifts to full page width
        CGFloat shiftDelta;

        if (currentOffset.x - centerOffsetX > 0) {

            shiftDelta = -pageWidth;
            pageOffset += 1;

        } else {

            shiftDelta = pageWidth;
            pageOffset -= 1;
        }

        // Keep pageOffset in sane region
        if (pageOffset < 0)
            pageOffset += numOfPages;

        else if (pageOffset >= numOfPages)
            pageOffset %= numOfPages;

        // Recenter scrollview
        self.contentOffset = CGPointMake (currentOffset.x + shiftDelta, currentOffset.y);

        // Move content by the same amount so it appears to stay still
        for (UIView *view in [self subviews]) {

            CGPoint center = view.center;

            center.x += shiftDelta;

            // Wrap content around to get a circular scrolling
            if (center.x < 0)
                center.x += contentWidth;
            else if (center.x > contentWidth)
                center.x -= contentWidth;

            view.center = center;
        }
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self recenterIfNecessary];
}

@end
