// ShadedTableViewCell.h
//
// Kraftstoff


@interface ShadedTableViewCell : UITableViewCell
{
    UITableViewCellStateMask state;
    BOOL large;
}

- (id)initWithStyle: (UITableViewCellStyle)style reuseIdentifier: (NSString*)reuseIdentifier enlargeTopRightLabel: (BOOL)largeRightLabel;

@property (nonatomic, readonly) UILabel  *topLeftLabel;
@property (nonatomic, retain)   NSString *topLeftAccessibilityLabel;

@property (nonatomic, readonly) UILabel  *botLeftLabel;
@property (nonatomic, retain)   NSString *botLeftAccessibilityLabel;

@property (nonatomic, readonly) UILabel  *topRightLabel;
@property (nonatomic, retain)   NSString *topRightAccessibilityLabel;

@property (nonatomic, readonly) UILabel  *botRightLabel;
@property (nonatomic, retain)   NSString *botRightAccessibilityLabel;

@end
