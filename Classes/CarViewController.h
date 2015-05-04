// CarViewController.h
//
// Kraftstoff


#import "FuelEventController.h"

@class Car;

@interface CarViewController : UITableViewController <UIDataSourceModelAssociation, UIGestureRecognizerDelegate, NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) Car *editedObject;
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressRecognizer;

@property (nonatomic, strong) FuelEventController *fuelEventController;

@end
