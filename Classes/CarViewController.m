// CarViewController.m
//
// Kraftstoff


#import "AppDelegate.h"
#import "CarViewController.h"
#import "FuelEventController.h"
#import "ShadowTableView.h"
#import "ShadedTableViewCell.h"
#import "TextEditTableCell.h"


static NSInteger maxEditHelpCounter = 1;


@interface CarViewController (private)

- (void)updateHelp: (BOOL)animated;
- (void)hideHelp: (BOOL)animated;

- (void)configureCell: (UITableViewCell*)cell atIndexPath: (NSIndexPath*)indexPath;
- (void)checkEnableEditButton;
- (void)insertNewObject: (id)sender;
- (void)removeExistingObjectAtPath: (NSIndexPath*)indexPath;

- (void)localeChanged: (id)object;

@end



@implementation CarViewController

@synthesize managedObjectContext;
@synthesize editedObject;
@synthesize longPressRecognizer;

@synthesize fuelEventController;



#pragma mark -
#pragma mark View Lifecycle



- (void)viewDidLoad
{
    [super viewDidLoad];

    changeIsUserDriven = NO;
    isEditing          = NO;

    // Configure root view
    self.title = _I18N (@"Cars");

    // Buttons in navigation bar
    self.navigationItem.leftBarButtonItem = nil;

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemAdd
                                                                               target: self
                                                                               action: @selector (insertNewObject:)];
    self.navigationItem.rightBarButtonItem = addButton;

    // Gesture recognizer for touch and hold
    self.longPressRecognizer = [[UILongPressGestureRecognizer alloc]
                                    initWithTarget: self
                                            action: @selector (handleLongPress:)];

    self.longPressRecognizer.delegate = self;

    // Observe locale changes
    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector (localeChanged:)
               name: NSCurrentLocaleDidChangeNotification
             object: nil];
}


- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}


- (void)viewWillAppear: (BOOL)animated
{
    [super viewWillAppear: animated];

    [self updateHelp: YES];
    [self checkEnableEditButton];
}


- (void)viewWillDisappear: (BOOL)animated
{
    [super viewWillDisappear: animated];

    [self hideHelp: animated];
}


- (void)localeChanged: (id)object
{    
    // Invalidate fuelEvent-controller and any precomputed statistics
    if (self.navigationController.topViewController == self)
        self.fuelEventController = nil;

    // Reload all table data
    [self.tableView reloadData];
}


- (BOOL)shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}


- (void)setEditing: (BOOL)editing animated: (BOOL)animated
{
    isEditing = editing;

    [super setEditing: editing animated: animated];

    [self checkEnableEditButton];
    [self updateHelp: animated];

    // Force Core Data save after editing mode is finished
    if (editing == NO)
        [[AppDelegate sharedDelegate] saveContext: self.managedObjectContext];
}



#pragma mark -
#pragma mark Help Badge



- (void)updateHelp: (BOOL)animated
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Number of cars determins the help badge
    NSString *helpImageName = nil;
    CGRect helpViewFrame;

    NSUInteger carCount = [[[self fetchedResultsController] fetchedObjects] count];

    if (isEditing == NO && carCount == 0)
    {
        helpImageName = @"Start";
        helpViewFrame = CGRectMake (0, 0, 320, 70);

        [defaults setObject: [NSNumber numberWithInteger: 0] forKey: @"editHelpCounter"];
    }
    else if (isEditing == YES && 1 <= carCount && carCount <= 3)
    {
        NSInteger editCounter = [[defaults objectForKey: @"editHelpCounter"] integerValue];

        if (editCounter < maxEditHelpCounter)
        {
            [defaults setObject: [NSNumber numberWithInteger: ++editCounter] forKey: @"editHelpCounter"];

            helpImageName = @"Edit";
            helpViewFrame = CGRectMake (0, carCount * 91.0 - 16, 320, 92);
        }
    }

    // Remove outdated help images
    UIImageView *helpView = (UIImageView*)[self.view viewWithTag: 100];

    if (helpImageName == nil || (helpView && CGRectEqualToRect (helpView.frame, helpViewFrame) == NO))
    {
        if (animated)
            [UIView animateWithDuration: 0.33
                                  delay: 0.0
                                options: UIViewAnimationOptionCurveEaseOut
                             animations: ^{ helpView.alpha = 0.0; }
                             completion: ^(BOOL finished){ [helpView removeFromSuperview]; }];
        else
            [helpView removeFromSuperview];

        helpView = nil;
    }

    // Add or update existing help image
    if (helpImageName)
    {
        if (helpView == nil)
        {
            helpView = [[UIImageView alloc] initWithImage: [UIImage imageNamed: helpImageName]];

            helpView.tag   = 100;
            helpView.frame = helpViewFrame;
            helpView.alpha = (animated) ? 0.0 : 0.9;

            [self.view addSubview: helpView];

            if (animated)
            {
                [UIView animateWithDuration: 0.33
                                      delay: 0.6
                                    options: UIViewAnimationOptionCurveEaseOut
                                 animations: ^{ helpView.alpha = 0.9; }
                                 completion: NULL];
            }
        }
        else
        {
            helpView.image = [UIImage imageNamed: helpImageName];
            helpView.frame = helpViewFrame;
        }
    }

    // Update the toolbar button
    self.navigationItem.leftBarButtonItem = (carCount == 0) ? nil : self.editButtonItem;
}


- (void)hideHelp: (BOOL)animated
{
    UIImageView *helpView = (UIImageView*)[self.view viewWithTag: 100];

    if (helpView != nil)
    {
        if (animated)
            [UIView animateWithDuration: 0.33
                                  delay: 0.0
                                options: UIViewAnimationOptionCurveEaseOut
                             animations: ^{ helpView.alpha = 0.0; }
                             completion: ^(BOOL finished){ [helpView removeFromSuperview]; }];
        else
            [helpView removeFromSuperview];
    }
}



#pragma mark -
#pragma mark CarConfigurationControllerDelegate



- (void)carConfigurationController: (CarConfigurationController*)controller didFinishWithResult: (CarConfigurationResult)result
{
    [self dismissModalViewControllerAnimated: (result != CarConfigurationAborted)];

    if (result == CarConfigurationCreateSucceded)
    {
        // Update order of existing objects
        changeIsUserDriven = YES;
        {
            for (NSManagedObject *managedObject in [self.fetchedResultsController fetchedObjects])
            {
                NSInteger order = [[managedObject valueForKey: @"order"] integerValue];
                [managedObject setValue: [NSNumber numberWithInt: order+1] forKey: @"order"];
            }
        }
        changeIsUserDriven = NO;

        // Create a new instance of the entity managed by the fetched results controller.
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName: @"car"
                                                                          inManagedObjectContext: self.managedObjectContext];

        [newManagedObject setValue: [NSNumber numberWithInt: 0]    forKey: @"order"];
        [newManagedObject setValue: [NSDate date]                  forKey: @"timestamp"];
        [newManagedObject setValue: controller.name                forKey: @"name"];
        [newManagedObject setValue: controller.plate               forKey: @"numberPlate"];
        [newManagedObject setValue: controller.odometerUnit        forKey: @"odometerUnit"];

        [newManagedObject setValue: [AppDelegate kilometersForDistance:  controller.odometer
                                                              withUnit: [controller.odometerUnit integerValue]]
                            forKey: @"odometer"];

        [newManagedObject setValue: controller.fuelUnit            forKey: @"fuelUnit"];
        [newManagedObject setValue: controller.fuelConsumptionUnit forKey: @"fuelConsumptionUnit"];

        // Saving here is important here to get a stable objectID for the fuelEvent fetches
        [[AppDelegate sharedDelegate] saveContext: self.managedObjectContext];
    }

    else if (result == CarConfigurationEditSucceded)
    {
        [editedObject setValue: controller.name                forKey: @"name"];
        [editedObject setValue: controller.plate               forKey: @"numberPlate"];
        [editedObject setValue: controller.odometerUnit        forKey: @"odometerUnit"];

        NSDecimalNumber *odometer = [AppDelegate kilometersForDistance:  controller.odometer
                                                              withUnit: [controller.odometerUnit integerValue]];

        odometer = [odometer max: [editedObject valueForKey: @"distanceTotalSum"]];

        [editedObject setValue: odometer                       forKey: @"odometer"];
        [editedObject setValue: controller.fuelUnit            forKey: @"fuelUnit"];
        [editedObject setValue: controller.fuelConsumptionUnit forKey: @"fuelConsumptionUnit"];

        [[AppDelegate sharedDelegate] saveContext: self.managedObjectContext];

        // Invalidate fuelEvent-controller and any precomputed statistics
        self.fuelEventController = nil;
    }

    self.editedObject = nil;
    [self checkEnableEditButton];
}



#pragma mark -
#pragma mark Adding a new Object



- (void)checkEnableEditButton
{
    self.editButtonItem.enabled = ([[[self fetchedResultsController] fetchedObjects] count] > 0);
}



- (void)insertNewObject: (id)sender
{
    [self setEditing: NO animated: YES];

    CarConfigurationController *configurator = [[CarConfigurationController alloc] initWithNibName: @"CarConfigurationController" bundle: nil];
    [configurator setDelegate: self];

    configurator.editing = NO;

    [self presentModalViewController: configurator animated: YES];
}



#pragma mark -
#pragma mark UIGestureRecognizerDelegate



- (BOOL)gestureRecognizer: (UIGestureRecognizer*)gestureRecognizer shouldReceiveTouch: (UITouch*)touch
{
    // Editing mode must be enabled and the touch must hit the contentview of a tableview cell
    if (isEditing)
    {
        if ([touch.view.superview isKindOfClass: [UITableViewCell class]])
        {
            UITableViewCell *cell = (UITableViewCell*)touch.view.superview;

            if (cell.contentView == touch.view)
                return YES;
        }
    }

    return NO;
}



#pragma mark -
#pragma mark Gesture Recognizer for Editing an Existing Object



- (void)setLongPressRecognizer: (UILongPressGestureRecognizer*)newRecognizer
{
    if (longPressRecognizer != newRecognizer)
    {
        [self.tableView removeGestureRecognizer: longPressRecognizer];
        [self.tableView addGestureRecognizer: newRecognizer];

        longPressRecognizer = newRecognizer;
    }
}


- (void)handleLongPress: (UILongPressGestureRecognizer*)sender
{
    if (sender.state == UIGestureRecognizerStateBegan)
    {
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint: [sender locationInView: self.tableView]];

        if (indexPath)
        {
            self.editedObject = [self.fetchedResultsController objectAtIndexPath: indexPath];

            // Present modal car configurator
            CarConfigurationController *configurator = [[CarConfigurationController alloc] initWithNibName: @"CarConfigurationController" bundle: nil];
            [configurator setDelegate: self];

            configurator.editing  = YES;
            configurator.name                = [editedObject valueForKey: @"name"];

            if ([configurator.name length] > maximumTextFieldLength)
                configurator.name = @"";

            configurator.plate               = [editedObject valueForKey: @"numberPlate"];

            if ([configurator.plate length] > maximumTextFieldLength)
                configurator.plate = @"";

            configurator.odometerUnit        = [editedObject valueForKey: @"odometerUnit"];
            configurator.odometer            = [AppDelegate distanceForKilometers:  [editedObject valueForKey: @"odometer"]
                                                                         withUnit: [[editedObject valueForKey: @"odometerUnit"] integerValue]];
            configurator.fuelUnit            = [editedObject valueForKey: @"fuelUnit"];
            configurator.fuelConsumptionUnit = [editedObject valueForKey: @"fuelConsumptionUnit"];

            [self presentModalViewController: configurator animated: YES];

            // Edit started => prevent edit help from now on
            [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInteger: maxEditHelpCounter] forKey: @"editHelpCounter"];

            // Quit editing mode
            [self setEditing: NO animated: YES];
        }
    }
}



#pragma mark -
#pragma mark Removing an Existing Object



- (void)removeExistingObjectAtPath: (NSIndexPath*)indexPath
{
    NSManagedObject *deletedObject = [self.fetchedResultsController objectAtIndexPath: indexPath];
    NSInteger deletedObjectOrder   = [[deletedObject valueForKey: @"order"] integerValue];


    // Delete any fetch-cache for the deleted object
    NSString *cacheName = [AppDelegate cacheNameForFuelEventFetchWithParent: deletedObject];

    if (cacheName)
        [NSFetchedResultsController deleteCacheWithName: cacheName];


    // Invalidate preference for deleted car
    NSString *preferredCarID = [[NSUserDefaults standardUserDefaults] stringForKey: @"preferredCarID"];
    NSString *deletedCarID   = [[[deletedObject objectID] URIRepresentation] absoluteString];

    if ([deletedCarID isEqualToString: preferredCarID])
        [[NSUserDefaults standardUserDefaults] setObject: @"" forKey: @"preferredCarID"];


    // Delete the managed object for the given index path
    [self.managedObjectContext deleteObject: deletedObject];
    [[AppDelegate sharedDelegate] saveContext: self.managedObjectContext];


    // Update order of existing objects
    changeIsUserDriven = YES;
    {
        for (NSManagedObject *managedObject in [self.fetchedResultsController fetchedObjects])
        {
            NSInteger order = [[managedObject valueForKey: @"order"] integerValue];

            if (order > deletedObjectOrder)
                [managedObject setValue: [NSNumber numberWithInt: order-1] forKey: @"order"];
        }

        [[AppDelegate sharedDelegate] saveContext: self.managedObjectContext];
    }
    changeIsUserDriven = NO;

    // Exit editing mode after last object is deleted
    if (isEditing)
        if ([[[self fetchedResultsController] fetchedObjects] count] == 0)
            [self setEditing: NO animated: YES];
}



#pragma mark -
#pragma mark UITableViewDataSource



- (void)configureCell: (UITableViewCell*)cell atIndexPath: (NSIndexPath*)indexPath
{
    ShadedTableViewCell *tableCell = (ShadedTableViewCell*)cell;
    NSManagedObject *managedObject = [self.fetchedResultsController objectAtIndexPath: indexPath];

    UILabel *label;

    // Car and Numberplate
    label      = [tableCell topLeftLabel];
    label.text = [NSString stringWithFormat: @"%@", [managedObject valueForKey: @"name"]];
    tableCell.topLeftAccessibilityLabel  = nil;

    label      = [tableCell botLeftLabel];
    label.text = [NSString stringWithFormat: @"%@", [managedObject valueForKey: @"numberPlate"]];
    tableCell.topRightAccessibilityLabel = nil;

    // Average consumption
    NSString *avgConsumption;
    KSFuelConsumption consumptionUnit = [[managedObject valueForKey: @"fuelConsumptionUnit"] integerValue];

    NSDecimalNumber *distance   = [managedObject valueForKey: @"distanceTotalSum"];
    NSDecimalNumber *fuelVolume = [managedObject valueForKey: @"fuelVolumeTotalSum"];

    if ([distance   compare: [NSDecimalNumber zero]] == NSOrderedDescending &&
        [fuelVolume compare: [NSDecimalNumber zero]] == NSOrderedDescending)
    {
        avgConsumption = [[AppDelegate sharedFuelVolumeFormatter]
                                stringFromNumber:
                                    [AppDelegate consumptionForKilometers: distance
                                                                   Liters: fuelVolume
                                                                   inUnit: consumptionUnit]];

        tableCell.topRightAccessibilityLabel = avgConsumption;
        tableCell.botRightAccessibilityLabel = [AppDelegate consumptionUnitShadedTableViewCellDescription: consumptionUnit];
    }
    else
    {
        avgConsumption = [NSString stringWithFormat: @"%@", _I18N (@"-")];

        tableCell.topRightAccessibilityLabel = _I18N (@"fuel mileage not available");
        tableCell.botRightAccessibilityLabel = nil;
    }

    label      = [tableCell topRightLabel];
    label.text = avgConsumption;

    label      = [tableCell botRightLabel];
    label.text = [AppDelegate consumptionUnitString: consumptionUnit];
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
    static NSString *CellIdentifier = @"ShadedTableViewCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier];

    if (cell == nil)
        cell = [[ShadedTableViewCell alloc] initWithStyle: UITableViewCellStyleDefault
                                          reuseIdentifier: CellIdentifier
                                     enlargeTopRightLabel: YES];

    [self configureCell: cell atIndexPath: indexPath];

    return cell;
}


- (void)tableView: (UITableView*)tableView commitEditingStyle: (UITableViewCellEditingStyle)editingStyle forRowAtIndexPath: (NSIndexPath*)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
        [self removeExistingObjectAtPath: indexPath];
}


- (void)tableView: (UITableView*)tableView moveRowAtIndexPath: (NSIndexPath*)fromIndexPath toIndexPath: (NSIndexPath*)toIndexPath
{
    NSIndexPath *basePath = [fromIndexPath indexPathByRemovingLastIndex];

    if ([basePath compare: [toIndexPath indexPathByRemovingLastIndex]] != NSOrderedSame)
    {
        [NSException raise: NSGenericException format: @"Invalid Index path for MoveRow"];
    }

    NSComparisonResult cmpResult = [fromIndexPath compare: toIndexPath];
    NSUInteger length = [fromIndexPath length], from, to;

    if (cmpResult == NSOrderedAscending)
    {
        from = [fromIndexPath indexAtPosition: length - 1];
        to   = [toIndexPath   indexAtPosition: length - 1];
    }
    else if (cmpResult == NSOrderedDescending)
    {
        to   = [fromIndexPath indexAtPosition: length - 1];
        from = [toIndexPath   indexAtPosition: length - 1];
    }
    else
        return;

    for (NSUInteger i = from; i <= to; i++)
    {
        NSManagedObject *managedObject = [self.fetchedResultsController objectAtIndexPath: [basePath indexPathByAddingIndex: i]];
        NSInteger order = [[managedObject valueForKey: @"order"] integerValue];

        if (cmpResult == NSOrderedAscending)
            order = (i != from) ? order-1 : to;
        else
            order = (i != to)   ? order+1 : from;

        [managedObject setValue: [NSNumber numberWithInt: order] forKey: @"order"];
    }

    changeIsUserDriven = YES;
}


- (BOOL)tableView: (UITableView*)tableView canMoveRowAtIndexPath: (NSIndexPath*)indexPath
{
    return YES;
}



#pragma mark -
#pragma mark UITableViewDelegate



- (NSIndexPath*)tableView: (UITableView*)tableView targetIndexPathForMoveFromRowAtIndexPath: (NSIndexPath*)sourceIndexPath
                                                                        toProposedIndexPath: (NSIndexPath*)proposedDestinationIndexPath
{
    ShadowTableView *table = (ShadowTableView*)tableView;

    [table setReorderSourceIndexPath: sourceIndexPath];
    [table setReorderDestinationIndexPath: proposedDestinationIndexPath];
    [table setNeedsLayout];

    return proposedDestinationIndexPath;
}


- (void)tableView: (UITableView*)tableView didSelectRowAtIndexPath: (NSIndexPath*)indexPath
{
    if (isEditing)
    {
        [tableView deselectRowAtIndexPath: indexPath animated: YES];
    }
    else
    {
        NSManagedObject *selectedCar = [[self fetchedResultsController] objectAtIndexPath: indexPath];

        if (self.fuelEventController == nil || self.fuelEventController.selectedCar != selectedCar)
        {
            self.fuelEventController = [[FuelEventController alloc] initWithNibName: @"FuelEventController" bundle: nil];
            self.fuelEventController.managedObjectContext = self.managedObjectContext;
            self.fuelEventController.selectedCar          = selectedCar;
        }

        [self.navigationController pushViewController: self.fuelEventController animated: YES];
    }
}


- (void)tableView: (UITableView*)tableView willBeginEditingRowAtIndexPath: (NSIndexPath*)indexPath
{
    self.editButtonItem.enabled = NO;
    [self hideHelp: YES];
}


- (void)tableView: (UITableView*)tableView didEndEditingRowAtIndexPath: (NSIndexPath*)indexPath
{
    [self checkEnableEditButton];
    [self updateHelp: YES];
}



#pragma mark -
#pragma mark Fetched Results Controller



@synthesize fetchedResultsController;


- (NSFetchedResultsController*)fetchedResultsController
{
    if (fetchedResultsController == nil)
    {
        self.fetchedResultsController          = [AppDelegate fetchedResultsControllerForCarsInContext: self.managedObjectContext];
        self.fetchedResultsController.delegate = self;
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

    if (changeIsUserDriven)
        return;

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

    [self updateHelp: YES];
    [self checkEnableEditButton];

    changeIsUserDriven = NO;
}



#pragma mark -
#pragma mark Memory Management



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if (self.navigationController.topViewController == self)
        self.fuelEventController = nil;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

@end
