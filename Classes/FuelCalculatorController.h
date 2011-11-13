// FuelCalculatorController.h
//
// Kraftstoff


#import "PageViewController.h"
#import "EditablePageCell.h"


@interface FuelCalculatorController : PageViewController <EditablePageCellDelegate, NSFetchedResultsControllerDelegate>
{
    BOOL changeIsUserDriven;
}

@property (nonatomic, strong) NSManagedObjectContext     *managedObjectContext;
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic, strong) UITextField *editingTextField;

@property (nonatomic, strong) NSManagedObject *car;
@property (nonatomic, strong) NSDate          *date;
@property (nonatomic, strong) NSDate          *lastChangeDate;
@property (nonatomic, strong) NSDecimalNumber *distance;
@property (nonatomic, strong) NSDecimalNumber *price;
@property (nonatomic, strong) NSDecimalNumber *fuelVolume;
@property (nonatomic)         BOOL             filledUp;

@property (nonatomic, strong) UIBarButtonItem *doneButton;
@property (nonatomic, strong) UIBarButtonItem *saveButton;

@end
