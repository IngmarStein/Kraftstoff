// FuelEventController.h
//
// Kraftstoff


#import "FuelStatisticsPageController.h"
#import <MessageUI/MessageUI.h>


@interface FuelEventController : UITableViewController <NSFetchedResultsControllerDelegate, MFMailComposeViewControllerDelegate, UIActionSheetDelegate>
{
    BOOL isEditing;
    BOOL isShowingMailComposer;
    BOOL isShowingAskForExportSheet;
    BOOL isObservingRotationEvents;
    BOOL isWaitingForACK;
}

@property (nonatomic, retain) NSManagedObject              *selectedCar;
@property (nonatomic, retain) NSManagedObjectContext       *managedObjectContext;
@property (nonatomic, retain) NSFetchRequest               *fetchRequest;
@property (nonatomic, retain) NSFetchedResultsController   *fetchedResultsController;
@property (nonatomic, retain) FuelStatisticsPageController *statisticsController;

@end
