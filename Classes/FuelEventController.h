// FuelEventController.h
//
// Kraftstoff


#import "FuelStatisticsPageController.h"
#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <MessageUI/MessageUI.h>


@interface FuelEventController : UITableViewController <UIDataSourceModelAssociation, UIViewControllerRestoration, NSFetchedResultsControllerDelegate, MFMailComposeViewControllerDelegate, UIDocumentInteractionControllerDelegate>

@property (nonatomic, strong) NSManagedObject              *selectedCar;
@property (nonatomic, strong) NSManagedObjectContext       *managedObjectContext;
@property (nonatomic, strong) NSFetchRequest               *fetchRequest;
@property (nonatomic, strong) NSFetchedResultsController   *fetchedResultsController;

@property (nonatomic, strong) FuelStatisticsPageController *statisticsController;

@end
