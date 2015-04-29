// QuadInfoCell.h
//
// TableView cells with four labels for information.

#import <UIKit/UIKit.h>

@interface QuadInfoCell : UITableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier enlargeTopRightLabel:(BOOL)largeRightLabel NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong, readonly) UILabel *topLeftLabel;
@property (nonatomic, strong, readonly) UILabel *botLeftLabel;
@property (nonatomic, strong, readonly) UILabel *topRightLabel;
@property (nonatomic, strong, readonly) UILabel *botRightLabel;

@property (nonatomic, strong) NSString *topLeftAccessibilityLabel;
@property (nonatomic, strong) NSString *botLeftAccessibilityLabel;
@property (nonatomic, strong) NSString *topRightAccessibilityLabel;
@property (nonatomic, strong) NSString *botRightAccessibilityLabel;

@end
