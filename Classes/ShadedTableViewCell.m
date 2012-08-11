// ShadedTableViewCell.h
//
// Kraftstoff


#import "ShadedTableViewCell.h"


@implementation ShadedTableViewCell

@synthesize topLeftLabel;
@synthesize topLeftAccessibilityLabel;

@synthesize botLeftLabel;
@synthesize botLeftAccessibilityLabel;

@synthesize topRightLabel;
@synthesize topRightAccessibilityLabel;

@synthesize botRightLabel;
@synthesize botRightAccessibilityLabel;


- (id)initWithStyle: (UITableViewCellStyle)style reuseIdentifier: (NSString*)reuseIdentifier enlargeTopRightLabel: (BOOL)enlargeTopRightLabel
{
    if ((self = [super initWithStyle: style reuseIdentifier: reuseIdentifier]))
    {
        state = UITableViewCellStateDefaultMask;
        large = enlargeTopRightLabel;

        topLeftLabel = [[UILabel alloc] initWithFrame: CGRectZero];

        topLeftLabel.backgroundColor           = [UIColor clearColor];
        topLeftLabel.textColor                 = [UIColor blackColor];
        topLeftLabel.shadowColor               = [UIColor colorWithWhite: 1.0 alpha: (CGFloat)0.8];
        topLeftLabel.shadowOffset              = CGSizeMake (0.0, 1.0);
        topLeftLabel.highlightedTextColor      = [UIColor whiteColor];
        topLeftLabel.adjustsFontSizeToFitWidth = YES;
        topLeftLabel.font                      = [UIFont boldSystemFontOfSize: 22.0];
        topLeftLabel.minimumFontSize           = 12.0;
        [self.contentView addSubview: topLeftLabel];


        botLeftLabel = [[UILabel alloc] initWithFrame: CGRectZero];

        botLeftLabel.backgroundColor           = [UIColor clearColor];
        botLeftLabel.textColor                 = [UIColor darkGrayColor];
        botLeftLabel.shadowColor               = [UIColor colorWithWhite: 1.0 alpha: (CGFloat)0.8];
        botLeftLabel.shadowOffset              = CGSizeMake (0.0, 1.0);
        botLeftLabel.highlightedTextColor      = [UIColor whiteColor];
        botLeftLabel.adjustsFontSizeToFitWidth = YES;
        botLeftLabel.font                      = [UIFont boldSystemFontOfSize: 15.0];
        botLeftLabel.minimumFontSize           = 12.0;
        [self.contentView addSubview: botLeftLabel];


        topRightLabel = [[UILabel alloc] initWithFrame: CGRectZero];

        topRightLabel.backgroundColor           = [UIColor clearColor];
        topRightLabel.textColor                 = [UIColor blackColor];
        topRightLabel.shadowColor               = [UIColor colorWithWhite: 1.0 alpha: (CGFloat)0.8];
        topRightLabel.shadowOffset              = CGSizeMake (0.0, 1.0);
        topRightLabel.highlightedTextColor      = [UIColor whiteColor];
        topRightLabel.adjustsFontSizeToFitWidth = YES;
        topRightLabel.font                      = [UIFont boldSystemFontOfSize: large ? 28.0 : 22];
        topRightLabel.minimumFontSize           = 12.0;
        topRightLabel.textAlignment             = UITextAlignmentRight;
        [self.contentView addSubview: topRightLabel];


        botRightLabel = [[UILabel alloc] initWithFrame: CGRectZero];

        botRightLabel.backgroundColor           = [UIColor clearColor];
        botRightLabel.textColor                 = [UIColor darkGrayColor];
        botRightLabel.shadowColor               = [UIColor colorWithWhite: 1.0 alpha: (CGFloat)0.8];
        botRightLabel.shadowOffset              = CGSizeMake (0.0, 1.0);
        botRightLabel.highlightedTextColor      = [UIColor whiteColor];
        botRightLabel.adjustsFontSizeToFitWidth = YES;
        botRightLabel.font                      = [UIFont boldSystemFontOfSize: 15.0];
        botRightLabel.minimumFontSize           = 12.0;
        botRightLabel.textAlignment             = UITextAlignmentRight;
        [self.contentView addSubview: botRightLabel];

        UIImageView *imageView;

        imageView                   = [[UIImageView alloc] init];
        imageView.image             = [UIImage imageNamed: @"CellShade"];
        self.backgroundView         = imageView;

        imageView                   = [[UIImageView alloc] init];
        imageView.image             = [UIImage imageNamed: @"SelectedCellShade"];
        self.selectedBackgroundView = imageView;

        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return self;
}


- (NSString*)accessibilityLabel
{
    NSString *label = [NSString stringWithFormat: @"%@, %@",
                            (topLeftAccessibilityLabel) ? topLeftAccessibilityLabel : topLeftLabel.text,
                            (botLeftAccessibilityLabel) ? botLeftAccessibilityLabel : botLeftLabel.text];

    if (state == UITableViewCellStateDefaultMask)
    {
        if (topRightAccessibilityLabel)
            label = [label stringByAppendingFormat: @", %@", topRightAccessibilityLabel];

        if (botRightAccessibilityLabel)
            label = [label stringByAppendingFormat: @" %@",  botRightAccessibilityLabel];
    }

    return label;
}



// Disable text shadow in highlighted and selected states
- (void)updateLabelShadowOffset
{
    CGSize offset = ([self isHighlighted] || [self isSelected]) ? CGSizeZero : CGSizeMake (0.0, 1.0);

    topLeftLabel.shadowOffset  = offset;
    botLeftLabel.shadowOffset  = offset;
    topRightLabel.shadowOffset = offset;
    botRightLabel.shadowOffset = offset;
}


- (void)setHighlighted: (BOOL)highlighted animated: (BOOL)animated
{
    [super setHighlighted: highlighted animated: animated];
    [self updateLabelShadowOffset];
}


- (void)setSelected: (BOOL)selected animated: (BOOL)animated
{
    [super setSelected: selected animated: animated];
    [self updateLabelShadowOffset];
}


- (void)willTransitionToState: (UITableViewCellStateMask)newState
{
    // Remember the last state transition
    [super willTransitionToState: (state = newState)];
}


- (void)prepareForReuse
{
    [super prepareForReuse];

    // Reset to default state before reuse of cell
    state = UITableViewCellStateDefaultMask;
}


- (void)layoutSubviews
{
#   define MARGIN         10
#   define FAR_DISTANCE  130

    CGFloat width   = self.frame.size.width;
    CGFloat iStart  = large ?  17.0 :  22.0;
    CGFloat iWidth  = large ?  96.0 : 135.0;
    CGFloat iHeight = large ?  36.0 :  30.0;


    if (state == UITableViewCellStateDefaultMask)
    {
        // Add extra space for the disclosure accessory
        width -= 9 + MARGIN;

        topLeftLabel.frame  = CGRectMake (MARGIN,         20,      width - iWidth - 2*MARGIN, 30);
        botLeftLabel.frame  = CGRectMake (MARGIN,         52,      width - iWidth - 2*MARGIN, 20);
        topRightLabel.frame = CGRectMake (width - iWidth, iStart, iWidth - MARGIN,            iHeight);
        botRightLabel.frame = CGRectMake (width - iWidth, 52,     iWidth - MARGIN,            20);
    }
    else
    {
        CGFloat offset = MARGIN + ((state & UITableViewCellStateShowingDeleteConfirmationMask) ? 92 : 54);

        topLeftLabel.frame  = CGRectMake (MARGIN,               20,      width - offset - 2*MARGIN, 30);
        botLeftLabel.frame  = CGRectMake (MARGIN,               52,      width - offset - 2*MARGIN, 20);
        topRightLabel.frame = CGRectMake (width + FAR_DISTANCE, iStart, iWidth - MARGIN,            iHeight);
        botRightLabel.frame = CGRectMake (width + FAR_DISTANCE, 52,     iWidth - MARGIN,            20);
    }

    [super layoutSubviews];
}

@end
