// FuelEventController.m
//
// Kraftstoff


#import "FuelEventController.h"
#import "ShadowTableView.h"
#import "ShadedTableViewCell.h"
#import "FuelStatisticsPageController.h"
#import "FuelEventEditorController.h"
#import "AppDelegate.h"


@implementation FuelEventController

@synthesize selectedCar;
@synthesize managedObjectContext;
@synthesize statisticsController;
@synthesize fetchRequest;
@synthesize fetchedResultsController;



#pragma mark -
#pragma mark View Lifecycle



- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle
{
    if ((self = [super initWithNibName:nibName bundle:nibBundle]))
    {
        self.restorationIdentifier = @"FuelEventController";
        self.restorationClass = [self class];

        // Alternate view controller for statistics
        self.statisticsController = [[FuelStatisticsPageController alloc]
                                           initWithNibName:@"FuelStatisticsPageController"
                                                    bundle:nil];
    }

    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    isObservingRotationEvents  = NO;
    isPerformingRotation       = NO;

    isShowingExportSheet       = NO;
    isShowingExportFailedAlert = NO;
    isShowingMailComposer      = NO;

    restoreExportSheet         = NO;
    restoreExportFailedAlert   = NO;
    restoreMailComposer        = NO;

    // Configure root view
    self.title = [self.selectedCar valueForKey:@"name"];

    // Export button in navigation bar
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                     target:self
                                                                     action:@selector(showExportSheet:)];

    self.navigationItem.rightBarButtonItem.enabled = NO;

    // iOS7:reset tint color
    if ([AppDelegate systemMajorVersion] >= 7)
        self.navigationController.navigationBar.tintColor = nil;

    // Background image
    NSString *imageName = [NSString stringWithFormat:@"TableBackground%@%@",
                                ([AppDelegate systemMajorVersion] >= 7 ? @"Flat"  : @""),
                                ([AppDelegate isLongPhone]             ? @"-568h" : @"")];

    self.tableView.backgroundView  = [[UIImageView alloc] initWithImage:[UIImage imageNamed:imageName]];
    self.tableView.backgroundView.contentMode = UIViewContentModeBottom;

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(localeChanged:)
               name:NSCurrentLocaleDidChangeNotification
             object:nil];

    if ([self presentedViewController])
        [self dismissViewControllerAnimated:NO completion:nil];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self validateExport];
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self setObserveDeviceRotation:YES];

    if (restoreExportSheet)
        [self showExportSheet:nil];

    else if (restoreExportFailedAlert)
        [self showExportFailedAlert:nil];

    else if (restoreMailComposer)
        [self showMailComposer:nil];
}


- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if ([self presentedViewController] == nil)
        [self setObserveDeviceRotation:NO];
}



#pragma mark -
#pragma mark iOS 6 State Restoration



#define kSRFuelEventSelectedCarID     @"FuelEventSelectedCarID"
#define kSRFuelEventExportSheet       @"FuelEventExportSheet"
#define kSRFuelEventExportFailedAlert @"FuelEventExportFailedAlert"
#define kSRFuelEventShowComposer      @"FuelEventShowMailComposer"


+ (UIViewController*) viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    FuelEventController *controller = [[self alloc] initWithNibName:@"FuelEventController" bundle:nil];
    controller.managedObjectContext = [appDelegate managedObjectContext];
    controller.selectedCar          = [appDelegate managedObjectForModelIdentifier:[coder decodeObjectForKey:kSRFuelEventSelectedCarID]];

    if (controller.selectedCar == nil)
        return nil;

    return controller;
}


- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    [coder encodeObject:[appDelegate modelIdentifierForManagedObject:self.selectedCar] forKey:kSRFuelEventSelectedCarID];
    [coder encodeBool:restoreExportSheet|isShowingExportSheet             forKey:kSRFuelEventExportSheet];
    [coder encodeBool:restoreExportFailedAlert|isShowingExportFailedAlert forKey:kSRFuelEventExportFailedAlert];
    [coder encodeBool:restoreMailComposer|isShowingMailComposer           forKey:kSRFuelEventShowComposer];

    // don't use a snapshot image for next launch when graph is currently visible
    if ([AppDelegate systemMajorVersion] >= 7)
        if ([self presentedViewController] != nil)
            [[UIApplication sharedApplication] ignoreSnapshotOnNextApplicationLaunch];

    [super encodeRestorableStateWithCoder:coder];
}


- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    restoreExportSheet       = [coder decodeBoolForKey:kSRFuelEventExportSheet];
    restoreExportFailedAlert = [coder decodeBoolForKey:kSRFuelEventExportFailedAlert];
    restoreMailComposer      = [coder decodeBoolForKey:kSRFuelEventShowComposer];

    [super decodeRestorableStateWithCoder:coder];

    // -> openradar #13438788
    [self.tableView reloadData];
}



#pragma mark -
#pragma mark Device Rotation



- (void)setObserveDeviceRotation:(BOOL)observeRotation
{
    if (observeRotation == YES && isObservingRotationEvents == NO)
    {
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(orientationChanged:)
                   name:UIDeviceOrientationDidChangeNotification
                 object:[UIDevice currentDevice]];
    }

    else if (observeRotation == NO && isObservingRotationEvents == YES)
    {
        [[NSNotificationCenter defaultCenter]
            removeObserver:self
                      name:UIDeviceOrientationDidChangeNotification
                    object:[UIDevice currentDevice]];

        [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    }

    isObservingRotationEvents = observeRotation;
}


- (void)orientationChanged:(NSNotification*)aNotification
{
    // Ignore rotation when:
    //  - showing the export sheets or the mail composer
    //  - the previous rotation isn't finished yet
    //  - rotations are no longer observed
    if (isShowingExportSheet || isShowingExportFailedAlert || isShowingMailComposer || isPerformingRotation || !isObservingRotationEvents)
        return;

    // Switch view controllers according rotation state
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;

    if (UIDeviceOrientationIsLandscape (deviceOrientation) && [self presentedViewController] == nil)
    {
        self.statisticsController.selectedCar = self.selectedCar;

        isPerformingRotation = YES;

        [self presentViewController:self.statisticsController
                           animated:YES
                         completion: ^{ isPerformingRotation = NO; }];
    }
    else if (UIDeviceOrientationIsPortrait (deviceOrientation) && [self presentedViewController] != nil)
    {
        isPerformingRotation = YES;

        [self dismissViewControllerAnimated:YES completion: ^{ isPerformingRotation = NO; }];
    }
}



#pragma mark -
#pragma mark Locale Handling



- (void)localeChanged:(id)object
{
    [self.tableView reloadData];
}



#pragma mark -
#pragma mark Export Objects via eMail



- (void)showMailComposer:(id)sender
{
    restoreMailComposer   = NO;

    if ([MFMailComposeViewController canSendMail])
    {
        MFMailComposeViewController *mailComposer = [[MFMailComposeViewController alloc] init];

        // Copy look of navigation bar to compose window
        if ([AppDelegate systemMajorVersion] < 7)
        {
            UINavigationBar *navBar = [mailComposer navigationBar];

            if (navBar != nil)
            {
                navBar.barStyle  = UIBarStyleBlack;
                navBar.tintColor = [[[self navigationController] navigationBar] tintColor];
            }
        }

        // Setup the message
        [mailComposer setMailComposeDelegate:self];
        [mailComposer setSubject:[NSString stringWithFormat:_I18N(@"Your fuel data for %@"), [self.selectedCar valueForKey:@"numberPlate"]]];
        [mailComposer setMessageBody:[self exportTextDescription] isHTML:NO];

        [mailComposer addAttachmentData:[self exportTextData]
                               mimeType:@"text"
                               fileName:[NSString stringWithFormat:@"%@__%@.csv",
                                              [self.selectedCar valueForKey:@"name"],
                                              [self.selectedCar valueForKey:@"numberPlate"]]];

        [self presentViewController:mailComposer animated:YES completion: ^{ isShowingMailComposer = YES; }];
    }
}


- (void)validateExport
{
    // Sending mail needs a configured mail account
    self.navigationItem.rightBarButtonItem.enabled = ([MFMailComposeViewController canSendMail] && [[[self fetchedResultsController] fetchedObjects] count] > 0);
}


- (NSData*)exportTextData
{
    KSDistance        odometerUnit    = [[selectedCar valueForKey:@"odometerUnit"]        integerValue];
    KSVolume          fuelUnit        = [[selectedCar valueForKey:@"fuelUnit"]            integerValue];
    KSFuelConsumption consumptionUnit = [[selectedCar valueForKey:@"fuelConsumptionUnit"] integerValue];

    NSMutableString *dataString = [NSMutableString stringWithCapacity:4096];

    [dataString appendString:_I18N(@"yyyy-MM-dd")];
    [dataString appendString:@";"];

    [dataString appendString:_I18N(@"HH:mm")];
    [dataString appendString:@";"];

    [dataString appendString:[AppDelegate odometerUnitDescription:odometerUnit pluralization:YES]];
    [dataString appendString:@";"];

    [dataString appendString:[AppDelegate fuelUnitDescription:fuelUnit discernGallons:YES pluralization:YES]];
    [dataString appendString:@";"];

    [dataString appendString:_I18N(@"Full Fill-Up")];
    [dataString appendString:@";"];

    [dataString appendString:[AppDelegate fuelPriceUnitDescription:fuelUnit]];
    [dataString appendString:@";"];

    [dataString appendString:[AppDelegate consumptionUnitDescription:consumptionUnit]];
    [dataString appendString:@"\n"];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd';'HH:mm"];
    [dateFormatter setLocale:[NSLocale systemLocale]];

    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setNumberStyle:kCFNumberFormatterDecimalStyle];
    [numberFormatter setLocale:[NSLocale currentLocale]];
    [numberFormatter setUsesGroupingSeparator:NO];
    [numberFormatter setAlwaysShowsDecimalSeparator:YES];
    [numberFormatter setMinimumFractionDigits:2];

    NSArray *fetchedObjects = [self.fetchedResultsController fetchedObjects];

    for (NSUInteger i = 0; i < [fetchedObjects count]; i++)
    {
        NSManagedObject *managedObject = fetchedObjects[i];

        NSDecimalNumber *distance   = [managedObject valueForKey:@"distance"];
        NSDecimalNumber *fuelVolume = [managedObject valueForKey:@"fuelVolume"];
        NSDecimalNumber *price      = [managedObject valueForKey:@"price"];

        [dataString appendFormat:@"%@;\"%@\";\"%@\";%@;\"%@\";\"%@\"\n",
            [dateFormatter stringFromDate:[managedObject valueForKey:@"timestamp"]],
            [numberFormatter stringFromNumber:[AppDelegate distanceForKilometers:distance withUnit:odometerUnit]],
            [numberFormatter stringFromNumber:[AppDelegate volumeForLiters:fuelVolume withUnit:fuelUnit]],
            [[managedObject valueForKey:@"filledUp"] boolValue] ? _I18N(@"Yes") : _I18N(@"No"),
            [numberFormatter stringFromNumber:[AppDelegate pricePerUnit:price withUnit:fuelUnit]],

            [[managedObject valueForKey:@"filledUp"] boolValue]
                ? [numberFormatter stringFromNumber:
                      [AppDelegate consumptionForKilometers:[distance   decimalNumberByAdding:[managedObject valueForKey:@"inheritedDistance"]]
                                                     Liters:[fuelVolume decimalNumberByAdding:[managedObject valueForKey:@"inheritedFuelVolume"]]
                                                     inUnit:consumptionUnit]]
                : @" "
         ];
    }


    return [dataString dataUsingEncoding:NSUTF8StringEncoding];
}


- (NSString *)exportTextDescription
{
    NSString *period, *count;

    NSDateFormatter *outputFormatter = [[NSDateFormatter alloc] init];
    {
        [outputFormatter setDateStyle:kCFDateFormatterMediumStyle];
        [outputFormatter setTimeStyle:kCFDateFormatterNoStyle];

        NSArray *fetchedObjects = [self.fetchedResultsController fetchedObjects];
        NSUInteger fetchCount = [fetchedObjects count];

        NSString *from = [outputFormatter stringFromDate:[[fetchedObjects lastObject]       valueForKey:@"timestamp"]];
        NSString *to   = [outputFormatter stringFromDate:[fetchedObjects[0] valueForKey:@"timestamp"]];

        switch (fetchCount)
        {
            case 0:  period = _I18N(@""); break;
            case 1:  period = [NSString stringWithFormat:_I18N(@"on %@"), from]; break;
            default:period = [NSString stringWithFormat:_I18N(@"in the period from %@ to %@"), from, to]; break;
        }

        count = [NSString stringWithFormat:_I18N(((fetchCount == 1) ? @"%d item" : @"%d items")), fetchCount];
    }

    return [NSString stringWithFormat:_I18N(@"Here are your exported fuel data sets for %@ (%@) %@ (%@):\n"),
                [self.selectedCar valueForKey:@"name"],
                [self.selectedCar valueForKey:@"numberPlate"],
                period,
                count];
}


- (void)mailComposeController:(MFMailComposeViewController*)mailComposer
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError*)error
{
    [self dismissViewControllerAnimated:YES completion: ^{

        isShowingMailComposer = NO;

        if (result == MFMailComposeResultFailed)
            [self showExportFailedAlert:nil];
    }];
}



#pragma mark -
#pragma mark Export Action Sheet



- (void)showExportSheet:(id)sender
{
    isShowingExportSheet = YES;
    restoreExportSheet   = NO;

    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:_I18N(@"Export Fuel Data as CSV via Mail?")
                                                       delegate:self
                                              cancelButtonTitle:_I18N(@"Cancel")
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:_I18N(@"Export"), nil];

    sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;

    [sheet showFromTabBar:self.tabBarController.tabBar];
}


- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    isShowingExportSheet = NO;

    if (buttonIndex != actionSheet.cancelButtonIndex)
    {
        [self showMailComposer:nil];
    }
}



#pragma mark -
#pragma mark Export Failed Alert



- (void)showExportFailedAlert:(id)sender
{
    isShowingExportFailedAlert = YES;
    restoreExportFailedAlert   = NO;

    [[[UIAlertView alloc] initWithTitle:_I18N(@"Sending Failed")
                                message:_I18N(@"The exported fuel data could not be sent.")
                               delegate:self
                      cancelButtonTitle:_I18N(@"OK")
                      otherButtonTitles:nil] show];
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    isShowingExportFailedAlert = NO;
}



#pragma mark -
#pragma mark UITableViewDataSource



- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath
{
    ShadedTableViewCell *tableCell = (ShadedTableViewCell*)cell;
    NSManagedObject *managedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];

    NSManagedObject *car        = [managedObject valueForKey:@"car"];
    NSDecimalNumber *distance   = [managedObject valueForKey:@"distance"];
    NSDecimalNumber *fuelVolume = [managedObject valueForKey:@"fuelVolume"];
    NSDecimalNumber *price      = [managedObject valueForKey:@"price"];

    KSDistance        odometerUnit    = [[car valueForKey:@"odometerUnit"]        integerValue];
    KSFuelConsumption consumptionUnit = [[car valueForKey:@"fuelConsumptionUnit"] integerValue];

    UILabel *label;


    // Timestamp
    label      = [tableCell topLeftLabel];
    label.text = [[AppDelegate sharedDateFormatter] stringForObjectValue:[managedObject valueForKey:@"timestamp"]];
    tableCell.topLeftAccessibilityLabel = nil;


    // Distance
    NSDecimalNumber *convertedDistance;

    if (odometerUnit == KSDistanceKilometer)
        convertedDistance = distance;
    else
        convertedDistance = [distance decimalNumberByDividingBy:[AppDelegate kilometersPerStatuteMile]];

    label      = [tableCell botLeftLabel];
    label.text = [NSString stringWithFormat:@"%@ %@",
                    [[AppDelegate sharedDistanceFormatter] stringFromNumber:convertedDistance],
                    [AppDelegate odometerUnitString:odometerUnit]];
    tableCell.botLeftAccessibilityLabel = nil;

    
    // Price
    label      = [tableCell topRightLabel];
    label.text = [[AppDelegate sharedCurrencyFormatter] stringFromNumber:[fuelVolume decimalNumberByMultiplyingBy:price]];
    tableCell.topRightAccessibilityLabel = label.text;


    // Consumption combined with inherited data from earlier events
    NSString *consumptionDescription;

    if ([[managedObject valueForKey:@"filledUp"] boolValue])
    {
        distance   = [distance   decimalNumberByAdding:[managedObject valueForKey:@"inheritedDistance"]];
        fuelVolume = [fuelVolume decimalNumberByAdding:[managedObject valueForKey:@"inheritedFuelVolume"]];

        NSDecimalNumber *avg = [AppDelegate consumptionForKilometers:distance
                                                              Liters:fuelVolume
                                                              inUnit:consumptionUnit];

        consumptionDescription = [[AppDelegate sharedFuelVolumeFormatter] stringFromNumber:avg];

        tableCell.botRightAccessibilityLabel = [NSString stringWithFormat:@", %@ %@",
                                                    consumptionDescription,
                                                    [AppDelegate consumptionUnitAccesibilityDescription:consumptionUnit]];
    }
    else
    {
        consumptionDescription = _I18N(@"-");

        tableCell.botRightAccessibilityLabel = _I18N(@"fuel mileage not available");
    }

    label = [tableCell botRightLabel];
    label.text = [NSString stringWithFormat:@"%@ %@", consumptionDescription, [AppDelegate consumptionUnitString:consumptionUnit]];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];

    return [sectionInfo numberOfObjects];
}


- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"FuelCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (cell == nil)
        cell = [[ShadedTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                           reuseIdentifier:CellIdentifier
                                      enlargeTopRightLabel:NO];

    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {

        [AppDelegate removeEventFromArchive:[self.fetchedResultsController objectAtIndexPath:indexPath]
                     inManagedObjectContext:self.managedObjectContext
                        forceOdometerUpdate:NO];

        [(AppDelegate *)[[UIApplication sharedApplication] delegate] saveContext:self.managedObjectContext];
    }
}



#pragma mark -
#pragma mark UIDataSourceModelAssociation



- (NSIndexPath *)indexPathForElementWithModelIdentifier:(NSString *)identifier inView:(UIView *)view
{
    NSManagedObject *object = [(AppDelegate *)[[UIApplication sharedApplication] delegate] managedObjectForModelIdentifier:identifier];

    return [self.fetchedResultsController indexPathForObject:object];
}


- (NSString *)modelIdentifierForElementAtIndexPath:(NSIndexPath *)idx inView:(UIView *)view
{
    NSManagedObject *object = [self.fetchedResultsController objectAtIndexPath:idx];

    return [(AppDelegate *)[[UIApplication sharedApplication] delegate] modelIdentifierForManagedObject:object];
}



#pragma mark -
#pragma mark UITableViewDelegate



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    FuelEventEditorController *editController = [[FuelEventEditorController alloc] initWithNibName:@"FuelEventEditor" bundle:nil];

    editController.managedObjectContext =  self.managedObjectContext;
    editController.event = [self.fetchedResultsController objectAtIndexPath:indexPath];

    [self.navigationController pushViewController:editController animated:YES];
}



#pragma mark -
#pragma mark Fetch Request



- (NSFetchRequest*)fetchRequest
{
    if (fetchRequest == nil)
        self.fetchRequest = [AppDelegate fetchRequestForEventsForCar:self.selectedCar
                                                           afterDate:nil
                                                         dateMatches:YES
                                              inManagedObjectContext:self.managedObjectContext];

    return fetchRequest;
}



#pragma mark -
#pragma mark Fetched Results Controller



- (NSFetchedResultsController *)fetchedResultsController
{
    if (fetchedResultsController == nil)
    {
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSString *cacheName = [appDelegate cacheNameForFuelEventFetchWithParent:self.selectedCar];

        NSFetchedResultsController *fetchController = [[NSFetchedResultsController alloc] initWithFetchRequest:self.fetchRequest
                                                                                          managedObjectContext:self.managedObjectContext
                                                                                            sectionNameKeyPath:nil
                                                                                                     cacheName:cacheName];

        fetchController.delegate = self;
        self.fetchedResultsController = fetchController;


        // Perform the data fetch
        NSError *error = nil;

        if (! [fetchedResultsController performFetch:&error])
            [NSException raise:NSGenericException format:@"%@", [error localizedDescription]];
    }

    return fetchedResultsController;
}



#pragma mark -
#pragma mark NSFetchedResultsControllerDelegate



- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}


- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
    switch (type) {

        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)object
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;

    switch (type) {

        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];

            [tableView insertRowsAtIndexPaths:@[newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
            [tableView reloadRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];

    [self validateExport];
    [self.statisticsController invalidateCaches];
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
