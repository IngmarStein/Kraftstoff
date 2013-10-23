// QuadInfoCell.h
//
// TableView cells with four labels for information.


@interface QuadInfoCell : UITableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier enlargeTopRightLabel:(BOOL)largeRightLabel;

@property (nonatomic, strong, readonly) UILabel *topLeftLabel;
@property (nonatomic, strong, readonly) UILabel *botLeftLabel;
@property (nonatomic, strong, readonly) UILabel *topRightLabel;
@property (nonatomic, strong, readonly) UILabel *botRightLabel;

@property (nonatomic, strong) NSString *topLeftAccessibilityLabel;
@property (nonatomic, strong) NSString *botLeftAccessibilityLabel;
@property (nonatomic, strong) NSString *topRightAccessibilityLabel;
@property (nonatomic, strong) NSString *botRightAccessibilityLabel;

@end
