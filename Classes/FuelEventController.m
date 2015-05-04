// FuelEventController.m
//
// Kraftstoff


#import "FuelEventController.h"
#import "FuelStatisticsPageController.h"
#import "AppDelegate.h"
#import "kraftstoff-Swift.h"

@interface FuelEventController ()

@property (nonatomic, assign) BOOL isShowingAlert;

@end


@implementation FuelEventController
{
    BOOL isObservingRotationEvents;
    BOOL isPerformingRotation;
    BOOL isShowingExportSheet;
    BOOL restoreExportSheet;
    BOOL restoreOpenIn;
    BOOL restoreMailComposer;

    UIDocumentInteractionController *openInController;
    MFMailComposeViewController *mailComposeController;
}

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

	_statisticsController = [self.storyboard instantiateViewControllerWithIdentifier:@"FuelStatisticsPageController"];

	isObservingRotationEvents  = NO;
    isPerformingRotation       = NO;
    isShowingExportSheet       = NO;
    self.isShowingAlert        = NO;
    restoreExportSheet         = NO;
    restoreOpenIn              = NO;
    restoreMailComposer        = NO;

    // Configure root view
    self.title = _selectedCar.name;

    // Export button in navigation bar
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                     target:self
                                                                     action:@selector(showExportSheet:)];

    self.navigationItem.rightBarButtonItem.enabled = NO;

    // Reset tint color
    self.navigationController.navigationBar.tintColor = nil;

    // Background image
	UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
	backgroundView.backgroundColor = [UIColor colorWithRed:0.935 green:0.935 blue:0.956 alpha:1.0];
    UIImageView *backgroundImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Pumps"]];
	backgroundImage.translatesAutoresizingMaskIntoConstraints = NO;
	[backgroundView addSubview:backgroundImage];
	[backgroundView addConstraint:[NSLayoutConstraint constraintWithItem:backgroundView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:backgroundImage attribute:NSLayoutAttributeBottom multiplier:1.0 constant:90.0]];
	[backgroundView addConstraint:[NSLayoutConstraint constraintWithItem:backgroundView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:backgroundImage attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0]];
	self.tableView.backgroundView = backgroundView;

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

	UIStoryboard *storyboard = [coder decodeObjectForKey:UIStateRestorationViewControllerStoryboardKey];
    FuelEventController *controller = [storyboard instantiateViewControllerWithIdentifier:@"FuelEventController"];
    controller.managedObjectContext = [appDelegate managedObjectContext];
    controller.selectedCar = (Car *)[appDelegate managedObjectForModelIdentifier:[coder decodeObjectForKey:kSRFuelEventSelectedCarID]];

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

    if (isShowingExportSheet || isPerformingRotation || self.isShowingAlert || !isObservingRotationEvents)
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
    NSString *rawFilename = [NSString stringWithFormat:@"%@__%@.csv", _selectedCar.name, _selectedCar.numberPlate];
    NSCharacterSet* illegalCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];

    return [[rawFilename componentsSeparatedByCharactersInSet:illegalCharacters] componentsJoinedByString:@""];
}


- (NSURL*)exportURL
{
    return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", NSTemporaryDirectory(), [self exportFilename]]];
}


- (NSData*)exportTextData
{
    KSDistance odometerUnit = _selectedCar.ksOdometerUnit;
    KSVolume fuelUnit = _selectedCar.ksFuelUnit;
    KSFuelConsumption consumptionUnit = _selectedCar.ksFuelConsumptionUnit;

    NSMutableString *dataString = [NSMutableString stringWithCapacity:4096];

    [dataString appendString:NSLocalizedString(@"yyyy-MM-dd", @"")];
    [dataString appendString:@";"];

    [dataString appendString:NSLocalizedString(@"HH:mm", @"")];
    [dataString appendString:@";"];

    [dataString appendString:[Units odometerUnitDescription:odometerUnit pluralization:YES]];
    [dataString appendString:@";"];

    [dataString appendString:[Units fuelUnitDescription:fuelUnit discernGallons:YES pluralization:YES]];
    [dataString appendString:@";"];

    [dataString appendString:NSLocalizedString(@"Full Fill-Up", @"")];
    [dataString appendString:@";"];

    [dataString appendString:[Units fuelPriceUnitDescription:fuelUnit]];
    [dataString appendString:@";"];

    [dataString appendString:[Units consumptionUnitDescription:consumptionUnit]];
    [dataString appendString:@"\n"];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd';'HH:mm";
    dateFormatter.locale = [NSLocale systemLocale];

    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    numberFormatter.locale = [NSLocale currentLocale];
    numberFormatter.usesGroupingSeparator = NO;
	numberFormatter.alwaysShowsDecimalSeparator = YES;
    numberFormatter.minimumFractionDigits = 2;

    NSArray *fetchedObjects = [self.fetchedResultsController fetchedObjects];

    for (NSUInteger i = 0; i < [fetchedObjects count]; i++) {

        FuelEvent *managedObject = fetchedObjects[i];

        NSDecimalNumber *distance = managedObject.distance;
        NSDecimalNumber *fuelVolume = managedObject.fuelVolume;
        NSDecimalNumber *price = managedObject.price;

        [dataString appendFormat:@"%@;\"%@\";\"%@\";%@;\"%@\";\"%@\"\n",

         [dateFormatter stringFromDate:managedObject.timestamp],
         [numberFormatter stringFromNumber:[Units distanceForKilometers:distance withUnit:odometerUnit]],
         [numberFormatter stringFromNumber:[Units volumeForLiters:fuelVolume withUnit:fuelUnit]],
         managedObject.filledUp ? NSLocalizedString(@"Yes", @"") : NSLocalizedString(@"No", @""),
         [numberFormatter stringFromNumber:[Units pricePerUnit:price withUnit:fuelUnit]],

         managedObject.filledUp
         ? [numberFormatter stringFromNumber:
            [Units consumptionForKilometers:[distance decimalNumberByAdding:managedObject.inheritedDistance]
                                           liters:[fuelVolume decimalNumberByAdding:managedObject.inheritedFuelVolume]
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

		FuelEvent *last = fetchedObjects.lastObject;
		FuelEvent *first = fetchedObjects.firstObject;
        NSString *from = [outputFormatter stringFromDate:last.timestamp];
        NSString *to = [outputFormatter stringFromDate:first.timestamp];

        switch (fetchCount) {

            case 0:  period = NSLocalizedString(@"", @""); break;
            case 1:  period = [NSString stringWithFormat:NSLocalizedString(@"on %@", @""), from]; break;
            default:period = [NSString stringWithFormat:NSLocalizedString(@"in the period from %@ to %@", @""), from, to]; break;
        }

        count = [NSString stringWithFormat:NSLocalizedString(((fetchCount == 1) ? @"%d item" : @"%d items"), @""), fetchCount];
    }

    return [NSString stringWithFormat:NSLocalizedString(@"Here are your exported fuel data sets for %@ (%@) %@ (%@):\n", @""),
            _selectedCar.name,
            _selectedCar.numberPlate,
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

		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Export Failed", @"")
																				 message:NSLocalizedString(@"Sorry, could not save the CSV-data for export.", @"")
																		  preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
																style:UIAlertActionStyleDefault
															  handler:^(UIAlertAction * action) { self.isShowingAlert = NO; }];
		[alertController addAction:defaultAction];
		self.isShowingAlert = YES;
		[self presentViewController:alertController animated:YES completion:NULL];
        return;
    }

    // show document interaction controller
    openInController = [UIDocumentInteractionController interactionControllerWithURL:[self exportURL]];

    openInController.delegate = self;
    openInController.name = [self exportFilename];
    openInController.UTI = @"public.comma-separated-values-text";

    if ([openInController presentOpenInMenuFromBarButtonItem:self.navigationItem.rightBarButtonItem animated:YES] == NO) {

		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Open In Failed", @"")
																				 message:NSLocalizedString(@"Sorry, there seems to be no compatible app to open the data.", @"")
																		  preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
																style:UIAlertActionStyleDefault
															  handler:^(UIAlertAction * action) { self.isShowingAlert = NO; }];
		[alertController addAction:defaultAction];
		self.isShowingAlert = YES;
		[self presentViewController:alertController animated:YES completion:NULL];

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

        // Setup the message
        [mailComposeController setMailComposeDelegate:self];
        [mailComposeController setSubject:[NSString stringWithFormat:NSLocalizedString(@"Your fuel data for %@", @""), _selectedCar.numberPlate]];
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

        if (result == MFMailComposeResultFailed) {
			UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Sending Failed", @"")
																					 message:NSLocalizedString(@"The exported fuel data could not be sent.", @"")
																			  preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
																	style:UIAlertActionStyleDefault
																  handler:^(UIAlertAction * action) { self.isShowingAlert = NO; }];
			[alertController addAction:defaultAction];
			self.isShowingAlert = YES;
			[self presentViewController:alertController animated:YES completion:NULL];
        }
    }];
}



#pragma mark -
#pragma mark Export Action Sheet



- (void)showExportSheet:(id)sender
{
    isShowingExportSheet = YES;
    restoreExportSheet   = NO;

	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Export Fuel Data in CSV Format", @"")
																			 message:nil
																	  preferredStyle:UIAlertControllerStyleActionSheet];
	UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"")
														   style:UIAlertActionStyleCancel
														 handler:^(UIAlertAction * action) {
															 self->isShowingExportSheet = NO;
														 }];
	UIAlertAction *mailAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Send as Email", @"")
														   style:UIAlertActionStyleDefault
														 handler:^(UIAlertAction * action) {
															 self->isShowingExportSheet = NO;
															 dispatch_async(dispatch_get_main_queue(), ^{ [self showMailComposer:nil]; });
														 }];
	UIAlertAction *openInAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Open in ...", @"")
														   style:UIAlertActionStyleDefault
														 handler:^(UIAlertAction * action) {
															 self->isShowingExportSheet = NO;
															 dispatch_async(dispatch_get_main_queue(), ^{ [self showOpenIn:nil]; });
														 }];
	if ([MFMailComposeViewController canSendMail]) {
		[alertController addAction:mailAction];
	}
	[alertController addAction:openInAction];
	[alertController addAction:cancelAction];

	[self presentViewController:alertController animated:YES completion:NULL];
}


#pragma mark -
#pragma mark UITableViewDataSource



- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath
{
    QuadInfoCell *tableCell = (QuadInfoCell*)cell;
    FuelEvent *managedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];

    Car *car = managedObject.car;
    NSDecimalNumber *distance = managedObject.distance;
    NSDecimalNumber *fuelVolume = managedObject.fuelVolume;
    NSDecimalNumber *price = managedObject.price;

    KSDistance        odometerUnit = car.ksOdometerUnit;
    KSFuelConsumption consumptionUnit = car.ksFuelConsumptionUnit;

    UILabel *label;


    // Timestamp
    label      = [tableCell topLeftLabel];
    label.text = [[Formatters sharedDateFormatter] stringForObjectValue:managedObject.timestamp];
    tableCell.topLeftAccessibilityLabel = nil;


    // Distance
    NSDecimalNumber *convertedDistance;

    if (odometerUnit == KSDistanceKilometer)
        convertedDistance = distance;
    else
        convertedDistance = [distance decimalNumberByDividingBy:[Units kilometersPerStatuteMile]];

    label = [tableCell botLeftLabel];
    label.text = [NSString stringWithFormat:@"%@ %@",
                    [[Formatters sharedDistanceFormatter] stringFromNumber:convertedDistance],
                    [Units odometerUnitString:odometerUnit]];
    tableCell.botLeftAccessibilityLabel = nil;


    // Price
    label = [tableCell topRightLabel];
    label.text = [[Formatters sharedCurrencyFormatter] stringFromNumber:[fuelVolume decimalNumberByMultiplyingBy:price]];
    tableCell.topRightAccessibilityLabel = label.text;


    // Consumption combined with inherited data from earlier events
    NSString *consumptionDescription;

    if (managedObject.filledUp) {

        distance = [distance decimalNumberByAdding:managedObject.inheritedDistance];
        fuelVolume = [fuelVolume decimalNumberByAdding:managedObject.inheritedFuelVolume];

        NSDecimalNumber *avg = [Units consumptionForKilometers:distance
                                                              liters:fuelVolume
                                                              inUnit:consumptionUnit];

        consumptionDescription = [[Formatters sharedFuelVolumeFormatter] stringFromNumber:avg];

        tableCell.botRightAccessibilityLabel = [NSString stringWithFormat:@", %@ %@",
                                                    consumptionDescription,
                                                    [Units consumptionUnitAccesibilityDescription:consumptionUnit]];

    } else {

        consumptionDescription = NSLocalizedString(@"-", @"");
        tableCell.botRightAccessibilityLabel = NSLocalizedString(@"fuel mileage not available", @"");
    }

    label = [tableCell botRightLabel];
    label.text = [NSString stringWithFormat:@"%@ %@", consumptionDescription, [Units consumptionUnitString:consumptionUnit]];
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
        cell = [[QuadInfoCell alloc] initWithStyle:UITableViewCellStyleDefault
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
    FuelEventEditorController *editController = [self.storyboard instantiateViewControllerWithIdentifier:@"FuelEventEditor"];

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
        NSFetchedResultsController *fetchController = [[NSFetchedResultsController alloc] initWithFetchRequest:self.fetchRequest
                                                                                          managedObjectContext:_managedObjectContext
                                                                                            sectionNameKeyPath:nil
                                                                                                     cacheName:nil];

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

		case NSFetchedResultsChangeMove:
		case NSFetchedResultsChangeUpdate:
			[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:sectionIndex]
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



- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
