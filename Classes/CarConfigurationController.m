// CarConfigurationController.m
//
// Kraftstoff


#import "CarConfigurationController.h"
#import "TextEditTableCell.h"
#import "NumberEditTableCell.h"
#import "PickerTableCell.h"
#import "AppDelegate.h"



@interface CarConfigurationController (private)

- (void)createTableContents;
- (void)recreateTableContents;
- (void)recreateOdometerRowWithAnimation: (UITableViewRowAnimation)animation;

- (void)selectRowAtIndexPath: (NSIndexPath*)path;

- (void)dismissKeyboardWithCompletion: (void (^)(void))completion;

- (void)actionSheet: (UIActionSheet*)actionSheet clickedButtonAtIndex: (NSInteger)buttonIndex;
- (void)handleCancelCompletion: (id)sender;
- (void)handleSaveCompletion: (id)sender;

- (void)localeChangedCompletion: (id)previousSelection;
- (void)localeChanged: (id)object;

@end



@implementation CarConfigurationController


@synthesize editingTextField;
@synthesize navBar;

@synthesize name;
@synthesize plate;
@synthesize odometerUnit;
@synthesize odometer;
@synthesize fuelUnit;
@synthesize fuelConsumptionUnit;
@synthesize editing;

@synthesize delegate;



#pragma mark -
#pragma mark View Lifecycle



- (id)initWithNibName: (NSString*)nibName bundle: (NSBundle*)nibBundle
{
    if ((self = [super initWithNibName: nibName bundle: nibBundle]))
    {
        editing               = NO;
        mostRecentSelectedRow = 0;
    }

    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    // Add shadow layer onto the background image view
    UIView *imageView = [self.view viewWithTag: 100];

    [imageView.layer
        insertSublayer: [AppDelegate shadowWithFrame: CGRectMake (0.0, NavBarHeight, imageView.frame.size.width, LargeShadowHeight)
                                          darkFactor: 0.5
                                         lightFactor: 150.0 / 255.0
                                             inverse: NO]
               atIndex: 0];

    // Build table contents
    [self recreateTableContents];

    // Update navigation bar
    UINavigationItem *item = navBar.topItem;

    item.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone
                                                                            target: self
                                                                            action: @selector (handleSave:)];

    item.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemStop
                                                                            target: self
                                                                            action: @selector (handleCancel:)];

    item.title = (editing) ? _I18N (@"Edit Car") : _I18N (@"New Car");
    [navBar setItems: [NSArray arrayWithObject: item] animated: NO];

    // Observe locale changes
    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector (localeChanged:)
               name: NSCurrentLocaleDidChangeNotification
             object: nil];
}


- (void)viewDidAppear: (BOOL)animated
{
    [super viewDidAppear: animated];

    dataChanged = NO;

    [self selectRowAtIndexPath: [NSIndexPath indexPathForRow: 0 inSection: 0]];
}


- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    self.editingTextField = nil;
    self.navBar           = nil;

    [super viewDidUnload];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}


- (BOOL)shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}


- (void)localeChangedCompletion: (id)previousSelection
{
    [self.editingTextField resignFirstResponder];
    self.editingTextField = nil;

    [self recreateTableContents];
    [self selectRowAtIndexPath: previousSelection];
}


- (void)localeChanged: (id)object
{
    NSIndexPath *path = [self.tableView indexPathForSelectedRow];

    if (path)
        [self dismissKeyboardWithCompletion: ^{ [self localeChangedCompletion: path]; }];
    else
        [self localeChangedCompletion: path];
}


#pragma mark -
#pragma mark Creating the Table Rows



- (void)createOdometerRowWithAnimation: (UITableViewRowAnimation)animation
{
    NSString *suffix = [@" " stringByAppendingString: [AppDelegate odometerUnitString: [self.odometerUnit integerValue]]];

    if (odometer == nil)
        self.odometer = [NSDecimalNumber zero];

    [self addRowAtIndex: 3
              inSection: 0
              cellClass: [NumberEditTableCell class]
               cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                            _I18N (@"Odometer Reading"),           @"label",
                            suffix,                                @"suffix",
                            [AppDelegate sharedDistanceFormatter], @"formatter",
                            @"odometer",                           @"valueIdentifier",
                            nil]
          withAnimation: animation];
}


- (void)createTableContents
{
    NSArray *pickerLabels;

    [self addSectionAtIndex: 0 withAnimation: UITableViewRowAnimationNone];

    if (name == nil)
        self.name = @"";

    [self addRowAtIndex: 0
              inSection: 0
              cellClass: [TextEditTableCell class]
               cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                            _I18N (@"Name"),  @"label",
                            @"name",          @"valueIdentifier",
                            nil]
          withAnimation: UITableViewRowAnimationNone];

    if (plate == nil)
        self.plate = @"";

    [self addRowAtIndex: 1
              inSection: 0
              cellClass: [TextEditTableCell class]
               cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                            _I18N (@"Number Plate"),        @"label",
                            @"plate",                       @"valueIdentifier",
                            [NSNumber numberWithBool: YES], @"autocapitalizeAll",
                            nil]
          withAnimation: UITableViewRowAnimationNone];


    if (odometerUnit == nil)
        self.odometerUnit = [NSNumber numberWithInteger: [AppDelegate odometerUnitFromLocale]];

    pickerLabels = [NSArray arrayWithObjects:
                        [AppDelegate odometerUnitDescription: KSDistanceKilometer],
                        [AppDelegate odometerUnitDescription: KSDistanceStatuteMile],
                        nil];

    [self addRowAtIndex: 2
              inSection: 0
              cellClass: [PickerTableCell class]
               cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                            _I18N (@"Odometer Type"), @"label",
                            @"odometerUnit",          @"valueIdentifier",
                            pickerLabels,             @"labels",
                            nil]
          withAnimation: UITableViewRowAnimationNone];


    [self createOdometerRowWithAnimation: UITableViewRowAnimationNone];


    if (fuelUnit == nil)
        self.fuelUnit = [NSNumber numberWithInteger: [AppDelegate fuelUnitFromLocale]];

    pickerLabels = [NSArray arrayWithObjects:
                        [AppDelegate fuelUnitDescription: KSVolumeLiter discernGallons: YES],
                        [AppDelegate fuelUnitDescription: KSVolumeGalUS discernGallons: YES],
                        [AppDelegate fuelUnitDescription: KSVolumeGalUK discernGallons: YES],
                        nil];

    [self addRowAtIndex: 4
              inSection: 0
              cellClass: [PickerTableCell class]
               cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                            _I18N (@"Fuel Unit"), @"label",
                            @"fuelUnit",          @"valueIdentifier",
                            pickerLabels,         @"labels",
                            nil]
          withAnimation: UITableViewRowAnimationNone];


    if (fuelConsumptionUnit == nil)
        self.fuelConsumptionUnit = [NSNumber numberWithInteger: [AppDelegate fuelConsumptionUnitFromLocale]];

    pickerLabels = [NSArray arrayWithObjects:
                        [AppDelegate consumptionUnitDescription: KSFuelConsumptionLitersPer100km],
                        [AppDelegate consumptionUnitDescription: KSFuelConsumptionKilometersPerLiter],
                        [AppDelegate consumptionUnitDescription: KSFuelConsumptionMilesPerGallonUS],
                        [AppDelegate consumptionUnitDescription: KSFuelConsumptionMilesPerGallonUK],
                        nil];

    [self addRowAtIndex: 5
              inSection: 0
              cellClass: [PickerTableCell class]
               cellData: [NSDictionary dictionaryWithObjectsAndKeys:
                            _I18N (@"Mileage"),     @"label",
                            @"fuelConsumptionUnit", @"valueIdentifier",
                            pickerLabels,           @"labels",
                            nil]
          withAnimation: UITableViewRowAnimationNone];
}


- (void)recreateTableContents
{
    [self removeAllSectionsWithAnimation: UITableViewRowAnimationNone];
    [self createTableContents];
    [self.tableView reloadData];
}


- (void)recreateOdometerRowWithAnimation: (UITableViewRowAnimation)animation
{
    [self removeRowAtIndex: 3 inSection: 0 withAnimation: UITableViewRowAnimationNone];
    [self createOdometerRowWithAnimation: UITableViewRowAnimationNone];

    if (animation == UITableViewRowAnimationNone)
        [self.tableView reloadData];
    else
        [self.tableView reloadRowsAtIndexPaths: [NSArray arrayWithObject: [NSIndexPath indexPathForRow: 3 inSection: 0]]
                              withRowAnimation: animation];
}



#pragma mark -
#pragma mark Programatically Selecting Table Rows



- (void)selectRowAtIndexPath: (NSIndexPath*)path
{
    if (path)
    {
        [self.tableView selectRowAtIndexPath: path animated: NO scrollPosition: UITableViewScrollPositionNone];
        [self tableView: self.tableView didSelectRowAtIndexPath: path];
    }
}



#pragma mark -
#pragma mark Frame Computation for Keyboard Animations



- (CGRect)frameForKeyboardApprearingInRect: (CGRect)keyboardRect
{
    CGRect frame = [self.view viewWithTag: 1].frame;

    frame.size.height = self.view.frame.size.height - NavBarHeight - keyboardRect.size.height;
    return frame;
}


- (CGRect)frameForDisappearingKeyboard
{
    CGRect frame = [self.view viewWithTag: 1].frame;

    frame.size.height = self.view.frame.size.height - NavBarHeight;
    return frame;
}



#pragma mark -
#pragma mark Button Actions



- (void)dismissKeyboardWithCompletion: (void (^)(void))completion
{
    BOOL scrollToTop = (self.tableView.contentOffset.y > 0.0);

    [UIView animateWithDuration: scrollToTop ? 0.2 : 0.1
                     animations: ^{

                         // Deselect row and scroll table to the top
                         [self.tableView deselectRowAtIndexPath: [self.tableView indexPathForSelectedRow] animated: NO];

                         if (scrollToTop)
                             [self.tableView scrollToRowAtIndexPath: [NSIndexPath indexPathForRow: 0 inSection: 0]
                                                   atScrollPosition: UITableViewScrollPositionTop
                                                           animated: NO];
                     }
                     completion: ^(BOOL finished){

                         completion ();
                     }];
}


- (void)actionSheet: (UIActionSheet*)actionSheet clickedButtonAtIndex: (NSInteger)buttonIndex
{
    if (buttonIndex != actionSheet.cancelButtonIndex)
        [delegate carConfigurationController: self didFinishWithResult: CarConfigurationCanceled];
    else
        [self selectRowAtIndexPath: [NSIndexPath indexPathForRow: mostRecentSelectedRow inSection: 0]];
}


- (void)handleCancelCompletion: (id)sender
{
    [self.editingTextField resignFirstResponder];
    self.editingTextField = nil;

    BOOL showAlertPanel = YES;

    // In editing mode show alert panel on any change
    if (editing == YES && dataChanged == NO)
        showAlertPanel = NO;

    // In create mode show alert panel on textual changes
    if (editing == NO
        && [name isEqualToString: @""] == YES
        && [plate isEqualToString: @""] == YES
        && [odometer compare: [NSDecimalNumber zero]] == NSOrderedSame)
        showAlertPanel = NO;

    if (showAlertPanel)
    {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle: editing ? _I18N (@"Revert Changes for Car?")
                                                                             : _I18N (@"Delete the newly created Car?")
                                                           delegate: self
                                                  cancelButtonTitle: _I18N (@"Cancel")
                                             destructiveButtonTitle: editing ? _I18N (@"Revert")
                                                                             : _I18N (@"Delete")
                                                  otherButtonTitles: nil];

        sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;

        [sheet showInView: [self.view viewWithTag: 100]];
    }
    else
        [delegate carConfigurationController: self didFinishWithResult: CarConfigurationCanceled];
}


- (IBAction)handleCancel: (id)sender
{
    // Remember currently selected row in case the action shhet gets canceled
    mostRecentSelectedRow = [self.tableView indexPathForSelectedRow].row;

    [self dismissKeyboardWithCompletion: ^{ [self handleCancelCompletion: self]; }];
}


- (void)handleSaveCompletion: (id)sender
{
    [self.editingTextField resignFirstResponder];
    self.editingTextField = nil;

    [delegate carConfigurationController: self
                     didFinishWithResult: editing ? CarConfigurationEditSucceded
                                                  : CarConfigurationCreateSucceded];
}


- (IBAction)handleSave: (id)sender
{
    [self dismissKeyboardWithCompletion: ^{ [self handleSaveCompletion: self]; }];
}



#pragma mark -
#pragma mark EditablePageCellDelegate



- (void)focusNextFieldForValueIdentifier: (NSString*)valueIdentifier
{
    if ([valueIdentifier isEqualToString: @"name"])
        [self selectRowAtIndexPath: [NSIndexPath indexPathForRow: 1 inSection: 0]];
    else
        [self selectRowAtIndexPath: [NSIndexPath indexPathForRow: 2 inSection: 0]];
}


- (id)valueForIdentifier: (NSString*)valueIdentifier
{
    if ([valueIdentifier isEqualToString: @"name"])
        return name;
    else if ([valueIdentifier isEqualToString: @"plate"])
        return plate;
    else if ([valueIdentifier isEqualToString: @"odometerUnit"])
        return odometerUnit;
    else if ([valueIdentifier isEqualToString: @"odometer"])
        return odometer;
    else if ([valueIdentifier isEqualToString: @"fuelUnit"])
        return fuelUnit;
    else if ([valueIdentifier isEqualToString: @"fuelConsumptionUnit"])
        return fuelConsumptionUnit;

    return nil;
}


- (void)valueChanged: (id)newValue identifier: (NSString*)valueIdentifier
{
    if ([newValue isKindOfClass: [NSString class]])
    {
        if ([valueIdentifier isEqualToString: @"name"])
            self.name  = (NSString*)newValue;

        else if ([valueIdentifier isEqualToString: @"plate"])
            self.plate = (NSString*)newValue;
    }

    else if ([newValue isKindOfClass: [NSDecimalNumber class]])
    {
        if ([valueIdentifier isEqualToString: @"odometer"])
            self.odometer = (NSDecimalNumber*)newValue;
    }

    else if ([newValue isKindOfClass: [NSNumber class]])
    {
        if ([valueIdentifier isEqualToString: @"odometerUnit"])
        {
            KSDistance oldUnit = [self.odometerUnit integerValue];
            KSDistance newUnit = [(NSNumber*)newValue integerValue];

            if (oldUnit != newUnit)
            {
                self.odometerUnit = (NSNumber*)newValue;
                self.odometer     = [AppDelegate distanceForKilometers: [AppDelegate kilometersForDistance: self.odometer
                                                                                                  withUnit: oldUnit]
                                                              withUnit: newUnit];

                [self recreateOdometerRowWithAnimation: newUnit
                                                            ? UITableViewRowAnimationRight
                                                            : UITableViewRowAnimationLeft];
            }
        }

        else if ([valueIdentifier isEqualToString: @"fuelUnit"])
            self.fuelUnit = (NSNumber*)newValue;

        else if ([valueIdentifier isEqualToString: @"fuelConsumptionUnit"])
            self.fuelConsumptionUnit = (NSNumber*)newValue;
    }

    dataChanged = YES;
}



#pragma mark -
#pragma mark UITableViewDelegate



// Activate edit fields for selected rows, track the currently active textfield
- (void)tableView: (UITableView*)tableView didSelectRowAtIndexPath: (NSIndexPath*)indexPath
{
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath: indexPath];


    self.editingTextField = nil;

    if ([cell isKindOfClass: [TextEditTableCell class]])
        self.editingTextField = [(TextEditTableCell*)cell textField];

    else if ([cell isKindOfClass: [NumberEditTableCell class]])
        self.editingTextField = [(NumberEditTableCell*)cell textField];

    else if ([cell isKindOfClass: [PickerTableCell class]])
        self.editingTextField = [(PickerTableCell*)cell textField];


    if (self.editingTextField)
    {
        self.editingTextField.userInteractionEnabled = YES;
        [self.editingTextField becomeFirstResponder];

        [self.tableView scrollToRowAtIndexPath: indexPath
                              atScrollPosition: UITableViewScrollPositionMiddle
                                      animated: YES];
    }
    else
        [tableView deselectRowAtIndexPath: indexPath animated: NO];
}

@end
