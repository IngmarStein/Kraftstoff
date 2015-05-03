// FuelEventEditorController.h
//
// Kraftstoff


#import "PageViewController.h"


@interface FuelEventEditorController : PageViewController <UIViewControllerRestoration, NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@property (nonatomic, strong) NSManagedObject *event;
@property (nonatomic, strong) NSManagedObject *car;
@property (nonatomic, strong) NSDate          *date;
@property (nonatomic, strong) NSDecimalNumber *distance;
@property (nonatomic, strong) NSDecimalNumber *price;
@property (nonatomic, strong) NSDecimalNumber *fuelVolume;
@property (nonatomic)         BOOL             filledUp;

@property (nonatomic, strong) UIBarButtonItem *editButton;
@property (nonatomic, strong) UIBarButtonItem *cancelButton;
@property (nonatomic, strong) UIBarButtonItem *doneButton;

@end
