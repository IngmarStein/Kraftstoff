// PageViewController.m
//
// Kraftstoff


#import "PageViewController.h"
#import "PageCell.h"
#import "PageCellDescription.h"
#import "AppDelegate.h"


static CGFloat const PageViewSectionGroupHeaderHeight = 36.0;
static CGFloat const PageViewSectionPlainHeaderHeight = 22.0;
static CGFloat const PageViewSectionGroupHeaderMargin = 20.0;
static CGFloat const PageViewSectionPlainHeaderMargin =  5.0;


@interface PageViewController (private)

- (PageCellDescription*)cellDescriptionForRow: (NSInteger)rowIndex inSection: (NSInteger)sectionIndex;
- (void)headerSectionsReordered;

@end


@implementation PageViewController



#pragma mark -
#pragma mark UITableViewController



@synthesize tableView;

- (UITableView*)tableView
{
    return tableView;
}


- (void)setTableView: (UITableView*)newTableView
{
    [newTableView retain];
    [tableView release];
    tableView = newTableView;

    [tableView setDelegate: self];
    [tableView setDataSource: self];

    if (!self.nibName && !self.view)
    {
        self.view = newTableView;
    }
}


- (BOOL)shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}


- (void)loadView
{
    if (self.nibName && [[NSBundle mainBundle] URLForResource: self.nibName withExtension: @"nib"])
    {
        [super loadView];
    }
    else
    {
        UITableView *aTableView = [[UITableView alloc] initWithFrame: CGRectZero style: UITableViewStyleGrouped];

        self.view      = aTableView;
        self.tableView = aTableView;

        [aTableView release];
    }
}


- (void)viewDidLoad
{
    keyboardIsVisible = NO;
}


- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    tableView.delegate   = nil;
    tableView.dataSource = nil;

    [tableView release], tableView = nil;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    tableView.delegate   = nil;
    tableView.dataSource = nil;

    [tableView     release], tableView     = nil;
    [tableSections release], tableSections = nil;
    [headerViews   release], headerViews   = nil;

    [super dealloc];
}



#pragma mark -
#pragma mark Frame Computation for Keyboard Animations



- (CGRect)frameForKeyboardApprearingInRect: (CGRect)keyboardRect
{
    CGRect frame = [self.view viewWithTag: 1].frame;

    frame.size.height = self.view.frame.size.height + TabBarHeight - keyboardRect.size.height;
    return frame;
}


- (CGRect)frameForDisappearingKeyboard
{
    return self.view.frame;
}



#pragma mark -
#pragma mark View Resize on Keyboard Events (only when visible)



- (void)viewWillAppear: (BOOL)animated
{
    [super viewWillAppear: animated];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector (keyboardWillShow:)
                                                 name: UIKeyboardWillShowNotification
                                               object: nil];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector (keyboardWillHide:)
                                                 name: UIKeyboardWillHideNotification
                                               object: nil];
}


- (void)viewWillDisappear: (BOOL)animated
{
    [super viewWillDisappear: animated];

    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: UIKeyboardWillShowNotification
                                                  object: nil];

    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: UIKeyboardWillHideNotification
                                                  object: nil];
}


- (void)keyboardWillShow: (NSNotification*)notification
{
    UIView *view = [self.view viewWithTag: 1];
    CGRect kRect = [[[notification userInfo] objectForKey: UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect frame = [self frameForKeyboardApprearingInRect: kRect];

    [UIView animateWithDuration: [[[notification userInfo] objectForKey: UIKeyboardAnimationDurationUserInfoKey] doubleValue]
                     animations: ^{ view.frame = frame; }];

    keyboardIsVisible = YES;
}


- (void)keyboardWillHide: (NSNotification*)notification
{
    UIView *view = [self.view viewWithTag: 1];
    CGRect frame = [self frameForDisappearingKeyboard];

    [UIView animateWithDuration: [[[notification userInfo] objectForKey: UIKeyboardAnimationDurationUserInfoKey] doubleValue]
                     animations: ^{ view.frame = frame; }];

    keyboardIsVisible = NO;
}



#pragma mark -
#pragma mark Access to Table Cells



- (PageCellDescription*)cellDescriptionForRow: (NSInteger)rowIndex inSection: (NSInteger)sectionIndex
{
    if ([tableSections count] <= sectionIndex)
        return nil;

    NSArray *section = [tableSections objectAtIndex: sectionIndex];

    if ([section count] <= rowIndex)
        return nil;

    return [section objectAtIndex: rowIndex];
}


- (Class)classForRow: (NSInteger)rowIndex inSection: (NSInteger)sectionIndex
{
    return [[self cellDescriptionForRow: rowIndex inSection: sectionIndex] cellClass];
}


- (id)dataForRow: (NSInteger)rowIndex inSection: (NSInteger)sectionIndex
{
    return [[self cellDescriptionForRow: rowIndex inSection: sectionIndex] cellData];
}


- (void)setData: (id)object forRow: (NSInteger)rowIndex inSection: (NSInteger)sectionIndex
{
    [[self cellDescriptionForRow: rowIndex inSection: sectionIndex] setCellData: object];

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow: rowIndex inSection: sectionIndex];
    PageCell *cell = (PageCell*)[self.tableView cellForRowAtIndexPath: indexPath];

    [cell configureForData: object viewController: self tableView: self.tableView indexPath: indexPath];
}



#pragma mark -
#pragma mark Access to Table Sections



- (void)addSectionAtIndex: (NSInteger)sectionIndex withAnimation: (UITableViewRowAnimation)animation
{
    if (tableSections == nil)
        tableSections = [[NSMutableArray alloc] init];

    if (sectionIndex > [tableSections count])
        sectionIndex = [tableSections count];

    [tableSections insertObject: [[[NSMutableArray alloc] init] autorelease] atIndex: sectionIndex];

    if (animation != UITableViewRowAnimationNone)
        [self.tableView insertSections: [NSIndexSet indexSetWithIndex: sectionIndex] withRowAnimation: animation];

    [self headerSectionsReordered];
}


- (void)removeSectionAtIndex: (NSInteger)sectionIndex withAnimation: (UITableViewRowAnimation)animation
{
    if (sectionIndex < [tableSections count])
    {
        [tableSections removeObjectAtIndex: sectionIndex];
        [self headerSectionsReordered];

        if (animation != UITableViewRowAnimationNone)
            [self.tableView deleteSections: [NSIndexSet indexSetWithIndex: sectionIndex] withRowAnimation: animation];
    }
}


- (void)removeAllSectionsWithAnimation: (UITableViewRowAnimation)animation
{
    NSIndexSet *allSections = [NSIndexSet indexSetWithIndexesInRange: NSMakeRange (0, [tableSections count])];

    [tableSections removeAllObjects];
    [self headerSectionsReordered];

    if (animation != UITableViewRowAnimationNone)
        [self.tableView deleteSections: allSections withRowAnimation: animation];
}



#pragma mark -
#pragma mark Access to Table Rows



- (void)addRowAtIndex: (NSInteger)rowIndex
            inSection: (NSInteger)sectionIndex
            cellClass: (Class)class
             cellData: (id)data
        withAnimation: (UITableViewRowAnimation)animation
{
    // Get valid section index and section
    if (tableSections == nil)
        tableSections = [[NSMutableArray alloc] init];

    if ([tableSections count] == 0)
        [self addSectionAtIndex: 0 withAnimation: animation];

    if (sectionIndex > [tableSections count] - 1)
        sectionIndex = [tableSections count] - 1;

    NSMutableArray *tableSection = [tableSections objectAtIndex: sectionIndex];

    // Get valid row index
    if (rowIndex > [tableSection count])
        rowIndex = [tableSection count];

    // Store cell description
    PageCellDescription *description = [[PageCellDescription alloc] initWithCellClass: class andData: data];
    {
        [tableSection insertObject: description atIndex: rowIndex];
    }
    [description release];

    if (animation != UITableViewRowAnimationNone)
    {
        // If necessary update position for former bottom row of the section
        if (tableView.style == UITableViewStyleGrouped)
            if (rowIndex == [tableSection count] - 1 && rowIndex > 0)
                [self setData: [self dataForRow: rowIndex-1 inSection: sectionIndex]
                       forRow: rowIndex-1
                    inSection: sectionIndex];

        // Add row to table
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow: rowIndex inSection: sectionIndex];
        [self.tableView insertRowsAtIndexPaths: [NSArray arrayWithObject: indexPath] withRowAnimation: animation];
    }
}



- (void)removeRowAtIndex: (NSInteger)rowIndex
               inSection: (NSInteger)sectionIndex
           withAnimation: (UITableViewRowAnimation)animation
{
    if (sectionIndex < [tableSections count])
    {
        NSMutableArray *tableSection = [tableSections objectAtIndex: sectionIndex];

        if (rowIndex < [tableSection count])
        {
            [tableSection removeObjectAtIndex: rowIndex];

            if (animation != UITableViewRowAnimationNone)
            {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow: rowIndex inSection: sectionIndex];
                [self.tableView deleteRowsAtIndexPaths: [NSArray arrayWithObject: indexPath] withRowAnimation: animation];
            }
        }
    }
}



#pragma mark -
#pragma mark Properties



@synthesize constantRowHeight;

- (void)setConstantRowHeight: (BOOL)newValue
{
    constantRowHeight = newValue;

    // Force change of delegate to indicate changes
    tableView.delegate = nil;
    tableView.delegate = self;
}


@synthesize useCustomHeaders;

- (void)setUseCustomHeaders: (BOOL)newValue
{
    useCustomHeaders = newValue;

    // Force change of delegate to indicate changes
    tableView.delegate = nil;
    tableView.delegate = self;
}


- (BOOL)respondsToSelector: (SEL)aSelector
{
    if (aSelector == @selector (tableView:heightForRowAtIndexPath:))
        return !constantRowHeight;

    if (aSelector == @selector (tableView:viewForHeaderInSection:) ||
        aSelector == @selector (tableView:heightForHeaderInSection:))
    {
        return useCustomHeaders;
    }

    return [super respondsToSelector: aSelector];
}



#pragma mark -
#pragma mark UITableViewDelegate



- (void)headerSectionsReordered
{
    [headerViews release];
    headerViews = nil;
}


- (UIView*)tableView: (UITableView*)aTableView viewForHeaderInSection: (NSInteger)section
{
    NSString *title = [self tableView: aTableView titleForHeaderInSection: section];

    if ([title length] == 0)
        return nil;

    if ([headerViews count] != [tableSections count])
    {
        if (headerViews == nil)
            headerViews = [[NSMutableArray alloc] initWithCapacity: [tableSections count]];

        // Build Headerviews on demand
        while ([headerViews count] <= section)
        {
            BOOL isGrouped = (tableView.style == UITableViewStyleGrouped);

            CGRect frame = CGRectMake (0, 0,
                                       tableView.bounds.size.width,
                                       isGrouped ? PageViewSectionGroupHeaderHeight
                                                 : PageViewSectionPlainHeaderHeight);

            UIView *headerView = [[[UIView alloc] initWithFrame: frame] autorelease];

            headerView.backgroundColor =
                isGrouped ?
                    [UIColor clearColor] :
                    [UIColor colorWithRed:0.46 green:0.52 blue:0.56 alpha:0.5];

            frame.origin.x    = isGrouped ? PageViewSectionGroupHeaderMargin : PageViewSectionPlainHeaderMargin;
            frame.size.width -= 2.0 * frame.origin.x;

            UILabel *label = [[[UILabel alloc] initWithFrame: frame] autorelease];

            label.text                      = [self tableView: aTableView titleForHeaderInSection: [headerViews count]];
            label.backgroundColor           = [UIColor clearColor];
            label.textColor                 = isGrouped ? [UIColor colorWithRed:0.3 green:0.33 blue:0.43 alpha:1.0] : [UIColor whiteColor];
            label.shadowColor               = isGrouped ? [UIColor whiteColor] : [UIColor darkGrayColor];
            label.shadowOffset              = CGSizeMake (0, 1.0);
            label.font                      = [UIFont boldSystemFontOfSize:[UIFont labelFontSize] + (isGrouped ? 0 : 1)];
            label.lineBreakMode             = UILineBreakModeMiddleTruncation;
            label.adjustsFontSizeToFitWidth = YES;
            label.minimumFontSize           = 12.0;

            [headerView addSubview: label];
            [headerViews addObject: headerView];
        }
    }

    return [headerViews objectAtIndex:section];
}


- (CGFloat)tableView: (UITableView*)aTableView heightForHeaderInSection: (NSInteger)section
{
    NSString *title = [self tableView: aTableView titleForHeaderInSection: section];

    if ([title length] == 0)
        return 0;

    return [[self tableView: aTableView viewForHeaderInSection: section] bounds].size.height;
}


- (CGFloat)tableView: (UITableView*)aTableView heightForRowAtIndexPath: (NSIndexPath*)indexPath
{
    return [[self classForRow: indexPath.row inSection: indexPath.section] rowHeight];
}



#pragma mark -
#pragma mark UITableViewDataSource



- (NSInteger)numberOfSectionsInTableView: (UITableView*)aTableView
{
    return [tableSections count];
}


- (NSInteger)tableView: (UITableView*)aTableView numberOfRowsInSection: (NSInteger)section
{
    if (tableSections == nil)
        return 0;

    return [[tableSections objectAtIndex: section] count];
}


- (NSString *)tableView: (UITableView*)aTableView titleForHeaderInSection: (NSInteger)section
{
    return nil;
}


- (UITableViewCell*)tableView: (UITableView*)aTableView cellForRowAtIndexPath: (NSIndexPath*)indexPath
{
    PageCellDescription *description = [self cellDescriptionForRow: indexPath.row inSection: indexPath.section];

    PageCell *cell = (PageCell *)[tableView dequeueReusableCellWithIdentifier: [description.cellClass reuseIdentifier]];

    if (cell == nil)
        cell = [[[description.cellClass alloc] init] autorelease];

    [cell configureForData: description.cellData
            viewController: self
                 tableView: aTableView
                 indexPath: indexPath];

    return cell;
}

@end

