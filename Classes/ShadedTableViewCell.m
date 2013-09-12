// ShadedTableViewCell.h
//
// TableView cells with four labels for information.


#import "ShadedTableViewCell.h"
#import "AppDelegate.h"


@implementation ShadedTableViewCell
{
    UITableViewCellStateMask cellState;
    BOOL large;
}


- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier enlargeTopRightLabel:(BOOL)enlargeTopRightLabel
{
    BOOL useOldStyle = ([AppDelegate systemMajorVersion] < 7);

    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {

        cellState = UITableViewCellStateDefaultMask;
        large     = enlargeTopRightLabel;

    
        _topLeftLabel                            = [[UILabel alloc] initWithFrame:CGRectZero];
        _topLeftLabel.backgroundColor            = [UIColor clearColor];
        _topLeftLabel.textColor                  = [UIColor blackColor];

        if (useOldStyle) {
            _topLeftLabel.shadowColor            = [UIColor colorWithWhite:1.0 alpha:0.8];
            _topLeftLabel.shadowOffset           = CGSizeMake(0.0, 1.0);
            _topLeftLabel.highlightedTextColor   = [UIColor whiteColor];
        }

        _topLeftLabel.adjustsFontSizeToFitWidth  = YES;
        _topLeftLabel.font                       = (useOldStyle) ? [UIFont boldSystemFontOfSize:22.0] : [UIFont fontWithName:@"HelveticaNeue-Light" size:22];
        _topLeftLabel.minimumScaleFactor         = 12.0/[_topLeftLabel.font pointSize];
        [self.contentView addSubview:_topLeftLabel];


        _botLeftLabel                            = [[UILabel alloc] initWithFrame:CGRectZero];
        _botLeftLabel.backgroundColor            = [UIColor clearColor];
        _botLeftLabel.textColor                  = (useOldStyle) ? [UIColor darkGrayColor] : [UIColor colorWithWhite:0.5 alpha:1.0];

        if (useOldStyle) {
            _botLeftLabel.shadowColor            = [UIColor colorWithWhite:1.0 alpha:0.8];
            _botLeftLabel.shadowOffset           = CGSizeMake(0.0, 1.0);
            _botLeftLabel.highlightedTextColor   = [UIColor whiteColor];
        }

        _botLeftLabel.adjustsFontSizeToFitWidth  = YES;
        _botLeftLabel.font                       = (useOldStyle) ? [UIFont boldSystemFontOfSize:15.0] : [UIFont fontWithName:@"HelveticaNeue-Light" size:15.0];
        _botLeftLabel.minimumScaleFactor         = 12.0/[_botLeftLabel.font pointSize];
        [self.contentView addSubview:_botLeftLabel];


        _topRightLabel                           = [[UILabel alloc] initWithFrame:CGRectZero];
        _topRightLabel.backgroundColor           = [UIColor clearColor];
        _topRightLabel.textColor                 = [UIColor blackColor];

        if (useOldStyle) {
            _topRightLabel.shadowColor           = [UIColor colorWithWhite:1.0 alpha:0.8];
            _topRightLabel.shadowOffset          = CGSizeMake(0.0, 1.0);
            _topRightLabel.highlightedTextColor  = [UIColor whiteColor];
        }

        _topRightLabel.adjustsFontSizeToFitWidth = YES;
        _topRightLabel.font                      = (useOldStyle) ? [UIFont boldSystemFontOfSize:large ? 28.0 : 22.0] : [UIFont fontWithName:@"HelveticaNeue-Light" size:large ? 28.0 : 22.0];
        _topRightLabel.minimumScaleFactor        = 12.0/[_topRightLabel.font pointSize];
        _topRightLabel.textAlignment             = NSTextAlignmentRight;
        [self.contentView addSubview:_topRightLabel];


        _botRightLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _botRightLabel.backgroundColor           = [UIColor clearColor];
        _botRightLabel.textColor                 = (useOldStyle) ? [UIColor darkGrayColor] : [UIColor colorWithWhite:0.5 alpha:1.0];

        if (useOldStyle) {
            _botRightLabel.shadowColor           = [UIColor colorWithWhite:1.0 alpha:0.8];
            _botRightLabel.shadowOffset          = CGSizeMake(0.0, 1.0);
            _botRightLabel.highlightedTextColor  = [UIColor whiteColor];
        }

        _botRightLabel.adjustsFontSizeToFitWidth = YES;
        _botRightLabel.font                      = (useOldStyle) ? [UIFont boldSystemFontOfSize:15.0] : [UIFont fontWithName:@"HelveticaNeue-Light" size:15.0];
        _botRightLabel.minimumScaleFactor        = 12.0/[_botRightLabel.font pointSize];
        _botRightLabel.textAlignment             = NSTextAlignmentRight;
        [self.contentView addSubview:_botRightLabel];


        UIImageView *imageView;

        imageView = [[UIImageView alloc] init];
        imageView.image = [UIImage imageNamed:(useOldStyle) ? @"CellShade" : @"CellShadeFlat"];
        self.backgroundView = imageView;

        if (useOldStyle) {
            imageView = [[UIImageView alloc] init];
            imageView.image = [UIImage imageNamed:@"SelectedCellShade"];
            self.selectedBackgroundView = imageView;
        }

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



// Disable text shadow in highlighted and selected states
- (void)updateLabelShadowOffset
{
    if ([AppDelegate systemMajorVersion] < 7) {

        CGSize offset = ([self isHighlighted] || [self isSelected]) ? CGSizeZero : CGSizeMake(0.0, 1.0);

        _topLeftLabel.shadowOffset  = offset;
        _botLeftLabel.shadowOffset  = offset;
        _topRightLabel.shadowOffset = offset;
        _botRightLabel.shadowOffset = offset;
    }
}


- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    [self updateLabelShadowOffset];
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    [self updateLabelShadowOffset];
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
    BOOL useOldStyle = ([AppDelegate systemMajorVersion] < 7);

    CGFloat margin = (useOldStyle ? 10.0 : 15.0);

    // offset to compensate shift caused by editing control
    CGFloat editOffset = 0;

    if (cellState & UITableViewCellStateShowingEditControlMask)
        editOffset = (useOldStyle ? 32.0 : 38.0);

    // space that can be distributed
    CGFloat width = self.frame.size.width - 9 - margin;

    // width of right labels
    CGFloat iWidth  = large ?  96.0 : 135.0;

    // y position and height of top right label
    CGFloat iYStart = large ?  17.0 :  20.0;
    CGFloat iHeight = large ?  36.0 :  30.0;

    // compute label frames
    _topLeftLabel.frame  = CGRectMake(margin,                      20,       width - iWidth - 20, 30);
    _botLeftLabel.frame  = CGRectMake(margin,                      52,       width - iWidth - 20, 20);
    _topRightLabel.frame = CGRectMake(width - iWidth - editOffset, iYStart, iWidth - margin,      iHeight);
    _botRightLabel.frame = CGRectMake(width - iWidth - editOffset, 52,      iWidth - margin,      20);

    // hide right labels in editing modes
    [UIView animateWithDuration:0.5
                     animations:^{

                         CGFloat newAlpha = 1.0;

                         if (useOldStyle)
                             newAlpha = (cellState != UITableViewCellStateDefaultMask) ? 0.0 : 1.0;
                         else
                             newAlpha = (cellState & UITableViewCellStateShowingEditControlMask) ? 0.0 : 1.0;

                         _topRightLabel.alpha = newAlpha;
                         _botRightLabel.alpha = newAlpha;
                     }];

    [super layoutSubviews];

    // #radar 14977605: backgroundView may overlap delete confirmation button
    if (useOldStyle == NO && self.editingStyle == UITableViewCellEditingStyleDelete) {

        CGRect frame = self.backgroundView.frame;
        frame.size.width = MIN(frame.size.width, 320-frame.origin.x);
        self.backgroundView.frame = frame;
    }
}

@end
