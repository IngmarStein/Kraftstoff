// PageViewController.m
//
// Kraftstoff


#import "PageViewController.h"
#import "PageCell.h"
#import "PageCellDescription.h"
#import "AppDelegate.h"


@implementation PageViewController



#pragma mark -
#pragma mark View Resize on Keyboard Events (only when visible)



- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}


- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
}


- (void)keyboardWillShow:(NSNotification*)notification
{
    if (keyboardIsVisible == NO) {

        bottomInsetBeforeKeyboard = self.tableView.contentInset.bottom;
        keyboardIsVisible = YES;
    }

    [UIView animateWithDuration:[[notification userInfo][UIKeyboardAnimationDurationUserInfoKey] doubleValue]
                          delay:0.1
                        options:[[notification userInfo][UIKeyboardAnimationCurveUserInfoKey] integerValue]
                     animations:^{

                         CGRect kRect = [[notification userInfo][UIKeyboardFrameEndUserInfoKey] CGRectValue];

                         UIEdgeInsets insets = self.tableView.contentInset;
                         insets.bottom = kRect.size.height;
                         self.tableView.contentInset = insets;
                     }
                     completion:nil];
}


- (void)keyboardWillHide:(NSNotification*)notification
{
    keyboardIsVisible = NO;
}



#pragma mark -
#pragma mark Dismissing the Keyboard



- (void)dismissKeyboardWithCompletion:(void (^)(void))completion
{
    BOOL scrollToTop = (self.tableView.contentOffset.y > 0.0);
    
    [UIView animateWithDuration:scrollToTop ? 0.25 : 0.15
                     animations: ^{
                         
                         NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
                         
                         if (indexPath)
                             [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
                         
                         if (scrollToTop)
                             [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                                                   atScrollPosition:UITableViewScrollPositionTop
                                                           animated:NO];

                         UIEdgeInsets insets = self.tableView.contentInset;
                         insets.bottom = bottomInsetBeforeKeyboard;
                         self.tableView.contentInset = insets;
                     }
                     completion: ^(BOOL finished){
                         
                         [self.view endEditing:YES];
                         completion();
                     }];
}



#pragma mark -
#pragma mark Access to Table Cells



- (PageCellDescription*)cellDescriptionForRow:(NSInteger)rowIndex inSection:(NSInteger)sectionIndex
{
    if (tableSections.count <= sectionIndex)
        return nil;

    NSArray *section = tableSections[sectionIndex];

    if (section.count <= rowIndex)
        return nil;

    return section[rowIndex];
}


- (Class)classForRow:(NSInteger)rowIndex inSection:(NSInteger)sectionIndex
{
    return [[self cellDescriptionForRow:rowIndex inSection:sectionIndex] cellClass];
}


- (id)dataForRow:(NSInteger)rowIndex inSection:(NSInteger)sectionIndex
{
    return [[self cellDescriptionForRow:rowIndex inSection:sectionIndex] cellData];
}


- (void)setData:(id)object forRow:(NSInteger)rowIndex inSection:(NSInteger)sectionIndex
{
    [[self cellDescriptionForRow:rowIndex inSection:sectionIndex] setCellData:object];

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex];
    PageCell *cell = (PageCell*)[self.tableView cellForRowAtIndexPath:indexPath];

    [cell configureForData:object viewController:self tableView:self.tableView indexPath:indexPath];
}



#pragma mark -
#pragma mark Access to Table Sections



- (void)addSectionAtIndex:(NSInteger)sectionIndex withAnimation:(UITableViewRowAnimation)animation
{
    if (tableSections == nil)
        tableSections = [[NSMutableArray alloc] init];

    if (sectionIndex > [tableSections count])
        sectionIndex = [tableSections count];

    [tableSections insertObject:[[NSMutableArray alloc] init] atIndex:sectionIndex];

    if (animation != UITableViewRowAnimationNone)
        [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:animation];

    [self headerSectionsReordered];
}


- (void)removeSectionAtIndex:(NSInteger)sectionIndex withAnimation:(UITableViewRowAnimation)animation
{
    if (sectionIndex < [tableSections count]) {

        [tableSections removeObjectAtIndex:sectionIndex];
        [self headerSectionsReordered];

        if (animation != UITableViewRowAnimationNone)
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:animation];
    }
}


- (void)removeAllSectionsWithAnimation:(UITableViewRowAnimation)animation
{
    NSIndexSet *allSections = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange (0, [tableSections count])];

    [tableSections removeAllObjects];
    [self headerSectionsReordered];

    if (animation != UITableViewRowAnimationNone)
        [self.tableView deleteSections:allSections withRowAnimation:animation];
}



#pragma mark -
#pragma mark Access to Table Rows



- (void)addRowAtIndex:(NSInteger)rowIndex
            inSection:(NSInteger)sectionIndex
            cellClass:(Class)class
             cellData:(id)data
        withAnimation:(UITableViewRowAnimation)animation
{
    // Get valid section index and section
    if (tableSections == nil)
        tableSections = [[NSMutableArray alloc] init];

    if ([tableSections count] == 0)
        [self addSectionAtIndex:0 withAnimation:animation];

    if (sectionIndex > [tableSections count] - 1)
        sectionIndex = [tableSections count] - 1;

    NSMutableArray *tableSection = tableSections[sectionIndex];

    // Get valid row index
    if (rowIndex > [tableSection count])
        rowIndex = [tableSection count];

    // Store cell description
    PageCellDescription *description = [[PageCellDescription alloc] initWithCellClass:class andData:data];
    [tableSection insertObject:description atIndex:rowIndex];

    if (animation != UITableViewRowAnimationNone) {

        // If necessary update position for former bottom row of the section
        if (self.tableView.style == UITableViewStyleGrouped)
            if (rowIndex == [tableSection count] - 1 && rowIndex > 0)
                [self setData:[self dataForRow:rowIndex-1 inSection:sectionIndex]
                       forRow:rowIndex-1
                    inSection:sectionIndex];

        // Add row to table
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex];
        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:animation];
    }
}



- (void)removeRowAtIndex:(NSInteger)rowIndex
               inSection:(NSInteger)sectionIndex
           withAnimation:(UITableViewRowAnimation)animation
{
    if (sectionIndex < [tableSections count]) {

        NSMutableArray *tableSection = tableSections[sectionIndex];

        if (rowIndex < [tableSection count]) {

            [tableSection removeObjectAtIndex:rowIndex];

            if (animation != UITableViewRowAnimationNone) {

                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex];
                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:animation];
            }
        }
    }
}



#pragma mark -
#pragma mark Properties

@synthesize tableView = _tableView;

- (UITableView *)tableView
{
    return _tableView;
}


- (void)setTableView:(UITableView *)newTableView
{
    _tableView = newTableView;

    [_tableView setDelegate:self];
    [_tableView setDataSource:self];

    if (!self.nibName && !self.view)
        self.view = newTableView;
}


@synthesize constantRowHeight = _constantRowHeight;

- (void)setConstantRowHeight:(BOOL)newValue
{
    _constantRowHeight = newValue;

    // Force change of delegate to indicate changes
    self.tableView.delegate = nil;
    self.tableView.delegate = self;
}


@synthesize useCustomHeaders = _useCustomHeaders;

- (void)setUseCustomHeaders:(BOOL)newValue
{
    _useCustomHeaders = newValue;

    // Force change of delegate to indicate changes
    self.tableView.delegate = nil;
    self.tableView.delegate = self;
}


- (BOOL)respondsToSelector:(SEL)aSelector
{
    if (aSelector == @selector(tableView:heightForRowAtIndexPath:))
        return !self.constantRowHeight;

    if (aSelector == @selector(tableView:viewForHeaderInSection:) || aSelector == @selector(tableView:heightForHeaderInSection:))
        return _useCustomHeaders;

    return [super respondsToSelector:aSelector];
}



#pragma mark -
#pragma mark UITableViewDelegate



- (void)headerSectionsReordered
{
    headerViews = nil;
}


- (UIView *)tableView:(UITableView *)aTableView viewForHeaderInSection:(NSInteger)section
{
    return nil;
}


- (CGFloat)tableView:(UITableView *)aTableView heightForHeaderInSection:(NSInteger)section
{
    NSString *title = [self tableView:aTableView titleForHeaderInSection:section];

    if ([title length] == 0)
        return 0;

    return [[self tableView:aTableView viewForHeaderInSection:section] bounds].size.height;
}


- (CGFloat)tableView:(UITableView *)aTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [[self classForRow:indexPath.row inSection:indexPath.section] rowHeight];
}



#pragma mark -
#pragma mark UITableViewDataSource



- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView
{
    return [tableSections count];
}


- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
    if (tableSections == nil)
        return 0;

    return [tableSections[section] count];
}


- (NSString *)tableView:(UITableView *)aTableView titleForHeaderInSection:(NSInteger)section
{
    return nil;
}


- (UITableViewCell*)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PageCellDescription *description = [self cellDescriptionForRow:indexPath.row inSection:indexPath.section];

    PageCell *cell = (PageCell*)[aTableView dequeueReusableCellWithIdentifier:[description.cellClass reuseIdentifier]];

    if (cell == nil)
        cell = [[description.cellClass alloc] init];

    [cell configureForData:description.cellData
            viewController:self
                 tableView:aTableView
                 indexPath:indexPath];

    return cell;
}



#pragma mark -
#pragma mark Memory Management



- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
