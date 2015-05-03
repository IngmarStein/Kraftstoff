// CarConfigurationController.m
//
// Kraftstoff


#import "CarConfigurationController.h"
#import "NumberEditTableCell.h"
#import "AppDelegate.h"
#import "kraftstoff-Swift.h"

@interface CarConfigurationController () <EditablePageCellDelegate>

@end

@implementation CarConfigurationController

#pragma mark -
#pragma mark View Lifecycle

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) {
		self.restorationClass = [self class];
	}
	return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self recreateTableContents];

    // Configure the navigation bar
    UINavigationItem *item = self.navigationController.navigationBar.topItem;

    item.leftBarButtonItem  = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                            target:self
                                                                            action:@selector(handleSave:)];

    item.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                            target:self
                                                                            action:@selector(handleCancel:)];

    item.title = self.editingExistingObject ? NSLocalizedString(@"Edit Car", @"") : NSLocalizedString(@"New Car", @"");

    [self setToolbarItems:@[item] animated:NO];


    // emove tint from navigation bar
    self.navigationController.navigationBar.tintColor = nil;

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
	UIStoryboard *storyboard = [coder decodeObjectForKey:UIStateRestorationViewControllerStoryboardKey];
    CarConfigurationController *controller = [storyboard instantiateViewControllerWithIdentifier:@"CarConfigurationController"];
    controller.editingExistingObject = [coder decodeBoolForKey:kSRConfiguratorEditMode];

    return controller;
}


- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    NSIndexPath *indexPath = (isShowingCancelSheet) ? previousSelectionIndex : [self.tableView indexPathForSelectedRow];

    [coder encodeObject:self.delegate             forKey:kSRConfiguratorDelegate];
    [coder encodeBool:   self.editingExistingObject   forKey:kSRConfiguratorEditMode];
    [coder encodeBool:   isShowingCancelSheet forKey:kSRConfiguratorCancelSheet];
    [coder encodeBool:   dataChanged          forKey:kSRConfiguratorDataChanged];
    [coder encodeObject:indexPath            forKey:kSRConfiguratorPreviousSelectionIndex];
    [coder encodeObject:self.name                 forKey:kSRConfiguratorName];
    [coder encodeObject:self.plate                forKey:kSRConfiguratorPlate];
    [coder encodeObject:self.fuelUnit             forKey:kSRConfiguratorFuelUnit];
    [coder encodeObject:self.fuelConsumptionUnit  forKey:kSRConfiguratorFuelConsumptionUnit];

    [super encodeRestorableStateWithCoder:coder];
}


- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    self.delegate               = [coder decodeObjectForKey:kSRConfiguratorDelegate];
    isShowingCancelSheet   = [coder decodeBoolForKey:   kSRConfiguratorCancelSheet];
    dataChanged            = [coder decodeBoolForKey:   kSRConfiguratorDataChanged];
    previousSelectionIndex = [coder decodeObjectForKey:kSRConfiguratorPreviousSelectionIndex];
    self.name                   = [coder decodeObjectForKey:kSRConfiguratorName];
    self.plate                  = [coder decodeObjectForKey:kSRConfiguratorPlate];
    self.fuelUnit               = [coder decodeObjectForKey:kSRConfiguratorFuelUnit];
    self.fuelConsumptionUnit    = [coder decodeObjectForKey:kSRConfiguratorFuelConsumptionUnit];

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
    NSString *suffix = [@" " stringByAppendingString:[Units odometerUnitString:(KSDistance)[self.odometerUnit integerValue]]];

    if (self.odometer == nil)
        self.odometer = [NSDecimalNumber zero];

    [self addRowAtIndex:3
              inSection:0
              cellClass:[NumberEditTableCell class]
               cellData:@{@"label":           NSLocalizedString(@"Odometer Reading", @""),
                           @"suffix":          suffix,
                           @"formatter":       [Formatters sharedDistanceFormatter],
                           @"valueIdentifier":@"odometer"}
          withAnimation:animation];
}


- (void)createTableContents
{
    NSArray *pickerLabels, *pickerShortLabels;

    [self addSectionAtIndex:0 withAnimation:UITableViewRowAnimationNone];

    if (self.name == nil)
        self.name = @"";

    [self addRowAtIndex:0
              inSection:0
              cellClass:[TextEditTableCell class]
               cellData:@{@"label":           NSLocalizedString(@"Name", @""),
                           @"valueIdentifier":@"name"}
          withAnimation:UITableViewRowAnimationNone];

    if (self.plate == nil)
        self.plate = @"";

    [self addRowAtIndex:1
              inSection:0
              cellClass:[TextEditTableCell class]
               cellData:@{@"label":             NSLocalizedString(@"License Plate", @""),
                           @"valueIdentifier":   @"plate",
                           @"autocapitalizeAll":@YES}
          withAnimation:UITableViewRowAnimationNone];


    if (self.odometerUnit == nil)
        self.odometerUnit = @([Units distanceUnitFromLocale]);

    pickerLabels = @[[Units odometerUnitDescription:KSDistanceKilometer   pluralization:YES],
                     [Units odometerUnitDescription:KSDistanceStatuteMile pluralization:YES]];

    [self addRowAtIndex:2
              inSection:0
              cellClass:[PickerTableCell class]
               cellData:@{@"label":           NSLocalizedString(@"Odometer Type", @""),
                           @"valueIdentifier":@"odometerUnit",
                           @"labels":          pickerLabels}
          withAnimation:UITableViewRowAnimationNone];


    [self createOdometerRowWithAnimation:UITableViewRowAnimationNone];


    if (self.fuelUnit == nil)
        self.fuelUnit = @([Units volumeUnitFromLocale]);

    pickerLabels = @[[Units fuelUnitDescription:KSVolumeLiter discernGallons:YES pluralization:YES],
                     [Units fuelUnitDescription:KSVolumeGalUS discernGallons:YES pluralization:YES],
                     [Units fuelUnitDescription:KSVolumeGalUK discernGallons:YES pluralization:YES]];

    [self addRowAtIndex:4
              inSection:0
              cellClass:[PickerTableCell class]
               cellData:@{@"label":           NSLocalizedString(@"Fuel Unit", @""),
                           @"valueIdentifier":@"fuelUnit",
                           @"labels":          pickerLabels}
          withAnimation:UITableViewRowAnimationNone];


    if (self.fuelConsumptionUnit == nil)
        self.fuelConsumptionUnit = @([Units fuelConsumptionUnitFromLocale]);

    pickerLabels = @[[Units consumptionUnitDescription:KSFuelConsumptionLitersPer100km],
                     [Units consumptionUnitDescription:KSFuelConsumptionKilometersPerLiter],
                     [Units consumptionUnitDescription:KSFuelConsumptionMilesPerGallonUS],
                     [Units consumptionUnitDescription:KSFuelConsumptionMilesPerGallonUK],
                     [Units consumptionUnitDescription:KSFuelConsumptionGP10KUS],
                     [Units consumptionUnitDescription:KSFuelConsumptionGP10KUK]];

    pickerShortLabels = @[[Units consumptionUnitShortDescription:KSFuelConsumptionLitersPer100km],
                          [Units consumptionUnitShortDescription:KSFuelConsumptionKilometersPerLiter],
                          [Units consumptionUnitShortDescription:KSFuelConsumptionMilesPerGallonUS],
                          [Units consumptionUnitShortDescription:KSFuelConsumptionMilesPerGallonUK],
                          [Units consumptionUnitShortDescription:KSFuelConsumptionGP10KUS],
                          [Units consumptionUnitShortDescription:KSFuelConsumptionGP10KUK]];

    [self addRowAtIndex:5
              inSection:0
              cellClass:[PickerTableCell class]
               cellData:@{@"label":           NSLocalizedString(@"Mileage", @""),
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
    if (self.editingExistingObject && !dataChanged)
        showCancelSheet = NO;

    // In create mode show alert panel on textual changes
    if (!self.editingExistingObject
        && [self.name isEqualToString:@""] == YES
        && [self.plate isEqualToString:@""] == YES
        && [self.odometer compare:[NSDecimalNumber zero]] == NSOrderedSame)
        showCancelSheet = NO;

    if (showCancelSheet)
        [self showCancelSheet];
    else
        [self.delegate carConfigurationController:self
                         didFinishWithResult:CarConfigurationCanceled];
}


- (void)showCancelSheet
{
    isShowingCancelSheet = YES;

	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:self.editingExistingObject ? NSLocalizedString(@"Revert Changes for Car?", @"") : NSLocalizedString(@"Delete the newly created Car?", @"")
																			 message:nil
																	  preferredStyle:UIAlertControllerStyleActionSheet];
	UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"")
														   style:UIAlertActionStyleCancel
														 handler:^(UIAlertAction * action) {
															 self->isShowingCancelSheet = NO;
															 [self selectRowAtIndexPath:previousSelectionIndex];
															 previousSelectionIndex = nil;
														 }];
	UIAlertAction *destructiveAction = [UIAlertAction actionWithTitle:self.editingExistingObject ? NSLocalizedString(@"Revert", @"") : NSLocalizedString(@"Delete", @"")
																style:UIAlertActionStyleDestructive
															  handler:^(UIAlertAction * action) {
																  self->isShowingCancelSheet = NO;
																  [self.delegate carConfigurationController:self didFinishWithResult:CarConfigurationCanceled];
																  previousSelectionIndex = nil;
															  }];
	[alertController addAction:cancelAction];
	[alertController addAction:destructiveAction];
	[self presentViewController:alertController animated:YES completion:NULL];
}

#pragma mark -
#pragma mark Save Button


- (IBAction)handleSave:(id)sender
{
    [self dismissKeyboardWithCompletion: ^{

        [self.delegate carConfigurationController:self
                         didFinishWithResult:self.editingExistingObject ? CarConfigurationEditSucceded
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
        return self.name;
    else if ([valueIdentifier isEqualToString:@"plate"])
        return self.plate;
    else if ([valueIdentifier isEqualToString:@"odometerUnit"])
        return self.odometerUnit;
    else if ([valueIdentifier isEqualToString:@"odometer"])
        return self.odometer;
    else if ([valueIdentifier isEqualToString:@"fuelUnit"])
        return self.fuelUnit;
    else if ([valueIdentifier isEqualToString:@"fuelConsumptionUnit"])
        return self.fuelConsumptionUnit;

    return nil;
}


- (void)valueChanged:(id)newValue identifier:(NSString *)valueIdentifier
{
    if ([newValue isKindOfClass:[NSString class]]) {

        if ([valueIdentifier isEqualToString:@"name"])
            self.name  = (NSString *)newValue;

        else if ([valueIdentifier isEqualToString:@"plate"])
            self.plate = (NSString *)newValue;

    } else if ([newValue isKindOfClass:[NSDecimalNumber class]]) {

        if ([valueIdentifier isEqualToString:@"odometer"])
            self.odometer = (NSDecimalNumber *)newValue;

    } else if ([newValue isKindOfClass:[NSNumber class]]) {

        if ([valueIdentifier isEqualToString:@"odometerUnit"]) {

            KSDistance oldUnit = (KSDistance)[self.odometerUnit integerValue];
            KSDistance newUnit = (KSDistance)[(NSNumber*)newValue integerValue];

            if (oldUnit != newUnit) {

                self.odometerUnit = (NSNumber*)newValue;
                self.odometer     = [Units distanceForKilometers:[Units kilometersForDistance:self.odometer
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



- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
