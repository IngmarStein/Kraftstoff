// FuelEventController.m
//
// Kraftstoff


#import "FuelEventController.h"
#import "ShadowTableView.h"
#import "ShadedTableViewCell.h"
#import "FuelStatisticsPageController.h"
#import "FuelEventEditorController.h"
#import "AppDelegate.h"


@interface FuelEventController (private)

- (void)localeChanged: (id)object;

#pragma mark Rotation

- (void)setWaitForRotationAck: (BOOL)flag;
- (void)rotationAckExpired: (id)object;

#pragma mark Export

- (void)validateExport;
- (void)askExportObjects: (id)sender;

- (void)mailComposeController: (MFMailComposeViewController*)mailComposer
          didFinishWithResult: (MFMailComposeResult)result
                        error: (NSError*)error;

- (void)configureCell: (UITableViewCell*)cell atIndexPath: (NSIndexPath*)indexPath;

@end


@implementation FuelEventController

@synthesize selectedCar;
@synthesize managedObjectContext;
@synthesize statisticsController;
@synthesize fetchRequest;
@synthesize fetchedResultsController;



#pragma mark -
#pragma mark View Lifecycle



- (id)initWithNibName: (NSString*)nibName bundle: (NSBundle*)nibBundle
{
    if ((self = [super initWithNibName: nibName bundle: nibBundle]))
    {
        // Alternate view controller for statistics
        self.statisticsController = [[FuelStatisticsPageController alloc]
                                           initWithNibName: @"FuelStatisticsPageController"
                                                    bundle: nil];

        self.statisticsController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }

    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    isEditing                  = NO;
    isShowingMailComposer      = NO;
    isShowingAskForExportSheet = NO;
    isObservingRotationEvents  = NO;
    isWaitingForACK            = NO;

    // Configure root view
    self.title = [self.selectedCar valueForKey: @"name"];

    // Export button in navigation bar
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                initWithBarButtonSystemItem: UIBarButtonSystemItemAction
                                                                     target: self
                                                                     action: @selector (askExportObjects:)];

    self.navigationItem.rightBarButtonItem.enabled = NO;

    // Observe locale changes
    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector (localeChanged:)
               name: NSCurrentLocaleDidChangeNotification
             object: nil];

    if ([self modalViewController])
        [self dismissModalViewControllerAnimated: NO];
}


- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}


- (void)localeChanged: (id)object
{
    [self.tableView reloadData];
}



#pragma mark -
#pragma mark Memory Management



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}



#pragma mark -
#pragma mark Device Rotation



- (void)viewWillAppear: (BOOL)animated
{
    [super viewWillAppear: animated];

    [self validateExport];
}


- (void)viewDidAppear: (BOOL)animated
{
    [super viewDidAppear: animated];

    if (! isObservingRotationEvents)
    {
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

        [[NSNotificationCenter defaultCenter]
                addObserver: self
                   selector: @selector (orientationChanged:)
                       name: UIDeviceOrientationDidChangeNotification
                     object: [UIDevice currentDevice]];

        isObservingRotationEvents = YES;
    }

    [self setWaitForRotationAck: NO];
}


- (void)viewWillDisappear: (BOOL)animated
{
    [super viewWillDisappear: animated];

    if (isObservingRotationEvents && [self modalViewController] == nil)
    {
        [[NSNotificationCenter defaultCenter]
                removeObserver: self
                          name: UIDeviceOrientationDidChangeNotification
                        object: [UIDevice currentDevice]];

        [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];

        isObservingRotationEvents = NO;
    }

    [self setWaitForRotationAck: NO];
}


- (void)orientationChanged: (NSNotification*)aNotification
{
    // Ignore rotation when:
    //  - showing the export sheet
    //  - composing an export mail
    //  - the previous rotation isn't finished yet
    //  - rotations are no longer observed
    if (isShowingAskForExportSheet || isShowingMailComposer || isWaitingForACK || !isObservingRotationEvents)
        return;

    // Switch view controllers according rotation state
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;

    if (UIDeviceOrientationIsLandscape (deviceOrientation) && [self modalViewController] == nil)
    {
        self.statisticsController.selectedCar = self.selectedCar;

        [[UIApplication sharedApplication] setStatusBarStyle: UIStatusBarStyleBlackOpaque animated: NO];
        [self presentModalViewController: self.statisticsController animated: YES];

        [self setWaitForRotationAck: YES];
    }
    else if (UIDeviceOrientationIsPortrait (deviceOrientation) && [self modalViewController] != nil)
    {
        [[UIApplication sharedApplication] setStatusBarStyle: UIStatusBarStyleDefault animated: NO];
        [self dismissModalViewControllerAnimated: YES];

        [self setWaitForRotationAck: YES];
    }
}


- (void)setWaitForRotationAck: (BOOL)enabled
{
    if (enabled)
        [self performSelector: @selector(rotationAckExpired:) withObject: nil afterDelay: 0.5];
    else
        [FuelEventController cancelPreviousPerformRequestsWithTarget: self];

    isWaitingForACK = enabled;
}


- (void)rotationAckExpired: (id)object
{
    isWaitingForACK = NO;
}


- (BOOL)shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}



#pragma mark -
#pragma mark Export Objects via eMail



- (void)validateExport
{
    // Sending mail needs a configured mail account
    self.navigationItem.rightBarButtonItem.enabled = ([MFMailComposeViewController canSendMail] && [[[self fetchedResultsController] fetchedObjects] count] > 0);
}


- (NSData*)exportTextData
{
    KSDistance        odometerUnit    = [[selectedCar valueForKey: @"odometerUnit"]        integerValue];
    KSVolume          fuelUnit        = [[selectedCar valueForKey: @"fuelUnit"]            integerValue];
    KSFuelConsumption consumptionUnit = [[selectedCar valueForKey: @"fuelConsumptionUnit"] integerValue];

    NSMutableString *dataString = [NSMutableString stringWithCapacity: 4096];

    [dataString appendString: _I18N (@"yyyy-MM-dd")];
    [dataString appendString: @";"];

    [dataString appendString: _I18N (@"HH:mm")];
    [dataString appendString: @";"];

    [dataString appendString: [AppDelegate odometerUnitDescription: odometerUnit]];
    [dataString appendString: @";"];

    [dataString appendString: [AppDelegate fuelUnitDescription: fuelUnit discernGallons: YES]];
    [dataString appendString: @";"];

    [dataString appendString: _I18N (@"Full Fill-Up")];
    [dataString appendString: @";"];

    [dataString appendString: [AppDelegate fuelPriceUnitDescription: fuelUnit]];
    [dataString appendString: @";"];

    [dataString appendString: [AppDelegate consumptionUnitDescription: consumptionUnit]];
    [dataString appendString: @"\n"];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat: @"yyyy-MM-dd';'HH:mm"];
    [dateFormatter setLocale: [NSLocale systemLocale]];

    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setNumberStyle: kCFNumberFormatterDecimalStyle];
    [numberFormatter setLocale: [NSLocale systemLocale]];

    NSArray *fetchedObjects = [self.fetchedResultsController fetchedObjects];

    for (NSUInteger i = 0; i < [fetchedObjects count]; i++)
    {
        NSManagedObject *managedObject = [fetchedObjects objectAtIndex: i];

        NSDecimalNumber *distance   = [managedObject valueForKey: @"distance"];
        NSDecimalNumber *fuelVolume = [managedObject valueForKey: @"fuelVolume"];
        NSDecimalNumber *price      = [managedObject valueForKey: @"price"];

        [dataString appendFormat: @"%@;\"%@\";\"%@\";%@;\"%@\";\"%@\"\n",
            [dateFormatter stringFromDate: [managedObject valueForKey: @"timestamp"]],
            [numberFormatter stringFromNumber: [AppDelegate distanceForKilometers: distance withUnit: odometerUnit]],
            [numberFormatter stringFromNumber: [AppDelegate volumeForLiters: fuelVolume withUnit: fuelUnit]],
            [[managedObject valueForKey: @"filledUp"] boolValue] ? _I18N (@"Yes") : _I18N (@"No"),
            [numberFormatter stringFromNumber: [AppDelegate pricePerUnit: price withUnit: fuelUnit]],

            [[managedObject valueForKey: @"filledUp"] boolValue]
                ? [numberFormatter stringFromNumber: [AppDelegate consumptionForDistance: [distance   decimalNumberByAdding: [managedObject valueForKey: @"inheritedDistance"]]
                                                                                  Volume: [fuelVolume decimalNumberByAdding: [managedObject valueForKey: @"inheritedFuelVolume"]]
                                                                                withUnit: consumptionUnit]]
                : @" "
         ];
    }


    return [dataString dataUsingEncoding:NSUTF8StringEncoding];
}


- (NSString*)exportTextDescription
{
    NSString *period;

    NSDateFormatter *outputFormatter = [[NSDateFormatter alloc] init];
    {
        [outputFormatter setDateStyle: kCFDateFormatterMediumStyle];
        [outputFormatter setTimeStyle: kCFDateFormatterNoStyle];

        NSArray *fetchedObjects = [self.fetchedResultsController fetchedObjects];

        NSString *from = [outputFormatter stringFromDate: [[fetchedObjects lastObject]       valueForKey: @"timestamp"]];
        NSString *to   = [outputFormatter stringFromDate: [[fetchedObjects objectAtIndex: 0] valueForKey: @"timestamp"]];

        period = ([fetchedObjects count] > 1)
                        ? [NSString stringWithFormat: _I18N (@"in the period from %@ to %@"), from, to]
                        : [NSString stringWithFormat: _I18N (@"on %@"), from];
    }

    return [NSString stringWithFormat: _I18N (@"Here is your fuel data for %@ (%@) %@.\n"),
                [self.selectedCar valueForKey: @"name"],
                [self.selectedCar valueForKey: @"numberPlate"],
                period];
}


- (void)mailComposeController: (MFMailComposeViewController*)mailComposer
          didFinishWithResult: (MFMailComposeResult)result
                        error: (NSError*)error
{
    isShowingMailComposer = NO;
    [self dismissModalViewControllerAnimated: YES];

    if (result == MFMailComposeResultFailed)
    {
        [[[UIAlertView alloc] initWithTitle: _I18N (@"Sending Failed")
                                    message: _I18N (@"The exported fuel data could not be sent.")
                                   delegate: nil
                          cancelButtonTitle: _I18N (@"OK")
                          otherButtonTitles: nil] show];
    }
}



#pragma mark -
#pragma mark Export Action Sheet



- (void)askExportObjects: (id)sender
{
    isShowingAskForExportSheet = YES;

    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle: _I18N (@"Export Fuel Data as CSV via Mail?")
                                                       delegate: self
                                              cancelButtonTitle: _I18N (@"Cancel")
                                         destructiveButtonTitle: nil
                                              otherButtonTitles: _I18N (@"Export"), nil];

    sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;

    [sheet showFromTabBar: self.tabBarController.tabBar];
}



- (void)actionSheet: (UIActionSheet*)actionSheet clickedButtonAtIndex: (NSInteger)buttonIndex
{
    isShowingAskForExportSheet = NO;

    if (buttonIndex != actionSheet.cancelButtonIndex)
    {
        MFMailComposeViewController *mailComposer = [[MFMailComposeViewController alloc] init];

        // Copy look of navigation bar to compose window
        UINavigationBar *navBar = [mailComposer navigationBar];

        if (navBar != nil)
        {
            navBar.barStyle  = UIBarStyleBlack;
            navBar.tintColor = [[[self navigationController] navigationBar] tintColor];
        }

        // Setup the message
        [mailComposer setMailComposeDelegate: self];
        [mailComposer setSubject: [NSString stringWithFormat: _I18N (@"Your fuel data: %@"), [self.selectedCar valueForKey: @"numberPlate"]]];
        [mailComposer setMessageBody: [self exportTextDescription] isHTML: NO];

        [mailComposer addAttachmentData: [self exportTextData]
                               mimeType: @"text"
                               fileName: [NSString stringWithFormat: @"%@__%@.csv",
                                            [self.selectedCar valueForKey: @"name"],
                                            [self.selectedCar valueForKey: @"numberPlate"]]];

        isShowingMailComposer = YES;
        [self presentModalViewController: mailComposer animated: YES];
    }
}



#pragma mark -
#pragma mark UITableViewDataSource



- (void)configureCell: (UITableViewCell*)cell atIndexPath: (NSIndexPath*)indexPath
{
    ShadedTableViewCell *tableCell = (ShadedTableViewCell*)cell;
    NSManagedObject *managedObject = [self.fetchedResultsController objectAtIndexPath: indexPath];

    NSManagedObject *car        = [managedObject valueForKey: @"car"];
    NSDecimalNumber *distance   = [managedObject valueForKey: @"distance"];
    NSDecimalNumber *fuelVolume = [managedObject valueForKey: @"fuelVolume"];
    NSDecimalNumber *price      = [managedObject valueForKey: @"price"];

    KSDistance        odometerUnit    = [[car valueForKey: @"odometerUnit"]        integerValue];
    KSFuelConsumption consumptionUnit = [[car valueForKey: @"fuelConsumptionUnit"] integerValue];

    UILabel *label;


    // Timestamp
    label      = [tableCell topLeftLabel];
    label.text = [[AppDelegate sharedDateFormatter] stringForObjectValue: [managedObject valueForKey: @"timestamp"]];
    tableCell.topLeftAccessibilityLabel = nil;


    // Distance
    NSDecimalNumber *convertedDistance;

    if (odometerUnit == KSDistanceKilometer)
        convertedDistance = distance;
    else
        convertedDistance = [distance decimalNumberByDividingBy: [AppDelegate kilometersPerStatuteMile]];

    label      = [tableCell botLeftLabel];
    label.text = [NSString stringWithFormat: @"%@ %@",
                    [[AppDelegate sharedDistanceFormatter] stringFromNumber: convertedDistance],
                    [AppDelegate odometerUnitString: odometerUnit]];
    tableCell.botLeftAccessibilityLabel = nil;


    // Price
    label      = [tableCell topRightLabel];
    label.text = [[AppDelegate sharedCurrencyFormatter] stringFromNumber: [fuelVolume decimalNumberByMultiplyingBy: price]];
    tableCell.topRightAccessibilityLabel = label.text;


    // Consumption combined with inherited data from earlier events
    NSString *consumptionDescription;

    if ([[managedObject valueForKey: @"filledUp"] boolValue])
    {
        distance   = [distance   decimalNumberByAdding: [managedObject valueForKey: @"inheritedDistance"]];
        fuelVolume = [fuelVolume decimalNumberByAdding: [managedObject valueForKey: @"inheritedFuelVolume"]];

        NSDecimalNumber *avg = [AppDelegate consumptionForDistance: distance
                                                            Volume: fuelVolume
                                                          withUnit: consumptionUnit];

        consumptionDescription = [[AppDelegate sharedFuelVolumeFormatter] stringFromNumber: avg];

        tableCell.botRightAccessibilityLabel = [NSString stringWithFormat: @", %@ %@",
                                                    consumptionDescription,
                                                    [AppDelegate consumptionUnitShadedTableViewCellDescription: consumptionUnit]];
    }
    else
    {
        consumptionDescription = _I18N (@"-");

        tableCell.botRightAccessibilityLabel = _I18N (@"fuel mileage not available");
    }

    label = [tableCell botRightLabel];
    label.text = [NSString stringWithFormat: @"%@ %@", consumptionDescription, [AppDelegate consumptionUnitString: consumptionUnit]];
}


- (NSInteger)numberOfSectionsInTableView: (UITableView*)tableView
{
    return [[self.fetchedResultsController sections] count];
}


- (NSInteger)tableView: (UITableView*)tableView numberOfRowsInSection: (NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex: section];

    return [sectionInfo numberOfObjects];
}


- (UITableViewCell*)tableView: (UITableView*)tableView cellForRowAtIndexPath: (NSIndexPath*)indexPath
{
    static NSString *CellIdentifier = @"FuelCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier];

    if (cell == nil)
        cell = [[ShadedTableViewCell alloc] initWithStyle: UITableViewCellStyleDefault
                                           reuseIdentifier: CellIdentifier
                                      enlargeTopRightLabel: NO];

    [self configureCell: cell atIndexPath: indexPath];
    return cell;
}


- (void)tableView: (UITableView*)tableView commitEditingStyle: (UITableViewCellEditingStyle)editingStyle forRowAtIndexPath: (NSIndexPath*)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        [AppDelegate removeEventFromArchive: [self.fetchedResultsController objectAtIndexPath: indexPath]
                     inManagedObjectContext: self.managedObjectContext
                        forceOdometerUpdate: NO];

        [[AppDelegate sharedDelegate] saveContext: self.managedObjectContext];
    }
}



#pragma mark -
#pragma mark UITableViewDelegate



- (void)tableView: (UITableView*)tableView didSelectRowAtIndexPath: (NSIndexPath*)indexPath
{
    FuelEventEditorController *editController = [[FuelEventEditorController alloc] initWithNibName: @"FuelEventEditor" bundle: nil];

    editController.managedObjectContext    =  self.managedObjectContext;
    editController.event                   = [self.fetchedResultsController objectAtIndexPath: indexPath];

    [self.navigationController pushViewController: editController animated: YES];
}



#pragma mark -
#pragma mark Fetch Request



- (NSFetchRequest*)fetchRequest
{
    if (fetchRequest == nil)
    {
        self.fetchRequest = [AppDelegate fetchRequestForEventsForCar: self.selectedCar
                                                           afterDate: nil
                                                         dateMatches: YES
                                              inManagedObjectContext: self.managedObjectContext];
    }

    return fetchRequest;
}



#pragma mark -
#pragma mark Fetched Results Controller



- (NSFetchedResultsController*)fetchedResultsController
{
    if (fetchedResultsController == nil)
    {
        NSString *cacheName = [AppDelegate cacheNameForFuelEventFetchWithParent: self.selectedCar];
        NSFetchedResultsController *fetchController = [[NSFetchedResultsController alloc] initWithFetchRequest: self.fetchRequest
                                                                                          managedObjectContext: self.managedObjectContext
                                                                                            sectionNameKeyPath: nil
                                                                                                     cacheName: cacheName];

        fetchController.delegate = self;
        self.fetchedResultsController = fetchController;


        // Perform the data fetch
        NSError *error = nil;

        if (! [fetchedResultsController performFetch: &error])
        {
            [NSException raise: NSGenericException format: @"%@", [error localizedDescription]];
        }
    }

    return fetchedResultsController;
}



#pragma mark -
#pragma mark NSFetchedResultsControllerDelegate



- (void)controllerWillChangeContent: (NSFetchedResultsController*)controller
{
    [self.tableView beginUpdates];
}


- (void)controller: (NSFetchedResultsController*)controller
  didChangeSection: (id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex: (NSUInteger)sectionIndex
     forChangeType: (NSFetchedResultsChangeType)type
{
    switch (type)
    {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections: [NSIndexSet indexSetWithIndex: sectionIndex]
                          withRowAnimation: UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections: [NSIndexSet indexSetWithIndex: sectionIndex]
                          withRowAnimation: UITableViewRowAnimationFade];
            break;
    }
}


- (void)controller: (NSFetchedResultsController*)controller
   didChangeObject: (id)object
       atIndexPath: (NSIndexPath*)indexPath
     forChangeType: (NSFetchedResultsChangeType)type
      newIndexPath: (NSIndexPath*)newIndexPath
{
    UITableView *tableView = self.tableView;

    switch (type)
    {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths: [NSArray arrayWithObject: newIndexPath]
                             withRowAnimation: UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths: [NSArray arrayWithObject: indexPath]
                             withRowAnimation: UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths: [NSArray arrayWithObject: indexPath]
                             withRowAnimation: UITableViewRowAnimationFade];

            [tableView insertRowsAtIndexPaths: [NSArray arrayWithObject: newIndexPath]
                             withRowAnimation: UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
            [self configureCell: [tableView cellForRowAtIndexPath: indexPath]
                    atIndexPath: indexPath];
            break;
    }
}


- (void)controllerDidChangeContent: (NSFetchedResultsController*)controller
{
    [self.tableView endUpdates];

    [self validateExport];
    [self.statisticsController invalidateCaches];
}

@end
