// PageCell.h
//
// Kraftstoff


@interface PageCell : UITableViewCell {}

+ (CGFloat)rowHeight;

+ (NSString*)reuseIdentifier;

// Overridepoint for subclasses: called once after allocation of cells
- (void)finishConstruction;

// (Re-)configure the cell with data
- (void)configureForData: (id)object viewController: (id)viewController tableView: (UITableView*)tableView indexPath: (NSIndexPath*)indexPath;

@end
