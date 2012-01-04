// CarViewController.h
//
// Kraftstoff


#import "CarConfigurationController.h"
#import "FuelEventController.h"


@interface CarViewController : UITableViewController <UIGestureRecognizerDelegate, NSFetchedResultsControllerDelegate, CarConfigurationControllerDelegate>
{
    BOOL changeIsUserDriven;
    BOOL isEditing;
}

@property (nonatomic, strong) NSManagedObjectContext       *managedObjectContext;
@property (nonatomic, strong) NSManagedObject              *editedObject;
@property (nonatomic, strong) NSFetchedResultsController   *fetchedResultsController;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressRecognizer;

@property (nonatomic, strong) FuelEventController          *fuelEventController;

@end
