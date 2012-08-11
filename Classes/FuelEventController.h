// FuelEventController.h
//
// Kraftstoff


#import "FuelStatisticsPageController.h"
#import <MessageUI/MessageUI.h>


@interface FuelEventController : UITableViewController <UIDataSourceModelAssociation, UIViewControllerRestoration, NSFetchedResultsControllerDelegate, MFMailComposeViewControllerDelegate, UIActionSheetDelegate, UIAlertViewDelegate>
{
    BOOL isObservingRotationEvents;
    BOOL isPerformingRotation;

    BOOL isShowingExportSheet;
    BOOL isShowingExportFailedAlert;
    BOOL isShowingMailComposer;

    BOOL restoreExportSheet;
    BOOL restoreExportFailedAlert;
    BOOL restoreMailComposer;
}

@property (nonatomic, strong) NSManagedObject              *selectedCar;
@property (nonatomic, strong) NSManagedObjectContext       *managedObjectContext;
@property (nonatomic, strong) NSFetchRequest               *fetchRequest;
@property (nonatomic, strong) NSFetchedResultsController   *fetchedResultsController;

@property (nonatomic, strong) FuelStatisticsPageController *statisticsController;

@end
