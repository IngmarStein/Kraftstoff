// ShadowTableView.h
//
// Kraftstoff


@interface ShadowTableView : UITableView
{
    CAGradientLayer *originShadow;

    CAGradientLayer *cellShadowTop;
    CAGradientLayer *cellShadowBottom;

    BOOL shadowsNeedUpdate;
}

@property (nonatomic, strong) NSIndexPath *reorderSourceIndexPath;
@property (nonatomic, strong) NSIndexPath *reorderDestinationIndexPath;

@end
