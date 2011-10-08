// FuelCalculatorController.h
//
// Kraftstoff


#import "PageViewController.h"
#import "EditablePageCell.h"


@interface FuelCalculatorController : PageViewController <EditablePageCellDelegate, NSFetchedResultsControllerDelegate>
{
    BOOL changeIsUserDriven;
}

@property (nonatomic, retain) NSManagedObjectContext     *managedObjectContext;
@property (nonatomic, retain) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic, retain) UITextField *editingTextField;

@property (nonatomic, retain) NSManagedObject *car;
@property (nonatomic, retain) NSDate          *date;
@property (nonatomic, retain) NSDate          *lastChangeDate;
@property (nonatomic, retain) NSDecimalNumber *distance;
@property (nonatomic, retain) NSDecimalNumber *price;
@property (nonatomic, retain) NSDecimalNumber *fuelVolume;
@property (nonatomic)         BOOL             filledUp;

@property (nonatomic, retain) UIBarButtonItem *doneButton;
@property (nonatomic, retain) UIBarButtonItem *saveButton;

@end
