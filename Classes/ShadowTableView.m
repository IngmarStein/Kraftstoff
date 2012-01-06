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


- (UITableViewCell*)dequeueReusableCellWithIdentifier: (NSString*)identifier
{
    shadowsNeedUpdate = YES;

    return [super dequeueReusableCellWithIdentifier: identifier];
}


// Shadows are laid out here when layout of cell occurs.
- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat shadowWidth = self.frame.size.width;

    // Construct the origin shadow if needed
    if (originShadow == nil)
        originShadow = [AppDelegate shadowWithFrame: CGRectMake (0.0, 0.0, shadowWidth, LargeShadowHeight)
                                         darkFactor: 0.5
                                        lightFactor: 150.0 / 255.0
                                      fadeDownwards: YES];

    if (! [[self.layer.sublayers objectAtIndex: 0] isEqual: originShadow])
        [self.layer insertSublayer: originShadow atIndex: 0];


    // Stretch and place the origin/footer shadow
    [CATransaction begin];
    [CATransaction setValue: (id)kCFBooleanTrue forKey: kCATransactionDisableActions];
    {
        CGRect originShadowFrame     = originShadow.frame;
        originShadowFrame.size.width = self.frame.size.width;
        originShadowFrame.origin.y   = self.contentOffset.y;
        originShadow.frame           = originShadowFrame;
    }
    [CATransaction commit];


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
        [topCellShadow removeFromSuperlayer];
        topCellShadow = nil;

        [bottomCellShadow removeFromSuperlayer];
        bottomCellShadow = nil;

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

        if (topCellShadow == nil)
            topCellShadow = [AppDelegate shadowWithFrame: CGRectMake (0.0, 0.0, shadowWidth, SmallShadowHeight)
                                              darkFactor: 0.3
                                             lightFactor: 100.0 / 255.0
                                           fadeDownwards: NO];

        if ([cell.layer.sublayers indexOfObjectIdenticalTo: topCellShadow] != 0)
            [cell.layer insertSublayer: topCellShadow atIndex: 0];

        CGRect shadowFrame     = topCellShadow.frame;
        shadowFrame.size.width = cell.frame.size.width;
        shadowFrame.origin.y   = -SmallShadowHeight;
        topCellShadow.frame    = shadowFrame;
    }
    else
    {
        [topCellShadow removeFromSuperlayer];
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

        if (bottomCellShadow == nil)
            bottomCellShadow = [AppDelegate shadowWithFrame: CGRectMake (0.0, 0.0, shadowWidth, MediumShadowHeight)
                                                 darkFactor: 0.5
                                                lightFactor: 100.0 / 255.0
                                              fadeDownwards: YES];

        if ([cell.layer.sublayers indexOfObjectIdenticalTo: bottomCellShadow] != 0)
            [cell.layer insertSublayer: bottomCellShadow atIndex :0];

        CGRect shadowFrame     = bottomCellShadow.frame;
        shadowFrame.size.width = cell.frame.size.width;
        shadowFrame.origin.y   = cell.frame.size.height;
        bottomCellShadow.frame = shadowFrame;
    }
    else
    {
        [bottomCellShadow removeFromSuperlayer];
    }
}


- (void)dealloc
{
    [originShadow removeFromSuperlayer];
    [topCellShadow removeFromSuperlayer];
    [bottomCellShadow removeFromSuperlayer];
}


- (void)beginUpdates
{
    self.reorderSourceIndexPath = nil;
    [super beginUpdates];
}


- (void)endUpdates
{
    shadowsNeedUpdate = YES;

    self.reorderSourceIndexPath = nil;
    [super endUpdates];
}

@end
