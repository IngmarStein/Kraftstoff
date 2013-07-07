// CarViewController.h
//
// Kraftstoff


#import "CarConfigurationController.h"
#import "FuelEventController.h"


@interface CarViewController : UITableViewController <UIDataSourceModelAssociation, UIGestureRecognizerDelegate, NSFetchedResultsControllerDelegate, CarConfigurationControllerDelegate>

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSManagedObject *editedObject;
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressRecognizer;

@property (nonatomic, strong) FuelEventController *fuelEventController;

@end
