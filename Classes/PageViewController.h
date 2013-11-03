// PageViewController.h
//
// Kraftstoff


@interface PageViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
{
    NSMutableArray *tableSections;
    NSMutableArray *headerViews;

    BOOL    keyboardIsVisible;
    CGFloat bottomInsetBeforeKeyboard;
}

@property (nonatomic, weak)   IBOutlet UITableView *tableView;
@property (nonatomic, assign) BOOL constantRowHeight;
@property (nonatomic, assign) BOOL useCustomHeaders;


#pragma mark Access to Table Cells

- (Class)classForRow:(NSInteger)rowIndex inSection:(NSInteger)sectionIndex;

- (id)dataForRow:(NSInteger)rowIndex inSection:(NSInteger)sectionIndex;

- (void)setData:(id)object forRow:(NSInteger)rowIndex inSection:(NSInteger)sectionIndex;


#pragma mark Access to Table Sections

- (void)addSectionAtIndex:(NSInteger)sectionIndex withAnimation:(UITableViewRowAnimation)animation;

- (void)removeSectionAtIndex:(NSInteger)sectionIndex withAnimation:(UITableViewRowAnimation)animation;

- (void)removeAllSectionsWithAnimation:(UITableViewRowAnimation)animation;


#pragma mark Access to Table Rows

- (void)addRowAtIndex:(NSInteger)rowIndex
            inSection:(NSInteger)sectionIndex
            cellClass:(Class)cellClass
             cellData:(id)cellData
        withAnimation:(UITableViewRowAnimation)animation;

- (void)removeRowAtIndex:(NSInteger)rowIndex
               inSection:(NSInteger)sectionIndex
           withAnimation:(UITableViewRowAnimation)animation;


#pragma mark Keyboard Support

- (void)dismissKeyboardWithCompletion:(void (^)(void))completion;

@end
