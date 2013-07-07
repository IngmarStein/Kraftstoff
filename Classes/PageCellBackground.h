// PageCellBackground.h
//
// Kraftstoff


typedef enum
{
	PageCellGroupPositionUnknown = 0,
	PageCellGroupPositionTop,
	PageCellGroupPositionBottom,
	PageCellGroupPositionMiddle,
	PageCellGroupPositionTopAndBottom
} PageCellGroupPosition;


@interface PageCellBackground : UIView
{
	BOOL selected;
	BOOL groupBackground;
}

@property (nonatomic) PageCellGroupPosition position;
@property (nonatomic, strong) UIColor *strokeColor;

+ (PageCellGroupPosition)positionForIndexPath:(NSIndexPath *)indexPath inTableView:(UITableView *)tableView;

- (id)initSelected:(BOOL)isSelected grouped:(BOOL)isGrouped;

@end
