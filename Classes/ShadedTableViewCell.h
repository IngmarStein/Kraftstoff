// ShadedTableViewCell.h
//
// Kraftstoff


@interface ShadedTableViewCell : UITableViewCell
{
    UITableViewCellStateMask state;
    BOOL large;
}

- (id)initWithStyle: (UITableViewCellStyle)style reuseIdentifier: (NSString*)reuseIdentifier enlargeTopRightLabel: (BOOL)largeRightLabel;

@property (nonatomic, strong, readonly) UILabel  *topLeftLabel;
@property (nonatomic, strong)           NSString *topLeftAccessibilityLabel;

@property (nonatomic, strong, readonly) UILabel  *botLeftLabel;
@property (nonatomic, strong)           NSString *botLeftAccessibilityLabel;

@property (nonatomic, strong, readonly) UILabel  *topRightLabel;
@property (nonatomic, strong)           NSString *topRightAccessibilityLabel;

@property (nonatomic, strong, readonly) UILabel  *botRightLabel;
@property (nonatomic, strong)           NSString *botRightAccessibilityLabel;

@end
