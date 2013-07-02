// ShadedTableViewCell.h
//
// Kraftstoff


#import "ShadedTableViewCell.h"
#import "AppDelegate.h"


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
        BOOL useOldStyle = ([AppDelegate systemMajorVersion] < 7);

        state = UITableViewCellStateDefaultMask;
        large = enlargeTopRightLabel;

        topLeftLabel = [[UILabel alloc] initWithFrame: CGRectZero];
        topLeftLabel.backgroundColor            = [UIColor clearColor];
        topLeftLabel.textColor                  = [UIColor blackColor];

        if (useOldStyle)
        {
            topLeftLabel.shadowColor            = [UIColor colorWithWhite: 1.0 alpha: (CGFloat)0.8];
            topLeftLabel.shadowOffset           = CGSizeMake (0.0, 1.0);
            topLeftLabel.highlightedTextColor   = [UIColor whiteColor];
        }

        topLeftLabel.adjustsFontSizeToFitWidth  = YES;
        topLeftLabel.font                       = (useOldStyle) ? [UIFont boldSystemFontOfSize: 22.0] : [UIFont fontWithName:@"HelveticaNeue-Light" size:22];
        topLeftLabel.minimumScaleFactor         = 12.0/[topLeftLabel.font pointSize];
        [self.contentView addSubview: topLeftLabel];


        botLeftLabel = [[UILabel alloc] initWithFrame: CGRectZero];
        botLeftLabel.backgroundColor            = [UIColor clearColor];
        botLeftLabel.textColor                  = (useOldStyle) ? [UIColor darkGrayColor] : [UIColor colorWithWhite:0.5 alpha:1.0];

        if (useOldStyle)
        {
            botLeftLabel.shadowColor            = [UIColor colorWithWhite: 1.0 alpha: (CGFloat)0.8];
            botLeftLabel.shadowOffset           = CGSizeMake (0.0, 1.0);
            botLeftLabel.highlightedTextColor   = [UIColor whiteColor];
        }

        botLeftLabel.adjustsFontSizeToFitWidth  = YES;
        botLeftLabel.font                       = (useOldStyle) ? [UIFont boldSystemFontOfSize: 15.0] : [UIFont fontWithName:@"HelveticaNeue-Light" size:15.0];
        botLeftLabel.minimumScaleFactor         = 12.0/[botLeftLabel.font pointSize];
        [self.contentView addSubview: botLeftLabel];


        topRightLabel = [[UILabel alloc] initWithFrame: CGRectZero];
        topRightLabel.backgroundColor           = [UIColor clearColor];
        topRightLabel.textColor                 = [UIColor blackColor];

        if (useOldStyle)
        {
            topRightLabel.shadowColor           = [UIColor colorWithWhite: 1.0 alpha: (CGFloat)0.8];
            topRightLabel.shadowOffset          = CGSizeMake (0.0, 1.0);
            topRightLabel.highlightedTextColor  = [UIColor whiteColor];
        }

        topRightLabel.adjustsFontSizeToFitWidth = YES;
        topRightLabel.font                      = (useOldStyle) ? [UIFont boldSystemFontOfSize: large ? 28.0 : 22.0] : [UIFont fontWithName:@"HelveticaNeue-Light" size:large ? 28.0 : 22.0];
        topRightLabel.minimumScaleFactor        = 12.0/[topRightLabel.font pointSize];
        topRightLabel.textAlignment             = NSTextAlignmentRight;
        [self.contentView addSubview: topRightLabel];


        botRightLabel = [[UILabel alloc] initWithFrame: CGRectZero];
        botRightLabel.backgroundColor           = [UIColor clearColor];
        botRightLabel.textColor                 = (useOldStyle) ? [UIColor darkGrayColor] : [UIColor colorWithWhite:0.5 alpha:1.0];

        if (useOldStyle)
        {
            botRightLabel.shadowColor           = [UIColor colorWithWhite: 1.0 alpha: (CGFloat)0.8];
            botRightLabel.shadowOffset          = CGSizeMake (0.0, 1.0);
            botRightLabel.highlightedTextColor  = [UIColor whiteColor];
        }

        botRightLabel.adjustsFontSizeToFitWidth = YES;
        botRightLabel.font                      = (useOldStyle) ? [UIFont boldSystemFontOfSize: 15.0] : [UIFont fontWithName:@"HelveticaNeue-Light" size:15.0];
        botRightLabel.minimumScaleFactor        = 12.0/[botRightLabel.font pointSize];
        botRightLabel.textAlignment             = NSTextAlignmentRight;
        [self.contentView addSubview: botRightLabel];

        UIImageView *imageView;

        imageView                   = [[UIImageView alloc] init];
        imageView.image             = [UIImage imageNamed: (useOldStyle) ? @"CellShade" : @"CellShadeFlat"];
        self.backgroundView         = imageView;

        imageView                   = [[UIImageView alloc] init];
        imageView.image             = [UIImage imageNamed: (useOldStyle) ? @"SelectedCellShade" : @"SelectedCellShadeFlat"];
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

    if ([AppDelegate systemMajorVersion] < 7)
        [self updateLabelShadowOffset];
}


- (void)setSelected: (BOOL)selected animated: (BOOL)animated
{
    [super setSelected: selected animated: animated];

    if ([AppDelegate systemMajorVersion] < 7)
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
    CGFloat margin = ([AppDelegate systemMajorVersion] >= 7 ? 15.0 : 10.0);

    // offset to compensate shift caused by editing control
    CGFloat editOffset = (state & UITableViewCellStateShowingEditControlMask) ? 32 : 0;

    // Space that can be distributed
    CGFloat width = self.frame.size.width - 9 - margin;

    // width of right labels
    CGFloat iWidth  = large ?  96.0 : 135.0;

    // y position and height of top right label
    CGFloat iYStart = large ?  17.0 :  20.0;
    CGFloat iHeight = large ?  36.0 :  30.0;

    // compute label frames
    topLeftLabel.frame  = CGRectMake (margin,                      20,       width - iWidth - 20, 30);
    botLeftLabel.frame  = CGRectMake (margin,                      52,       width - iWidth - 20, 20);
    topRightLabel.frame = CGRectMake (width - iWidth - editOffset, iYStart, iWidth - margin,      iHeight);
    botRightLabel.frame = CGRectMake (width - iWidth - editOffset, 52,      iWidth - margin,      20);

    // hide right labels in editing modes
    [UIView animateWithDuration: 0.5
                     animations: ^{

                         CGFloat newAlpha = 1.0;

                         if ([AppDelegate systemMajorVersion] >= 7)
                             newAlpha = (state & UITableViewCellStateShowingEditControlMask) ? 0.0 : 1.0;
                         else
                             newAlpha = (state != UITableViewCellStateDefaultMask) ? 0.0 : 1.0;

                         topRightLabel.alpha  = newAlpha;
                         botRightLabel.alpha  = newAlpha;
                     }];

    [super layoutSubviews];
}

@end
