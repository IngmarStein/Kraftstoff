// ConsumptionTableCell.m
//
// Kraftstoff


#import "ConsumptionTableCell.h"
#import "AppDelegate.h"
#import "kraftstoff-Swift.h"

// Standard cell geometry
static CGFloat const ConsumptionRowHeight = 50.0;
static CGFloat const cellHMargin          = 10.0;
static CGFloat const cellVMargin          =  1.0;

@interface ConsumptionTableCell ()

@property (nonatomic, strong) ConsumptionLabel *coloredLabel;

@end

@implementation ConsumptionTableCell

+ (CGFloat)rowHeight
{
    return ConsumptionRowHeight;
}


- (void)finishConstruction
{
	[super finishConstruction];

    self.selectionStyle = UITableViewCellSelectionStyleNone;

    self.coloredLabel = [[ConsumptionLabel alloc] initWithFrame:CGRectZero];

	self.coloredLabel.textAlignment             = NSTextAlignmentCenter;
    self.coloredLabel.adjustsFontSizeToFitWidth = YES;
	self.coloredLabel.font                      = [UIFont fontWithName:@"HelveticaNeue" size:20];
	self.coloredLabel.minimumScaleFactor        = 12.0/[self.coloredLabel.font pointSize];
    self.coloredLabel.backgroundColor           = [UIColor clearColor];
	self.coloredLabel.highlightedTextColor      = [UIColor colorWithWhite:0.5 alpha:1.0];
	self.coloredLabel.textColor                 = [UIColor blackColor];

    [self.contentView addSubview:self.coloredLabel];
}


- (void)configureForData:(id)dataObject viewController:(id)viewController tableView:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath
{
	[super configureForData:dataObject viewController:viewController tableView:tableView indexPath:indexPath];

	NSDictionary *dictionary = (NSDictionary *)dataObject;
    self.coloredLabel.highlightStrings = dictionary[@"highlightStrings"];
	self.coloredLabel.text             = dictionary[@"label"];
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
