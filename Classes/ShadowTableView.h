// ShadowTableView.h
//
// Kraftstoff


@interface ShadowTableView : UITableView
{
    CAGradientLayer *originShadow;

    CAGradientLayer *topCellShadow;
    CAGradientLayer *bottomCellShadow;

    BOOL shadowsNeedUpdate;
}

@property (nonatomic, retain) NSIndexPath *reorderSourceIndexPath;
@property (nonatomic, retain) NSIndexPath *reorderDestinationIndexPath;

@end
