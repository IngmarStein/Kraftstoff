// ShadowTableView.m
//
// Tableview that adds two shadow layers above/below the first/last row.


#import "ShadowTableView.h"
#import "AppDelegate.h"


@implementation ShadowTableView
{
    CAGradientLayer *cellShadowTop;
    CAGradientLayer *cellShadowBottom;

    BOOL shadowsNeedUpdate;
}


- (id)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
    if ((self = [super initWithFrame:frame style:style]))
    {
        [self setNeedsShadowUpdate];
    }

    return self;
}


- (void)setNeedsShadowUpdate
{
    shadowsNeedUpdate = YES;

    [self setNeedsLayout];
}



#pragma mark -
#pragma mark Shadow Updates during Layout



- (UITableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier
{
    // Mark for update of shadows whenever new cells are dequeued
    [self setNeedsShadowUpdate];

    return [super dequeueReusableCellWithIdentifier:identifier];
}


- (void)layoutSubviews
{
    [super layoutSubviews];

    
    // Skip shadow update when contents is unchanged or iOS7 is used
    if (shadowsNeedUpdate == NO || [AppDelegate systemMajorVersion] >= 7)
        return;

    shadowsNeedUpdate = NO;

    // Remove any cell shadow when table is empty
    NSArray *visibleCells     = [self visibleCells];
    NSInteger visibleRowCount = [visibleCells count];

    if (visibleRowCount == 0)
    {
        [cellShadowTop removeFromSuperlayer];
        cellShadowTop = nil;

        [cellShadowBottom removeFromSuperlayer];
        cellShadowBottom = nil;

        return;
    }

    // Add shadow before very first row
    NSIndexPath *firstIndexPath = [self indexPathForCell:visibleCells[0]];

    if ([firstIndexPath section] == 0 && [firstIndexPath row] == 0)
    {
        UIView *cell = [self cellForRowAtIndexPath:firstIndexPath];

        if (cellShadowTop == nil)
            cellShadowTop = [AppDelegate shadowWithFrame:CGRectMake(0.0, 0.0, self.frame.size.width, TableTopShadowHeight)
                                              darkFactor:0.3
                                             lightFactor:100.0 / 255.0
                                           fadeDownwards:NO];

        if ([cell.layer.sublayers indexOfObjectIdenticalTo:cellShadowTop] == NSNotFound)
            [cell.layer insertSublayer:cellShadowTop atIndex:0];

        CGRect shadowFrame     = cellShadowTop.frame;
        shadowFrame.size.width = cell.frame.size.width;
        shadowFrame.origin.y   = -TableTopShadowHeight;
        cellShadowTop.frame    = shadowFrame;
    }
    else
    {
        [cellShadowTop removeFromSuperlayer];
    }

    // Another shadow below the last row of the table
    NSIndexPath *lastIndexPath = [self indexPathForCell:visibleCells[visibleRowCount - 1]];

    if ([lastIndexPath section] == [self numberOfSections] - 1 && [lastIndexPath row] == [self numberOfRowsInSection:[lastIndexPath section]] - 1)
    {
        UIView *cell = [self cellForRowAtIndexPath:lastIndexPath];

        if (cellShadowBottom == nil)
            cellShadowBottom = [AppDelegate shadowWithFrame:CGRectMake(0.0, 0.0, self.frame.size.width, TableBotShadowHeight)
                                                 darkFactor:0.5
                                                lightFactor:100.0 / 255.0
                                              fadeDownwards:YES];

        if ([cell.layer.sublayers indexOfObjectIdenticalTo:cellShadowBottom] == NSNotFound)
            [cell.layer insertSublayer:cellShadowBottom atIndex:0];

        CGRect shadowFrame     = cellShadowBottom.frame;
        shadowFrame.size.width = cell.frame.size.width;
        shadowFrame.origin.y   = cell.frame.size.height;
        cellShadowBottom.frame = shadowFrame;
    }
    else
    {
        [cellShadowBottom removeFromSuperlayer];
    }
}



#pragma mark -
#pragma mark Tracking User Updates



- (void)endUpdates
{
    [self setNeedsShadowUpdate];
    [super endUpdates];
}



#pragma mark -
#pragma mark Memory Management



- (void)dealloc
{
    [cellShadowTop removeFromSuperlayer];
    [cellShadowBottom removeFromSuperlayer];
}

@end
