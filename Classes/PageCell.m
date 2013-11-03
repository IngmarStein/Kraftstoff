// PageCell.m
//
// Kraftstoff


#import "PageCell.h"
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
	if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[[self class] reuseIdentifier]])) {

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


- (void)configureForData:(id)object viewController:(id)viewController tableView:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath
{
    // Overridepoint for subclasses
}

@end
