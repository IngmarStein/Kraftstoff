// QuadInfoCell.h
//
// TableView cells with four labels for information.


#import "QuadInfoCell.h"
#import "AppDelegate.h"

@interface QuadInfoCell ()

@property (nonatomic, strong) UIView *separatorView;

@end

@implementation QuadInfoCell
{
    UITableViewCellStateMask cellState;
    BOOL large;
}


- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier enlargeTopRightLabel:(BOOL)enlargeTopRightLabel
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {

        cellState = UITableViewCellStateDefaultMask;
        large     = enlargeTopRightLabel;

    
        _topLeftLabel                            = [[UILabel alloc] initWithFrame:CGRectZero];
        _topLeftLabel.backgroundColor            = [UIColor clearColor];
        _topLeftLabel.textColor                  = [UIColor blackColor];
        _topLeftLabel.adjustsFontSizeToFitWidth  = YES;
        _topLeftLabel.font                       = [UIFont fontWithName:@"HelveticaNeue-Light" size:22];
        _topLeftLabel.minimumScaleFactor         = 12.0/[_topLeftLabel.font pointSize];
        [self.contentView addSubview:_topLeftLabel];


        _botLeftLabel                            = [[UILabel alloc] initWithFrame:CGRectZero];
        _botLeftLabel.backgroundColor            = [UIColor clearColor];
        _botLeftLabel.textColor                  = [UIColor colorWithWhite:0.5 alpha:1.0];
        _botLeftLabel.adjustsFontSizeToFitWidth  = YES;
        _botLeftLabel.font                       = [UIFont fontWithName:@"HelveticaNeue-Light" size:15.0];
        _botLeftLabel.minimumScaleFactor         = 12.0/[_botLeftLabel.font pointSize];
        [self.contentView addSubview:_botLeftLabel];


        _topRightLabel                           = [[UILabel alloc] initWithFrame:CGRectZero];
        _topRightLabel.backgroundColor           = [UIColor clearColor];
        _topRightLabel.textColor                 = [UIColor blackColor];
        _topRightLabel.adjustsFontSizeToFitWidth = YES;
        _topRightLabel.font                      = [UIFont fontWithName:@"HelveticaNeue-Light" size:large ? 28.0 : 22.0];
        _topRightLabel.minimumScaleFactor        = 12.0/[_topRightLabel.font pointSize];
        _topRightLabel.textAlignment             = NSTextAlignmentRight;
        [self.contentView addSubview:_topRightLabel];


        _botRightLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _botRightLabel.backgroundColor           = [UIColor clearColor];
        _botRightLabel.textColor                 = [UIColor colorWithWhite:0.5 alpha:1.0];
        _botRightLabel.adjustsFontSizeToFitWidth = YES;
        _botRightLabel.font                      = [UIFont fontWithName:@"HelveticaNeue-Light" size:15.0];
        _botRightLabel.minimumScaleFactor        = 12.0/[_botRightLabel.font pointSize];
        _botRightLabel.textAlignment             = NSTextAlignmentRight;
        [self.contentView addSubview:_botRightLabel];


		_separatorView = [[UIView alloc] initWithFrame:CGRectZero];
		_separatorView.backgroundColor = [UIColor colorWithWhite:200.0/255.0 alpha:1.0];
		[self.contentView addSubview:_separatorView];

        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return self;
}


- (NSString *)accessibilityLabel
{
    NSString *label = [NSString stringWithFormat:@"%@, %@",
                            (_topLeftAccessibilityLabel) ? _topLeftAccessibilityLabel : _topLeftLabel.text,
                            (_botLeftAccessibilityLabel) ? _botLeftAccessibilityLabel : _botLeftLabel.text];

    if (cellState == UITableViewCellStateDefaultMask) {

        if (_topRightAccessibilityLabel)
            label = [label stringByAppendingFormat:@", %@", _topRightAccessibilityLabel];

        if (_botRightAccessibilityLabel)
            label = [label stringByAppendingFormat:@" %@",  _botRightAccessibilityLabel];
    }

    return label;
}


// Remember target state for transition
- (void)willTransitionToState:(UITableViewCellStateMask)newState
{
    [super willTransitionToState:newState];
    cellState = newState;
}


// Reset to default state before reuse of cell
- (void)prepareForReuse
{
    [super prepareForReuse];
    cellState = UITableViewCellStateDefaultMask;
}


- (void)layoutSubviews
{
    CGFloat margin = 15.0;

    // offset to compensate shift caused by editing control
    CGFloat editOffset = 0;

    if (cellState & UITableViewCellStateShowingEditControlMask)
        editOffset = 38.0;

    // space that can be distributed
    CGFloat width = self.frame.size.width - 9 - margin;

    // width of right labels
    CGFloat iWidth  = large ?  96.0 : 135.0;

    // y position and height of top right label
    CGFloat iYStart = large ?  17.0 :  20.0;
    CGFloat iHeight = large ?  36.0 :  30.0;
	CGFloat separatorHeight = 1.0 / [UIScreen mainScreen].scale;

    // compute label frames
    _topLeftLabel.frame  = CGRectMake(margin,                      20,       width - iWidth - 20, 30);
    _botLeftLabel.frame  = CGRectMake(margin,                      52,       width - iWidth - 20, 20);
    _topRightLabel.frame = CGRectMake(width - iWidth - editOffset, iYStart, iWidth - margin,      iHeight);
    _botRightLabel.frame = CGRectMake(width - iWidth - editOffset, 52,      iWidth - margin,      20);
	_separatorView.frame = CGRectMake(0, self.frame.size.height - separatorHeight, self.frame.size.width, separatorHeight);

    // hide right labels in editing modes
    [UIView animateWithDuration:0.5
                     animations:^{

                         CGFloat newAlpha = (cellState & UITableViewCellStateShowingEditControlMask) ? 0.0 : 1.0;

                         _topRightLabel.alpha = newAlpha;
                         _botRightLabel.alpha = newAlpha;
                     }];

    [super layoutSubviews];
}

@end
