// FuelEventEditorController.h
//
// Kraftstoff


#import "PageViewController.h"
#import "EditablePageCell.h"


@interface FuelEventEditorController : PageViewController <EditablePageCellDelegate, NSFetchedResultsControllerDelegate, UIActionSheetDelegate>
{
    BOOL      dataChanged;
    NSInteger mostRecentSelectedRow;
}


@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;

@property (nonatomic, retain) NSManagedObject *event;
@property (nonatomic, retain) NSManagedObject *car;
@property (nonatomic, retain) NSDate          *date;
@property (nonatomic, retain) NSDecimalNumber *distance;
@property (nonatomic, retain) NSDecimalNumber *price;
@property (nonatomic, retain) NSDecimalNumber *fuelVolume;
@property (nonatomic)         BOOL             filledUp;

@property (nonatomic, retain) UITextField *editingTextField;

@property (nonatomic, retain) UIBarButtonItem *editButton;
@property (nonatomic, retain) UIBarButtonItem *cancelButton;
@property (nonatomic, retain) UIBarButtonItem *doneButton;

@property (nonatomic, getter=isEditing) BOOL editing;

@end
