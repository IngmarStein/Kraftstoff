// ConsumptionTableCell.m
//
// Kraftstoff


#import "ConsumptionTableCell.h"
#import "ConsumptionLabel.h"
#import "AppDelegate.h"


// Standard cell geometry
static CGFloat const ConsumptionRowHeight = 50.0;
static CGFloat const cellHMargin          = 10.0;
static CGFloat const cellVMargin          =  1.0;


@implementation ConsumptionTableCell

@synthesize coloredLabel;


+ (CGFloat)rowHeight
{
    return ConsumptionRowHeight;
}


- (void)finishConstruction
{
	[super finishConstruction];

    self.selectionStyle = UITableViewCellSelectionStyleNone;

    coloredLabel = [[ConsumptionLabel alloc] initWithFrame:CGRectZero];

	coloredLabel.textAlignment             = NSTextAlignmentCenter;
    coloredLabel.adjustsFontSizeToFitWidth = YES;
	coloredLabel.font                      = [UIFont fontWithName:@"HelveticaNeue" size:20];
	coloredLabel.minimumScaleFactor        = 12.0/[coloredLabel.font pointSize];
    coloredLabel.backgroundColor           = [UIColor clearColor];
	coloredLabel.highlightedTextColor      = [UIColor colorWithWhite:0.5 alpha:1.0];
	coloredLabel.textColor                 = [UIColor blackColor];

    [self.contentView addSubview:coloredLabel];
}


- (void)configureForData:(id)dataObject viewController:(id)viewController tableView:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath
{
	[super configureForData:dataObject viewController:viewController tableView:tableView indexPath:indexPath];

    self.coloredLabel.text             = ((NSDictionary *)dataObject)[@"label"];
    self.coloredLabel.highlightStrings = ((NSDictionary *)dataObject)[@"highlightStrings"];
}


- (NSString *)accessibilityLabel
{
	return self.coloredLabel.text;
}


- (void)layoutSubviews
{
    [super layoutSubviews];

    CGSize size = self.contentView.frame.size;

    self.coloredLabel.frame = CGRectMake (cellHMargin, cellVMargin, size.width-2*cellHMargin, size.height-2*cellVMargin);
}

@end
