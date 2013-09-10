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
{
    BOOL isObservingRotationEvents;
    BOOL isPerformingRotation;
    BOOL isShowingExportSheet;
    BOOL isShowingAlert;
    BOOL restoreExportSheet;
    BOOL restoreOpenIn;
    BOOL restoreMailComposer;

    UIDocumentInteractionController *openInController;
    MFMailComposeViewController *mailComposeController;
}

@synthesize fetchRequest = _fetchRequest;
@synthesize fetchedResultsController = _fetchedResultsController;



#pragma mark -
#pragma mark View Lifecycle



- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle
{
    if ((self = [super initWithNibName:nibName bundle:nibBundle])) {

        self.restorationIdentifier = @"FuelEventController";
        self.restorationClass = [self class];

        _statisticsController = [[FuelStatisticsPageController alloc]
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
    isShowingAlert             = NO;
    restoreExportSheet         = NO;
    restoreOpenIn              = NO;
    restoreMailComposer        = NO;

    // Configure root view
    self.title = [_selectedCar valueForKey:@"name"];

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

    // Dismiss any presented view controllers
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

    else if (restoreOpenIn)
        [self showOpenIn:nil];

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
#pragma mark State Restoration



#define kSRFuelEventSelectedCarID     @"FuelEventSelectedCarID"
#define kSRFuelEventExportSheet       @"FuelEventExportSheet"
#define kSRFuelEventShowOpenIn        @"FuelEventShowOpenIn"
#define kSRFuelEventShowComposer      @"FuelEventShowMailComposer"


+ (UIViewController*) viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    FuelEventController *controller = [[self alloc] initWithNibName:@"FuelEventController" bundle:nil];
    controller.managedObjectContext = [appDelegate managedObjectContext];
    controller.selectedCar = [appDelegate managedObjectForModelIdentifier:[coder decodeObjectForKey:kSRFuelEventSelectedCarID]];

    if (controller.selectedCar == nil)
        return nil;

    return controller;
}


- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    [coder encodeObject:[appDelegate modelIdentifierForManagedObject:_selectedCar] forKey:kSRFuelEventSelectedCarID];
    [coder encodeBool:restoreExportSheet||isShowingExportSheet forKey:kSRFuelEventExportSheet];
    [coder encodeBool:restoreOpenIn||(openInController != nil) forKey:kSRFuelEventShowOpenIn];
    [coder encodeBool:restoreMailComposer|(mailComposeController != nil) forKey:kSRFuelEventShowComposer];

    // don't use a snapshot image for next launch when graph is currently visible
    if ([AppDelegate systemMajorVersion] >= 7)
        if ([self presentedViewController] != nil)
            [[UIApplication sharedApplication] ignoreSnapshotOnNextApplicationLaunch];

    [super encodeRestorableStateWithCoder:coder];
}


- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    restoreExportSheet = [coder decodeBoolForKey:kSRFuelEventExportSheet];
    restoreOpenIn = [coder decodeBoolForKey:kSRFuelEventShowOpenIn];
    restoreMailComposer = [coder decodeBoolForKey:kSRFuelEventShowComposer];

    [super decodeRestorableStateWithCoder:coder];

    // -> openradar #13438788
    [self.tableView reloadData];
}



#pragma mark -
#pragma mark Device Rotation



- (void)setObserveDeviceRotation:(BOOL)observeRotation
{
    if (observeRotation == YES && isObservingRotationEvents == NO) {

        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(orientationChanged:)
                   name:UIDeviceOrientationDidChangeNotification
                 object:[UIDevice currentDevice]];

    } else if (observeRotation == NO && isObservingRotationEvents == YES) {

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
    // Ignore rotation when sheets or alerts are visible
    if (openInController != nil)
        return;

    if (mailComposeController != nil)
        return;

    if (isShowingExportSheet || isPerformingRotation || isShowingAlert || !isObservingRotationEvents)
        return;

    // Switch view controllers according rotation state
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;

    if (UIDeviceOrientationIsLandscape (deviceOrientation) && [self presentedViewController] == nil) {

        isPerformingRotation = YES;
        _statisticsController.selectedCar = _selectedCar;
        [self presentViewController:_statisticsController animated:YES completion: ^{ isPerformingRotation = NO; }];

    } else if (UIDeviceOrientationIsPortrait (deviceOrientation) && [self presentedViewController] != nil) {

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
#pragma mark Export Support


- (void)validateExport
{
    self.navigationItem.rightBarButtonItem.enabled = ([[self.fetchedResultsController fetchedObjects] count] > 0);
}


- (NSString *)exportFilename
{
    NSString *rawFilename = [NSString stringWithFormat:@"%@__%@.csv", [_selectedCar valueForKey:@"name"], [_selectedCar valueForKey:@"numberPlate"]];
    NSCharacterSet* illegalCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];

    return [[rawFilename componentsSeparatedByCharactersInSet:illegalCharacters] componentsJoinedByString:@""];
}


- (NSURL*)exportURL
{
    return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", NSTemporaryDirectory(), [self exportFilename]]];
}


- (NSData*)exportTextData
{
    KSDistance odometerUnit = (KSDistance)[[_selectedCar valueForKey:@"odometerUnit"] integerValue];
    KSVolume fuelUnit = (KSVolume)[[_selectedCar valueForKey:@"fuelUnit"] integerValue];
    KSFuelConsumption consumptionUnit = (KSFuelConsumption)[[_selectedCar valueForKey:@"fuelConsumptionUnit"] integerValue];

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

    for (NSUInteger i = 0; i < [fetchedObjects count]; i++) {

        NSManagedObject *managedObject = fetchedObjects[i];

        NSDecimalNumber *distance = [managedObject valueForKey:@"distance"];
        NSDecimalNumber *fuelVolume = [managedObject valueForKey:@"fuelVolume"];
        NSDecimalNumber *price = [managedObject valueForKey:@"price"];

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

    NSDateFormatter *outputFormatter = [[NSDateFormatter alloc] init]; {

        [outputFormatter setDateStyle:kCFDateFormatterMediumStyle];
        [outputFormatter setTimeStyle:kCFDateFormatterNoStyle];

        NSArray *fetchedObjects = [self.fetchedResultsController fetchedObjects];
        NSUInteger fetchCount = [fetchedObjects count];

        NSString *from = [outputFormatter stringFromDate:[[fetchedObjects lastObject] valueForKey:@"timestamp"]];
        NSString *to = [outputFormatter stringFromDate:[fetchedObjects[0] valueForKey:@"timestamp"]];

        switch (fetchCount) {

            case 0:  period = _I18N(@""); break;
            case 1:  period = [NSString stringWithFormat:_I18N(@"on %@"), from]; break;
            default:period = [NSString stringWithFormat:_I18N(@"in the period from %@ to %@"), from, to]; break;
        }

        count = [NSString stringWithFormat:_I18N(((fetchCount == 1) ? @"%d item" : @"%d items")), fetchCount];
    }

    return [NSString stringWithFormat:_I18N(@"Here are your exported fuel data sets for %@ (%@) %@ (%@):\n"),
            [_selectedCar valueForKey:@"name"],
            [_selectedCar valueForKey:@"numberPlate"],
            period,
            count];
}



#pragma mark -
#pragma mark Export Objects via eMail



- (void)showOpenIn:(id)sender
{
    restoreOpenIn = NO;

    // write exported data
    NSData *data = [self exportTextData];
    NSError *error = nil;

    if ([data writeToURL:[self exportURL] options:NSDataWritingFileProtectionComplete error:&error] == NO) {

        [[[UIAlertView alloc] initWithTitle:_I18N(@"Export Failed")
                                    message:_I18N(@"Sorry, could not save the CSV-data for export.")
                                   delegate:self
                          cancelButtonTitle:nil
                          otherButtonTitles:_I18N(@"OK"), nil] show];
        return;
    }

    // show document interaction controller
    openInController = [UIDocumentInteractionController interactionControllerWithURL:[self exportURL]];

    openInController.delegate = self;
    openInController.name = [self exportFilename];
    openInController.UTI = @"public.comma-separated-values-text";

    if ([openInController presentOpenInMenuFromBarButtonItem:self.navigationItem.rightBarButtonItem animated:YES] == NO) {

        [[[UIAlertView alloc] initWithTitle:_I18N(@"Open In Failed")
                                    message:_I18N(@"Sorry, there seems to be no compatible App to open the data.")
                                   delegate:self
                          cancelButtonTitle:nil
                          otherButtonTitles:_I18N(@"OK"), nil] show];

        openInController = nil;
        return;
    }
}


- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller
{
    [[NSFileManager defaultManager] removeItemAtURL:[self exportURL] error:nil];

    openInController = nil;
}



#pragma mark -
#pragma mark Export Objects via eMail



- (void)showMailComposer:(id)sender
{
    restoreMailComposer = NO;

    if ([MFMailComposeViewController canSendMail]) {

        mailComposeController = [[MFMailComposeViewController alloc] init];

        // Copy look of navigation bar to compose window
        if ([AppDelegate systemMajorVersion] < 7) {

            UINavigationBar *navBar = [mailComposeController navigationBar];

            if (navBar != nil) {

                navBar.barStyle = UIBarStyleBlack;
                navBar.tintColor = [[[self navigationController] navigationBar] tintColor];
            }
        }

        // Setup the message
        [mailComposeController setMailComposeDelegate:self];
        [mailComposeController setSubject:[NSString stringWithFormat:_I18N(@"Your fuel data for %@"), [_selectedCar valueForKey:@"numberPlate"]]];
        [mailComposeController setMessageBody:[self exportTextDescription] isHTML:NO];
        [mailComposeController addAttachmentData:[self exportTextData] mimeType:@"text" fileName:[self exportFilename]];

        [self presentViewController:mailComposeController animated:YES completion:nil];
    }
}


- (void)mailComposeController:(MFMailComposeViewController*)mailComposer
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError*)error
{
    [self dismissViewControllerAnimated:YES completion: ^{

        mailComposeController = nil;

        if (result == MFMailComposeResultFailed)
        {
            [[[UIAlertView alloc] initWithTitle:_I18N(@"Sending Failed")
                                        message:_I18N(@"The exported fuel data could not be sent.")
                                       delegate:self
                              cancelButtonTitle:_I18N(@"OK")
                              otherButtonTitles:nil] show];
        }
    }];
}



#pragma mark -
#pragma mark Export Action Sheet



- (void)showExportSheet:(id)sender
{
    isShowingExportSheet = YES;
    restoreExportSheet   = NO;

    NSString *firstButton, *secondButton;

    if ([MFMailComposeViewController canSendMail]) {
        firstButton  = _I18N(@"Send as Email");
        secondButton = _I18N(@"Open in ...");
    } else {
        firstButton  = _I18N(@"Open in ...");
        secondButton = nil;
    }

    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:_I18N(@"Export Fuel Data in CSV Format")
                                                       delegate:self
                                              cancelButtonTitle:_I18N(@"Cancel")
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:firstButton, secondButton, nil];

    sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [sheet showFromTabBar:self.tabBarController.tabBar];
}


- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    isShowingExportSheet = NO;

    if (buttonIndex != [actionSheet cancelButtonIndex]) {

        if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:_I18N(@"Open in ...")])
            dispatch_async(dispatch_get_main_queue(), ^{ [self showOpenIn:nil]; });
        else
            dispatch_async(dispatch_get_main_queue(), ^{ [self showMailComposer:nil]; });
    }
}



#pragma mark -
#pragma mark UIAlertViewDelegate



- (void)willPresentAlertView:(UIAlertView *)alertView
{
    isShowingAlert = YES;
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    isShowingAlert = NO;
}



#pragma mark -
#pragma mark UITableViewDataSource



- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath
{
    ShadedTableViewCell *tableCell = (ShadedTableViewCell*)cell;
    NSManagedObject *managedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];

    NSManagedObject *car = [managedObject valueForKey:@"car"];
    NSDecimalNumber *distance = [managedObject valueForKey:@"distance"];
    NSDecimalNumber *fuelVolume = [managedObject valueForKey:@"fuelVolume"];
    NSDecimalNumber *price = [managedObject valueForKey:@"price"];

    KSDistance        odometerUnit = (KSDistance)[[car valueForKey:@"odometerUnit"] integerValue];
    KSFuelConsumption consumptionUnit = (KSFuelConsumption)[[car valueForKey:@"fuelConsumptionUnit"] integerValue];

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

    label = [tableCell botLeftLabel];
    label.text = [NSString stringWithFormat:@"%@ %@",
                    [[AppDelegate sharedDistanceFormatter] stringFromNumber:convertedDistance],
                    [AppDelegate odometerUnitString:odometerUnit]];
    tableCell.botLeftAccessibilityLabel = nil;


    // Price
    label = [tableCell topRightLabel];
    label.text = [[AppDelegate sharedCurrencyFormatter] stringFromNumber:[fuelVolume decimalNumberByMultiplyingBy:price]];
    tableCell.topRightAccessibilityLabel = label.text;


    // Consumption combined with inherited data from earlier events
    NSString *consumptionDescription;

    if ([[managedObject valueForKey:@"filledUp"] boolValue])
    {
        distance = [distance decimalNumberByAdding:[managedObject valueForKey:@"inheritedDistance"]];
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
                     inManagedObjectContext:_managedObjectContext
                        forceOdometerUpdate:NO];

        [(AppDelegate *)[[UIApplication sharedApplication] delegate] saveContext:_managedObjectContext];
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

    editController.managedObjectContext =  _managedObjectContext;
    editController.event = [self.fetchedResultsController objectAtIndexPath:indexPath];

    [self.navigationController pushViewController:editController animated:YES];
}



#pragma mark -
#pragma mark Fetch Request



- (NSFetchRequest*)fetchRequest
{
    if (_fetchRequest == nil)
        _fetchRequest = [AppDelegate fetchRequestForEventsForCar:_selectedCar
                                                       afterDate:nil
                                                     dateMatches:YES
                                          inManagedObjectContext:_managedObjectContext];

    return _fetchRequest;
}



#pragma mark -
#pragma mark Fetched Results Controller



- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController == nil)
    {
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSString *cacheName = [appDelegate cacheNameForFuelEventFetchWithParent:_selectedCar];

        NSFetchedResultsController *fetchController = [[NSFetchedResultsController alloc] initWithFetchRequest:self.fetchRequest
                                                                                          managedObjectContext:_managedObjectContext
                                                                                            sectionNameKeyPath:nil
                                                                                                     cacheName:cacheName];

        fetchController.delegate = self;
        _fetchedResultsController = fetchController;


        // Perform the data fetch
        NSError *error = nil;

        if (! [_fetchedResultsController performFetch:&error])
            [NSException raise:NSGenericException format:@"%@", [error localizedDescription]];
    }

    return _fetchedResultsController;
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
    [_statisticsController invalidateCaches];
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
