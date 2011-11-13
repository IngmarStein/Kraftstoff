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

@property (nonatomic, strong) NSIndexPath *reorderSourceIndexPath;
@property (nonatomic, strong) NSIndexPath *reorderDestinationIndexPath;

@end
