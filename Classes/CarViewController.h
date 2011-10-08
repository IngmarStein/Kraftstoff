// CarViewController.h
//
// Kraftstoff


#import "CarConfigurationController.h"


@interface CarViewController : UITableViewController <NSFetchedResultsControllerDelegate, CarConfigurationControllerDelegate>
{
    BOOL changeIsUserDriven;
    BOOL isEditing;
}

@property (nonatomic, retain) NSManagedObjectContext       *managedObjectContext;
@property (nonatomic, retain) NSManagedObject              *editedObject;
@property (nonatomic, retain) NSFetchedResultsController   *fetchedResultsController;
@property (nonatomic, retain) UILongPressGestureRecognizer *longPressRecognizer;

@end
