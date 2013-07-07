// PageCell.m
//
// Kraftstoff


#import "PageCell.h"
#import "PageCellBackground.h"
#import "PageViewController.h"
#import "AppDelegate.h"


const CGFloat PageCellDefaultRowHeight = 44.0;


@implementation PageCell


+ (CGFloat)rowHeight
{
    return PageCellDefaultRowHeight;
}


+ (NSString *)reuseIdentifier
{
	return NSStringFromClass (self);
}


- (id)init
{
	if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[[self class] reuseIdentifier]]))
	{
		[self finishConstruction];

        self.detailTextLabel.hidden = YES;
	}

	return self;
}


- (void)prepareForReuse
{
    // Suppress default behaviour
}


- (void)finishConstruction
{
    // Overridepoint for subclasses
}


// (Re-)configure the cell with data
- (void)configureForData:(id)object viewController:(id)viewController tableView:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath
{
    if ([AppDelegate systemMajorVersion] < 7)
    {
        BOOL grouped = (tableView.style == UITableViewStyleGrouped);

        if (self.backgroundView == nil)
        {
            self.backgroundView = [[PageCellBackground alloc] initSelected:NO grouped:grouped];
            self.selectedBackgroundView = [[PageCellBackground alloc] initSelected:YES grouped:grouped];
        }

        if (grouped)
        {
            PageCellGroupPosition position = [PageCellBackground positionForIndexPath:indexPath inTableView:tableView];

            ((PageCellBackground*)self.backgroundView).position = position;
            ((PageCellBackground*)self.selectedBackgroundView).position = position;
        }
    }
}


// Revert default behaviour of color change when cell is selected
- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
	[super setSelected:selected animated:animated];

    if ([AppDelegate systemMajorVersion] < 7)
    {
        UIColor *clearColor = [UIColor clearColor];

        if (! [self.textLabel.backgroundColor isEqual:clearColor])
            self.textLabel.backgroundColor = [UIColor clearColor];

        if (! [self.detailTextLabel.backgroundColor isEqual:clearColor])
            self.detailTextLabel.backgroundColor = [UIColor clearColor];
    }
}

@end
