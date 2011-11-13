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

@property (nonatomic, strong) NSManagedObject              *selectedCar;
@property (nonatomic, strong) NSManagedObjectContext       *managedObjectContext;
@property (nonatomic, strong) NSFetchRequest               *fetchRequest;
@property (nonatomic, strong) NSFetchedResultsController   *fetchedResultsController;
@property (nonatomic, strong) FuelStatisticsPageController *statisticsController;

@end
