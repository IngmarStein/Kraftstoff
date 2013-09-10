// CarConfigurationController.m
//
// Kraftstoff


#import "CarConfigurationController.h"
#import "TextEditTableCell.h"
#import "NumberEditTableCell.h"
#import "PickerTableCell.h"
#import "AppDelegate.h"


@implementation CarConfigurationController

@synthesize name;
@synthesize plate;
@synthesize odometerUnit;
@synthesize odometer;
@synthesize fuelUnit;
@synthesize fuelConsumptionUnit;

@synthesize editingExistingObject;
@synthesize delegate;



#pragma mark -
#pragma mark View Lifecycle



- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle
{
    if ((self = [super initWithNibName:nibName bundle:nibBundle]))
    {
        self.restorationIdentifier = @"CarConfigurationController";
        self.restorationClass = [self class];
    }

    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    [self recreateTableContents];

    BOOL useOldStyle = ([AppDelegate systemMajorVersion] < 7);

    // Configure the navigation bar
    UINavigationItem *item = self.navigationController.navigationBar.topItem;

    item.leftBarButtonItem  = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                            target:self
                                                                            action:@selector(handleSave:)];

    item.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(useOldStyle) ? UIBarButtonSystemItemStop : UIBarButtonSystemItemCancel
                                                                            target:self
                                                                            action:@selector(handleCancel:)];

    item.title = (editingExistingObject) ? _I18N(@"Edit Car") : _I18N(@"New Car");

    [self setToolbarItems:@[item] animated:NO];


    // iOS7:remove tint from navigation bar
    if ([AppDelegate systemMajorVersion] >= 7)
        self.navigationController.navigationBar.tintColor = nil;

    // iOS6:background image on view
    if ([AppDelegate systemMajorVersion] < 7)
    {
        NSString *imageName = [AppDelegate isLongPhone] ? @"TablePattern-568h" : @"TablePattern";

        self.tableView.backgroundView = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:imageName] resizableImageWithCapInsets:UIEdgeInsetsZero]];
    }

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(localeChanged:)
               name:NSCurrentLocaleDidChangeNotification
             object:nil];
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    dataChanged = NO;

    [self selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
}



#pragma mark -
#pragma mark State Restoration



#define kSRConfiguratorDelegate               @"FuelConfiguratorDelegate"
#define kSRConfiguratorEditMode               @"FuelConfiguratorEditMode"
#define kSRConfiguratorCancelSheet            @"FuelConfiguratorCancelSheet"
#define kSRConfiguratorDataChanged            @"FuelConfiguratorDataChanged"
#define kSRConfiguratorPreviousSelectionIndex @"FuelConfiguratorPreviousSelectionIndex"
#define kSRConfiguratorName                   @"FuelConfiguratorName"
#define kSRConfiguratorPlate                  @"FuelConfiguratorPlate"
#define kSRConfiguratorOdometerUnit           @"FuelConfiguratorOdometerUnit"
#define kSRConfiguratorFuelUnit               @"FuelConfiguratorFuelUnit"
#define kSRConfiguratorFuelConsumptionUnit    @"FuelConfiguratorFuelConsumptionUnit"


+ (UIViewController*) viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    CarConfigurationController *controller = [[self alloc] initWithNibName:@"CarConfigurationController" bundle:nil];
    controller.editingExistingObject = [coder decodeBoolForKey:kSRConfiguratorEditMode];

    return controller;
}


- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    NSIndexPath *indexPath = (isShowingCancelSheet) ? previousSelectionIndex : [self.tableView indexPathForSelectedRow];

    [coder encodeObject:delegate             forKey:kSRConfiguratorDelegate];
    [coder encodeBool:   editingExistingObject   forKey:kSRConfiguratorEditMode];
    [coder encodeBool:   isShowingCancelSheet forKey:kSRConfiguratorCancelSheet];
    [coder encodeBool:   dataChanged          forKey:kSRConfiguratorDataChanged];
    [coder encodeObject:indexPath            forKey:kSRConfiguratorPreviousSelectionIndex];
    [coder encodeObject:name                 forKey:kSRConfiguratorName];
    [coder encodeObject:plate                forKey:kSRConfiguratorPlate];
    [coder encodeObject:fuelUnit             forKey:kSRConfiguratorFuelUnit];
    [coder encodeObject:fuelConsumptionUnit  forKey:kSRConfiguratorFuelConsumptionUnit];

    [super encodeRestorableStateWithCoder:coder];
}


- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    delegate               = [coder decodeObjectForKey:kSRConfiguratorDelegate];
    isShowingCancelSheet   = [coder decodeBoolForKey:   kSRConfiguratorCancelSheet];
    dataChanged            = [coder decodeBoolForKey:   kSRConfiguratorDataChanged];
    previousSelectionIndex = [coder decodeObjectForKey:kSRConfiguratorPreviousSelectionIndex];
    name                   = [coder decodeObjectForKey:kSRConfiguratorName];
    plate                  = [coder decodeObjectForKey:kSRConfiguratorPlate];
    fuelUnit               = [coder decodeObjectForKey:kSRConfiguratorFuelUnit];
    fuelConsumptionUnit    = [coder decodeObjectForKey:kSRConfiguratorFuelConsumptionUnit];

    [self.tableView reloadData];

    if (isShowingCancelSheet)
        [self showCancelSheet];
    else
        [self selectRowAtIndexPath:previousSelectionIndex];

    [super decodeRestorableStateWithCoder:coder];
}



#pragma mark -
#pragma mark Creating the Table Rows



- (void)createOdometerRowWithAnimation:(UITableViewRowAnimation)animation
{
    NSString *suffix = [@" " stringByAppendingString:[AppDelegate odometerUnitString:(KSDistance)[self.odometerUnit integerValue]]];

    if (odometer == nil)
        self.odometer = [NSDecimalNumber zero];

    [self addRowAtIndex:3
              inSection:0
              cellClass:[NumberEditTableCell class]
               cellData:@{@"label":           _I18N(@"Odometer Reading"),
                           @"suffix":          suffix,
                           @"formatter":       [AppDelegate sharedDistanceFormatter],
                           @"valueIdentifier":@"odometer"}
          withAnimation:animation];
}


- (void)createTableContents
{
    NSArray *pickerLabels, *pickerShortLabels;

    [self addSectionAtIndex:0 withAnimation:UITableViewRowAnimationNone];

    if (name == nil)
        self.name = @"";

    [self addRowAtIndex:0
              inSection:0
              cellClass:[TextEditTableCell class]
               cellData:@{@"label":           _I18N(@"Name"),
                           @"valueIdentifier":@"name"}
          withAnimation:UITableViewRowAnimationNone];

    if (plate == nil)
        self.plate = @"";

    [self addRowAtIndex:1
              inSection:0
              cellClass:[TextEditTableCell class]
               cellData:@{@"label":             _I18N(@"License Plate"),
                           @"valueIdentifier":   @"plate",
                           @"autocapitalizeAll":@YES}
          withAnimation:UITableViewRowAnimationNone];


    if (odometerUnit == nil)
        self.odometerUnit = @([AppDelegate distanceUnitFromLocale]);

    pickerLabels = @[[AppDelegate odometerUnitDescription:KSDistanceKilometer   pluralization:YES],
                     [AppDelegate odometerUnitDescription:KSDistanceStatuteMile pluralization:YES]];

    [self addRowAtIndex:2
              inSection:0
              cellClass:[PickerTableCell class]
               cellData:@{@"label":           _I18N(@"Odometer Type"),
                           @"valueIdentifier":@"odometerUnit",
                           @"labels":          pickerLabels}
          withAnimation:UITableViewRowAnimationNone];


    [self createOdometerRowWithAnimation:UITableViewRowAnimationNone];


    if (fuelUnit == nil)
        self.fuelUnit = @([AppDelegate volumeUnitFromLocale]);

    pickerLabels = @[[AppDelegate fuelUnitDescription:KSVolumeLiter discernGallons:YES pluralization:YES],
                     [AppDelegate fuelUnitDescription:KSVolumeGalUS discernGallons:YES pluralization:YES],
                     [AppDelegate fuelUnitDescription:KSVolumeGalUK discernGallons:YES pluralization:YES]];

    [self addRowAtIndex:4
              inSection:0
              cellClass:[PickerTableCell class]
               cellData:@{@"label":           _I18N(@"Fuel Unit"),
                           @"valueIdentifier":@"fuelUnit",
                           @"labels":          pickerLabels}
          withAnimation:UITableViewRowAnimationNone];


    if (fuelConsumptionUnit == nil)
        self.fuelConsumptionUnit = @([AppDelegate fuelConsumptionUnitFromLocale]);

    pickerLabels = @[[AppDelegate consumptionUnitDescription:KSFuelConsumptionLitersPer100km],
                     [AppDelegate consumptionUnitDescription:KSFuelConsumptionKilometersPerLiter],
                     [AppDelegate consumptionUnitDescription:KSFuelConsumptionMilesPerGallonUS],
                     [AppDelegate consumptionUnitDescription:KSFuelConsumptionMilesPerGallonUK],
                     [AppDelegate consumptionUnitDescription:KSFuelConsumptionGP10KUS],
                     [AppDelegate consumptionUnitDescription:KSFuelConsumptionGP10KUK]];

    pickerShortLabels = @[[AppDelegate consumptionUnitShortDescription:KSFuelConsumptionLitersPer100km],
                          [AppDelegate consumptionUnitShortDescription:KSFuelConsumptionKilometersPerLiter],
                          [AppDelegate consumptionUnitShortDescription:KSFuelConsumptionMilesPerGallonUS],
                          [AppDelegate consumptionUnitShortDescription:KSFuelConsumptionMilesPerGallonUK],
                          [AppDelegate consumptionUnitShortDescription:KSFuelConsumptionGP10KUS],
                          [AppDelegate consumptionUnitShortDescription:KSFuelConsumptionGP10KUK]];

    [self addRowAtIndex:5
              inSection:0
              cellClass:[PickerTableCell class]
               cellData:@{@"label":           _I18N(@"Mileage"),
                           @"valueIdentifier":@"fuelConsumptionUnit",
                           @"labels":          pickerLabels,
                           @"shortLabels":     pickerShortLabels}
          withAnimation:UITableViewRowAnimationNone];
}


- (void)recreateTableContents
{
    [self removeAllSectionsWithAnimation:UITableViewRowAnimationNone];
    [self createTableContents];
    [self.tableView reloadData];
}


- (void)recreateOdometerRowWithAnimation:(UITableViewRowAnimation)animation
{
    [self removeRowAtIndex:3 inSection:0 withAnimation:UITableViewRowAnimationNone];
    [self createOdometerRowWithAnimation:UITableViewRowAnimationNone];

    if (animation == UITableViewRowAnimationNone)
        [self.tableView reloadData];
    else
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:3 inSection:0]]
                              withRowAnimation:animation];
}



#pragma mark -
#pragma mark Locale Handling



- (void)localeChanged:(id)object
{
    NSIndexPath *previousSelection = [self.tableView indexPathForSelectedRow];

    [self dismissKeyboardWithCompletion: ^{

        [self recreateTableContents];
        [self selectRowAtIndexPath:previousSelection];
    }];
}



#pragma mark -
#pragma mark Programmatically Selecting Table Rows



- (void)activateTextFieldAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    UITextField *field = nil;

    if ([cell isKindOfClass:[TextEditTableCell class]])
        field = [(TextEditTableCell*)cell textField];

    else if ([cell isKindOfClass:[NumberEditTableCell class]])
        field = [(NumberEditTableCell*)cell textField];

    else if ([cell isKindOfClass:[PickerTableCell class]])
        field = [(PickerTableCell*)cell textField];

    field.userInteractionEnabled = YES;
    [field becomeFirstResponder];
}


- (void)selectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath)
    {
        [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionMiddle];
        [self activateTextFieldAtIndexPath:indexPath];
    }
}



#pragma mark -
#pragma mark Frame Computation for Keyboard Animations



- (CGRect)frameForKeyboardApprearingInRect:(CGRect)keyboardRect
{
    CGRect frame = frameBeforeKeyboard;
    frame.size.height -= keyboardRect.size.height;
    return frame;
}



#pragma mark -
#pragma mark Button Actions



#pragma mark Cancel Button


- (IBAction)handleCancel:(id)sender
{
    previousSelectionIndex = [self.tableView indexPathForSelectedRow];

    [self dismissKeyboardWithCompletion: ^{ [self handleCancelCompletion]; }];
}


- (void)handleCancelCompletion
{
    BOOL showCancelSheet = YES;

    // In editing mode show alert panel on any change
    if (editingExistingObject == YES && dataChanged == NO)
        showCancelSheet = NO;

    // In create mode show alert panel on textual changes
    if (editingExistingObject == NO
        && [name isEqualToString:@""] == YES
        && [plate isEqualToString:@""] == YES
        && [odometer compare:[NSDecimalNumber zero]] == NSOrderedSame)
        showCancelSheet = NO;

    if (showCancelSheet)
        [self showCancelSheet];
    else
        [delegate carConfigurationController:self
                         didFinishWithResult:CarConfigurationCanceled];
}


- (void)showCancelSheet
{
    isShowingCancelSheet = YES;

    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:editingExistingObject ? _I18N(@"Revert Changes for Car?")
                                                                                      : _I18N(@"Delete the newly created Car?")
                                                       delegate:self
                                              cancelButtonTitle: _I18N(@"Cancel")
                                         destructiveButtonTitle:editingExistingObject ? _I18N(@"Revert")
                                                                                      : _I18N(@"Delete")
                                              otherButtonTitles:nil];

    sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [sheet showInView:self.view];
}


- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    isShowingCancelSheet = NO;

    if (buttonIndex != actionSheet.cancelButtonIndex)
        [delegate carConfigurationController:self didFinishWithResult:CarConfigurationCanceled];
    else
        [self selectRowAtIndexPath:previousSelectionIndex];

    previousSelectionIndex = nil;
}


#pragma mark Save Button


- (IBAction)handleSave:(id)sender
{
    [self dismissKeyboardWithCompletion: ^{

        [delegate carConfigurationController:self
                         didFinishWithResult:editingExistingObject ? CarConfigurationEditSucceded
                                                                 : CarConfigurationCreateSucceded];
    }];
}



#pragma mark -
#pragma mark EditablePageCellDelegate



- (void)focusNextFieldForValueIdentifier:(NSString *)valueIdentifier
{
    if ([valueIdentifier isEqualToString:@"name"])
        [self selectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
    else
        [self selectRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:0]];
}


- (id)valueForIdentifier:(NSString *)valueIdentifier
{
    if ([valueIdentifier isEqualToString:@"name"])
        return name;
    else if ([valueIdentifier isEqualToString:@"plate"])
        return plate;
    else if ([valueIdentifier isEqualToString:@"odometerUnit"])
        return odometerUnit;
    else if ([valueIdentifier isEqualToString:@"odometer"])
        return odometer;
    else if ([valueIdentifier isEqualToString:@"fuelUnit"])
        return fuelUnit;
    else if ([valueIdentifier isEqualToString:@"fuelConsumptionUnit"])
        return fuelConsumptionUnit;

    return nil;
}


- (void)valueChanged:(id)newValue identifier:(NSString *)valueIdentifier
{
    if ([newValue isKindOfClass:[NSString class]])
    {
        if ([valueIdentifier isEqualToString:@"name"])
            self.name  = (NSString *)newValue;

        else if ([valueIdentifier isEqualToString:@"plate"])
            self.plate = (NSString *)newValue;
    }

    else if ([newValue isKindOfClass:[NSDecimalNumber class]])
    {
        if ([valueIdentifier isEqualToString:@"odometer"])
            self.odometer = (NSDecimalNumber *)newValue;
    }

    else if ([newValue isKindOfClass:[NSNumber class]])
    {
        if ([valueIdentifier isEqualToString:@"odometerUnit"])
        {
            KSDistance oldUnit = (KSDistance)[self.odometerUnit integerValue];
            KSDistance newUnit = (KSDistance)[(NSNumber*)newValue integerValue];

            if (oldUnit != newUnit)
            {
                self.odometerUnit = (NSNumber*)newValue;
                self.odometer     = [AppDelegate distanceForKilometers:[AppDelegate kilometersForDistance:self.odometer
                                                                                                  withUnit:oldUnit]
                                                              withUnit:newUnit];

                [self recreateOdometerRowWithAnimation:newUnit
                                                            ? UITableViewRowAnimationRight
                                                            : UITableViewRowAnimationLeft];
            }
        }

        else if ([valueIdentifier isEqualToString:@"fuelUnit"])
            self.fuelUnit = (NSNumber*)newValue;

        else if ([valueIdentifier isEqualToString:@"fuelConsumptionUnit"])
            self.fuelConsumptionUnit = (NSNumber*)newValue;
    }

    dataChanged = YES;
}



#pragma mark -
#pragma mark UITableViewDelegate



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self activateTextFieldAtIndexPath:indexPath];

    [self.tableView scrollToRowAtIndexPath:indexPath
                          atScrollPosition:UITableViewScrollPositionMiddle
                                  animated:YES];
}



#pragma mark -
#pragma mark Memory Management



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
