//  ShadowTableView.m
//
//  Kraftstoff


#import "ShadowTableView.h"
#import "AppDelegate.h"


@implementation ShadowTableView

@synthesize reorderSourceIndexPath;
@synthesize reorderDestinationIndexPath;


- (id)initWithFrame: (CGRect)frame style: (UITableViewStyle)style
{
    if ((self = [super initWithFrame: frame style: style]))
    {
        shadowsNeedUpdate = YES;
    }

    return self;
}



#pragma mark -
#pragma mark Shadow Updates during Layout



- (UITableViewCell*)dequeueReusableCellWithIdentifier: (NSString*)identifier
{
    shadowsNeedUpdate = YES;

    return [super dequeueReusableCellWithIdentifier: identifier];
}


- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat shadowWidth = self.frame.size.width;

    // Pre-iOS6: construct the origin shadow if needed
    if ([AppDelegate isRunningOS6] == NO)
    {
        if (originShadow == nil)
            originShadow = [AppDelegate shadowWithFrame: CGRectMake (0.0, 0.0, shadowWidth, NavBarShadowHeight)
                                             darkFactor: 0.5
                                            lightFactor: 150.0 / 255.0
                                          fadeDownwards: YES];

        if (! [[self.layer.sublayers objectAtIndex: 0] isEqual: originShadow])
            [self.layer insertSublayer: originShadow atIndex: 0];

        // Stretch and place the origin shadow
        [CATransaction begin];
        [CATransaction setValue: (id)kCFBooleanTrue forKey: kCATransactionDisableActions];
        {
            CGRect originShadowFrame     = originShadow.frame;
            originShadowFrame.size.width = self.frame.size.width;
            originShadowFrame.origin.y   = self.contentOffset.y;
            originShadow.frame           = originShadowFrame;
        }
        [CATransaction commit];
    }

    // Computing index paths for visible cells below is expensive,
    // so skip this if the table configuration hasn't changed...
    if (!shadowsNeedUpdate)
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
    NSIndexPath *firstRow = [self indexPathForCell: [visibleCells objectAtIndex: 0]];
    int rowDeltaIndex     = 0;

    // Attach shadow to the second row if the first one is currently reordered...
    if ([firstRow isEqual: reorderSourceIndexPath] && ![reorderSourceIndexPath isEqual: reorderDestinationIndexPath])
    {
        firstRow      = [self indexPathForCell: [visibleCells objectAtIndex: 1]];
        rowDeltaIndex = 1;
    }

    if ([firstRow section] == 0 && [firstRow row] == rowDeltaIndex)
    {
        UIView *cell = [self cellForRowAtIndexPath: firstRow];

        if (cellShadowTop == nil)
            cellShadowTop = [AppDelegate shadowWithFrame: CGRectMake (0.0, 0.0, shadowWidth, TableTopShadowHeight)
                                              darkFactor: 0.3
                                             lightFactor: 100.0 / 255.0
                                           fadeDownwards: NO];

        if ([cell.layer.sublayers indexOfObjectIdenticalTo: cellShadowTop] != 0)
            [cell.layer insertSublayer: cellShadowTop atIndex: 0];

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
    NSIndexPath *lastRow  = [self indexPathForCell: [visibleCells objectAtIndex: visibleRowCount - 1]];
    rowDeltaIndex         = 1;

    // Attach shadow to the second last row if the last one is currently reordered...
    if ([lastRow isEqual: reorderSourceIndexPath] && ![reorderSourceIndexPath isEqual: reorderDestinationIndexPath])
    {
        lastRow       = [self indexPathForCell: [visibleCells objectAtIndex: visibleRowCount - 2]];
        rowDeltaIndex = 2;
    }

    if ([lastRow section] == [self numberOfSections] - 1 && [lastRow row] == [self numberOfRowsInSection: [lastRow section]] - rowDeltaIndex)
    {
        UIView *cell = [self cellForRowAtIndexPath: lastRow];

        if (cellShadowBottom == nil)
            cellShadowBottom = [AppDelegate shadowWithFrame: CGRectMake (0.0, 0.0, shadowWidth, TableBotShadowHeight)
                                                 darkFactor: 0.5
                                                lightFactor: 100.0 / 255.0
                                              fadeDownwards: YES];

        if ([cell.layer.sublayers indexOfObjectIdenticalTo: cellShadowBottom] != 0)
            [cell.layer insertSublayer: cellShadowBottom atIndex :0];

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



- (void)beginUpdates
{
    self.reorderSourceIndexPath = nil;

    [super beginUpdates];
}


- (void)endUpdates
{
    self.reorderSourceIndexPath = nil;
    shadowsNeedUpdate = YES;

    [super endUpdates];
}



#pragma mark -
#pragma mark Memory Management



- (void)dealloc
{
    [originShadow removeFromSuperlayer];
    [cellShadowTop removeFromSuperlayer];
    [cellShadowBottom removeFromSuperlayer];
}


@end
