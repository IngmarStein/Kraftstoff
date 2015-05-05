// CarViewController.m
//
// Kraftstoff


#import "CarViewController.h"
#import "FuelEventController.h"
#import "kraftstoff-Swift.h"


static NSInteger maxEditHelpCounter = 1;

@interface CarViewController () <CarConfigurationControllerDelegate>

@end

@implementation CarViewController
{
    BOOL changeIsUserDriven;
}



#pragma mark -
#pragma mark View Lifecycle



- (void)viewDidLoad
{
    [super viewDidLoad];

    changeIsUserDriven = NO;

    // Navigation Bar
    self.title = NSLocalizedString(@"Cars", @"");
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(insertNewObject:)];;

    // Gesture recognizer for touch and hold
    self.longPressRecognizer = [[UILongPressGestureRecognizer alloc]
                                    initWithTarget:self
                                            action:@selector(handleLongPress:)];

    self.longPressRecognizer.delegate = self;

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

    _managedObjectContext = [AppDelegate  managedObjectContext];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(localeChanged:)
               name:NSCurrentLocaleDidChangeNotification
             object:nil];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self updateHelp:YES];
    [self checkEnableEditButton];
}


- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [self hideHelp:animated];
}



#pragma mark -
#pragma mark State Restoration



#define kSRCarViewEditedObject @"CarViewEditedObject"

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    [coder encodeObject:[appDelegate modelIdentifierForManagedObject:_editedObject] forKey:kSRCarViewEditedObject];
    [super encodeRestorableStateWithCoder:coder];
}


- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];

	self.editedObject = (Car *)[AppDelegate managedObjectForModelIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:kSRCarViewEditedObject]];

    // -> openradar #13438788
    [self.tableView reloadData];
}



#pragma mark -
#pragma mark Locale Handling



- (void)localeChanged:(id)object
{
    // Invalidate fuelEvent-controller and any precomputed statistics
    if (self.navigationController.topViewController == self)
        _fuelEventController = nil;

    [self.tableView reloadData];
}



#pragma mark -
#pragma mark Help Badge



- (void)updateHelp:(BOOL)animated
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Number of cars determins the help badge
    NSString *helpImageName = nil;
    CGRect helpViewFrame;
	UIViewContentMode helpViewContentMode;

    NSUInteger carCount = [[[self fetchedResultsController] fetchedObjects] count];

    if (self.editing == NO && carCount == 0) {

        helpImageName = @"StartFlat";
        helpViewFrame = CGRectMake (0, 0, self.view.bounds.size.width, 70);
		helpViewContentMode = UIViewContentModeRight;

        [defaults setObject:@0 forKey:@"editHelpCounter"];

    } else if (self.editing == YES && 1 <= carCount && carCount <= 3) {

        NSInteger editCounter = [[defaults objectForKey:@"editHelpCounter"] integerValue];

        if (editCounter < maxEditHelpCounter) {

            [defaults setObject:@(++editCounter) forKey:@"editHelpCounter"];
            helpImageName = @"EditFlat";
			helpViewContentMode = UIViewContentModeLeft;
            helpViewFrame = CGRectMake (0, carCount * 91.0 - 16, self.view.bounds.size.width, 92);
        }
    }

    // Remove outdated help images
    UIImageView *helpView = (UIImageView*)[self.view viewWithTag:100];

    if (helpImageName == nil || (helpView && CGRectEqualToRect (helpView.frame, helpViewFrame) == NO)) {

		if (animated) {
            [UIView animateWithDuration:0.33
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations: ^{ helpView.alpha = 0.0; }
                             completion: ^(BOOL finished){ [helpView removeFromSuperview]; }];
		} else {
            [helpView removeFromSuperview];
		}

        helpView = nil;
    }

    // Add or update existing help image
    if (helpImageName) {

        if (helpView == nil) {

            UIImage *helpImage  = [[UIImage imageNamed:NSLocalizedString(helpImageName, @"")] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

            helpView       = [[UIImageView alloc] initWithImage:helpImage];
            helpView.tag   = 100;
            helpView.frame = helpViewFrame;
            helpView.alpha = (animated) ? 0.0 : 1.0;
			helpView.contentMode = helpViewContentMode;

            [self.view addSubview:helpView];

            if (animated)
                [UIView animateWithDuration:0.33
                                      delay:0.8
                                    options:UIViewAnimationOptionCurveEaseOut
                                 animations: ^{ helpView.alpha = 1.0; }
                                 completion:NULL];

        } else {
            helpView.image = [UIImage imageNamed:helpImageName];
            helpView.frame = helpViewFrame;
        }
    }

    // Update the toolbar button
    self.navigationItem.leftBarButtonItem = (carCount == 0) ? nil : self.editButtonItem;
}


- (void)hideHelp:(BOOL)animated
{
    UIImageView *helpView = (UIImageView*)[self.view viewWithTag:100];

    if (helpView != nil) {

        if (animated)
            [UIView animateWithDuration:0.33
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{ helpView.alpha = 0.0; }
                             completion:^(BOOL finished){ [helpView removeFromSuperview]; }];
        else
            [helpView removeFromSuperview];
    }
}



#pragma mark -
#pragma mark CarConfigurationControllerDelegate



- (void)carConfigurationController:(CarConfigurationController*)controller didFinishWithResult:(CarConfigurationResult)result
{
    if (result == CarConfigurationResultCreateSucceeded) {

        BOOL addDemoContents = NO;

        // Update order of existing objects
        changeIsUserDriven = YES;
        {
            for (Car *managedObject in [self.fetchedResultsController fetchedObjects]) {
                managedObject.order = managedObject.order+1;
            }

            // Detect demo data request
            if ([[controller.name  lowercaseString] isEqualToString:@"apple"] && [[controller.plate lowercaseString] isEqualToString:@"demo"]) {
                addDemoContents = YES;

                controller.name  = @"Toyota IQ+";
                controller.plate = @"SLS IOIOI";
            }
        }
        changeIsUserDriven = NO;

        // Create a new instance of the entity managed by the fetched results controller.
        Car *newManagedObject = (Car *)[NSEntityDescription insertNewObjectForEntityForName:@"car"
                                                                          inManagedObjectContext:_managedObjectContext];

        newManagedObject.order = 0;
        newManagedObject.timestamp = [NSDate date];
        newManagedObject.name = controller.name;
        newManagedObject.numberPlate = controller.plate;
        newManagedObject.odometerUnit = controller.odometerUnit;

        newManagedObject.odometer = [Units kilometersForDistance:controller.odometer
														withUnit:(KSDistance)[controller.odometerUnit integerValue]];

        newManagedObject.fuelUnit = controller.fuelUnit;
		newManagedObject.fuelConsumptionUnit = controller.fuelConsumptionUnit;


        // Add demo contents
        if (addDemoContents)
            [DemoData addDemoEventsForCar:newManagedObject inContext:_managedObjectContext];

        // Saving here is important here to get a stable objectID for the fuelEvent fetches
        [(AppDelegate *)[[UIApplication sharedApplication] delegate] saveContext:_managedObjectContext];

    } else if (result == CarConfigurationResultEditSucceeded) {

        _editedObject.name = controller.name;
        _editedObject.numberPlate = controller.plate;
        _editedObject.odometerUnit = controller.odometerUnit;

        NSDecimalNumber *odometer = [Units kilometersForDistance:controller.odometer
                                                              withUnit:(KSDistance)[controller.odometerUnit integerValue]];

        odometer = [odometer max:_editedObject.distanceTotalSum];

        _editedObject.odometer = odometer;
        _editedObject.fuelUnit = controller.fuelUnit;
        _editedObject.fuelConsumptionUnit = controller.fuelConsumptionUnit;

        [(AppDelegate *)[[UIApplication sharedApplication] delegate] saveContext:_managedObjectContext];

        // Invalidate fuelEvent-controller and any precomputed statistics
        _fuelEventController = nil;
    }

    self.editedObject = nil;
    [self checkEnableEditButton];

    [self dismissViewControllerAnimated:(result != CarConfigurationResultAborted) completion:nil];
}



#pragma mark -
#pragma mark Adding a new Object



- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];

    [self checkEnableEditButton];
    [self updateHelp:animated];

    // Force Core Data save after editing mode is finished
    if (editing == NO)
        [(AppDelegate *)[[UIApplication sharedApplication] delegate] saveContext:_managedObjectContext];
}


- (void)checkEnableEditButton
{
    self.editButtonItem.enabled = ([[[self fetchedResultsController] fetchedObjects] count] > 0);
}



- (void)insertNewObject:(id)sender
{
    [self setEditing:NO animated:YES];

    CarConfigurationController *configurator = [self.storyboard instantiateViewControllerWithIdentifier:@"CarConfigurationController"];
    configurator.delegate = self;
    configurator.editingExistingObject = NO;

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:configurator];
	navController.restorationIdentifier = @"CarConfigurationNavigationController";
    navController.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;

    [self presentViewController:navController animated:YES completion:nil];
}



#pragma mark -
#pragma mark UIGestureRecognizerDelegate



- (BOOL)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer shouldReceiveTouch:(UITouch*)touch
{
    // Editing mode must be enabled
    if (self.editing) {

        UIView *view = touch.view;

        // Touch must hit the contentview of a tableview cell
        while (view != nil) {

            if ([view isKindOfClass:[UITableViewCell class]])
                return ([(UITableViewCell*)view contentView] == touch.view);

            view = view.superview;
        }
    }

    return NO;
}



#pragma mark -
#pragma mark Gesture Recognizer for Editing an Existing Object



- (void)setLongPressRecognizer:(UILongPressGestureRecognizer *)newRecognizer
{
    if (_longPressRecognizer != newRecognizer) {

        [self.tableView removeGestureRecognizer:_longPressRecognizer];
        [self.tableView addGestureRecognizer:newRecognizer];

        _longPressRecognizer = newRecognizer;
    }
}


- (void)handleLongPress:(UILongPressGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {

        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:[sender locationInView:self.tableView]];

        if (indexPath) {

            [(AppDelegate *)[[UIApplication sharedApplication] delegate] saveContext:_managedObjectContext];
            self.editedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];

            // Present modal car configurator
            CarConfigurationController *configurator = [self.storyboard instantiateViewControllerWithIdentifier:@"CarConfigurationController"];
            configurator.delegate = self;
            configurator.editingExistingObject = YES;

			configurator.name = _editedObject.name;

            if ([configurator.name length] > [TextEditTableCell maximumTextFieldLength])
                configurator.name = @"";

            configurator.plate = _editedObject.numberPlate;

            if ([configurator.plate length] > [TextEditTableCell maximumTextFieldLength])
                configurator.plate = @"";

            configurator.odometerUnit = @(_editedObject.odometerUnit);
            configurator.odometer     = [Units distanceForKilometers:_editedObject.odometer
                                                                  withUnit:_editedObject.ksOdometerUnit];

            configurator.fuelUnit            = @(_editedObject.fuelUnit);
            configurator.fuelConsumptionUnit = @(_editedObject.fuelConsumptionUnit);

            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:configurator];
			navController.restorationIdentifier = @"CarConfigurationNavigationController";
            navController.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;

            [self presentViewController:navController animated:YES completion:nil];

            // Edit started => prevent edit help from now on
            [[NSUserDefaults standardUserDefaults] setObject:@(maxEditHelpCounter) forKey:@"editHelpCounter"];

            // Quit editing mode
            [self setEditing:NO animated:YES];
        }
    }
}



#pragma mark -
#pragma mark Removing an Existing Object



- (void)removeExistingObjectAtPath:(NSIndexPath *)indexPath
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    Car *deletedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSInteger deletedObjectOrder = deletedObject.order;

    // catch nil objects
    if (!deletedObject)
        return;

    // Invalidate preference for deleted car
    NSString *preferredCarID = [[NSUserDefaults standardUserDefaults] stringForKey:@"preferredCarID"];
    NSString *deletedCarID = [appDelegate modelIdentifierForManagedObject:deletedObject];

    if ([deletedCarID isEqualToString:preferredCarID])
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"preferredCarID"];


    // Delete the managed object for the given index path
    [_managedObjectContext deleteObject:deletedObject];
    [appDelegate saveContext:_managedObjectContext];


    // Update order of existing objects
    changeIsUserDriven = YES;
    {
        for (Car *managedObject in [self.fetchedResultsController fetchedObjects]) {

            NSInteger order = managedObject.order;

            if (order > deletedObjectOrder)
                managedObject.order = (int32_t)order-1;
        }

        [appDelegate saveContext:_managedObjectContext];
    }
    changeIsUserDriven = NO;

    // Exit editing mode after last object is deleted
    if (self.editing)
        if ([[self.fetchedResultsController fetchedObjects] count] == 0)
            [self setEditing:NO animated:YES];
}



#pragma mark -
#pragma mark UITableViewDataSource



- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath
{
    QuadInfoCell *tableCell = (QuadInfoCell*)cell;
    Car *managedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];

    UILabel *label;

    // Car and Numberplate
    label      = [tableCell topLeftLabel];
    label.text = [NSString stringWithFormat:@"%@", managedObject.name];
    tableCell.topLeftAccessibilityLabel  = nil;

    label      = [tableCell botLeftLabel];
    label.text = [NSString stringWithFormat:@"%@", managedObject.numberPlate];
    tableCell.topRightAccessibilityLabel = nil;

    // Average consumption
    NSString *avgConsumption;
    KSFuelConsumption consumptionUnit = managedObject.ksFuelConsumptionUnit;

    NSDecimalNumber *distance   = managedObject.distanceTotalSum;
    NSDecimalNumber *fuelVolume = managedObject.fuelVolumeTotalSum;

    if ([distance   compare:[NSDecimalNumber zero]] == NSOrderedDescending && [fuelVolume compare:[NSDecimalNumber zero]] == NSOrderedDescending) {

        avgConsumption = [[Formatters sharedFuelVolumeFormatter]
                                stringFromNumber:
                                    [Units consumptionForKilometers:distance
                                                                   liters:fuelVolume
                                                                   inUnit:consumptionUnit]];

        tableCell.topRightAccessibilityLabel = avgConsumption;
        tableCell.botRightAccessibilityLabel = [Units consumptionUnitAccesibilityDescription:consumptionUnit];

    } else {

        avgConsumption = [NSString stringWithFormat:@"%@", NSLocalizedString(@"-", @"")];

        tableCell.topRightAccessibilityLabel = NSLocalizedString(@"fuel mileage not available", @"");
        tableCell.botRightAccessibilityLabel = nil;
    }

    label      = [tableCell topRightLabel];
    label.text = avgConsumption;

    label      = [tableCell botRightLabel];
    label.text = [Units consumptionUnitString:consumptionUnit];
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
    static NSString *CellIdentifier = @"ShadedTableViewCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (cell == nil)
        cell = [[QuadInfoCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:CellIdentifier
                              enlargeTopRightLabel:YES];

    [self configureCell:cell atIndexPath:indexPath];

    return cell;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
        [self removeExistingObjectAtPath:indexPath];
}


- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    NSIndexPath *basePath = [fromIndexPath indexPathByRemovingLastIndex];

    if ([basePath compare:[toIndexPath indexPathByRemovingLastIndex]] != NSOrderedSame)
        [NSException raise:NSGenericException format:@"Invalid Index path for MoveRow"];

    NSComparisonResult cmpResult = [fromIndexPath compare:toIndexPath];
    NSUInteger length = [fromIndexPath length], from, to;

    if (cmpResult == NSOrderedAscending) {

        from = [fromIndexPath indexAtPosition:length - 1];
        to   = [toIndexPath   indexAtPosition:length - 1];

    } else if (cmpResult == NSOrderedDescending) {

        to   = [fromIndexPath indexAtPosition:length - 1];
        from = [toIndexPath   indexAtPosition:length - 1];
    }
    else
        return;

    for (NSUInteger i = from; i <= to; i++) {

        Car *managedObject = [self.fetchedResultsController objectAtIndexPath:[basePath indexPathByAddingIndex:i]];
        NSInteger order = managedObject.order;

        if (cmpResult == NSOrderedAscending)
            order = (i != from) ? order-1 : to;
        else
            order = (i != to)   ? order+1 : from;

        managedObject.order = (int32_t)order;
    }

    changeIsUserDriven = YES;
}


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}



#pragma mark -
#pragma mark UIDataSourceModelAssociation



- (NSIndexPath *)indexPathForElementWithModelIdentifier:(NSString *)identifier inView:(UIView *)view
{
    NSManagedObject *object = [AppDelegate managedObjectForModelIdentifier:identifier];

    return [self.fetchedResultsController indexPathForObject:object];
}


- (NSString *)modelIdentifierForElementAtIndexPath:(NSIndexPath *)idx inView:(UIView *)view
{
    NSManagedObject *object = [self.fetchedResultsController objectAtIndexPath:idx];

    return [(AppDelegate *)[[UIApplication sharedApplication] delegate] modelIdentifierForManagedObject:object];
}



#pragma mark -
#pragma mark UITableViewDelegate



- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath
                                                                         toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
    return proposedDestinationIndexPath;
}


- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (self.editing) ? nil : indexPath;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Car *selectedCar = (Car *)[self.fetchedResultsController objectAtIndexPath:indexPath];

    if (_fuelEventController == nil || _fuelEventController.selectedCar != selectedCar) {

		_fuelEventController = [self.storyboard instantiateViewControllerWithIdentifier:@"FuelEventController"];
        _fuelEventController.managedObjectContext = _managedObjectContext;
        _fuelEventController.selectedCar          = selectedCar;
    }

    [self.navigationController pushViewController:_fuelEventController animated:YES];
}


- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.editButtonItem.enabled = NO;
    [self hideHelp:YES];
}


- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self checkEnableEditButton];
    [self updateHelp:YES];
}



#pragma mark -
#pragma mark Fetched Results Controller



- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController == nil) {

        _fetchedResultsController = [AppDelegate fetchedResultsControllerForCarsInContext:_managedObjectContext];
        _fetchedResultsController.delegate = self;
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

    if (changeIsUserDriven)
        return;

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

    [self updateHelp:YES];
    [self checkEnableEditButton];

    changeIsUserDriven = NO;
}



#pragma mark -
#pragma mark Memory Management



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if (self.navigationController.topViewController == self)
        _fuelEventController = nil;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
