// AppDelegate.h
//
// Kraftstoff

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

#define kraftstoffDeviceShakeNotification @"kraftstoffDeviceShakeNotification"


// Unit Constants
typedef NS_ENUM(NSInteger, KSDistance)
{
    KSDistanceInvalid = -1,
    KSDistanceKilometer,
    KSDistanceStatuteMile,
};

#define KSDistanceIsMetric(x) ((x) == KSDistanceKilometer)

typedef NS_ENUM(NSInteger, KSVolume)
{
    KSVolumeInvalid = -1,
    KSVolumeLiter,
    KSVolumeGalUS,
    KSVolumeGalUK,
};

#define KSVolumeIsMetric(x) ((x) == KSVolumeLiter)

typedef NS_ENUM(NSInteger, KSFuelConsumption)
{
    KSFuelConsumptionInvalid = -1,
    KSFuelConsumptionLitersPer100km,
    KSFuelConsumptionKilometersPerLiter,
    KSFuelConsumptionMilesPerGallonUS,
    KSFuelConsumptionMilesPerGallonUK,
    KSFuelConsumptionGP10KUS,
    KSFuelConsumptionGP10KUK,
};

#define KSFuelConsumptionIsMetric(x)     ((x) == KSFuelConsumptionLitersPer100km || (x) == KSFuelConsumptionKilometersPerLiter)
#define KSFuelConsumptionIsEfficiency(x) ((x) == KSFuelConsumptionKilometersPerLiter || (x) == KSFuelConsumptionMilesPerGallonUS || (x) == KSFuelConsumptionMilesPerGallonUK)
#define KSFuelConsumptionIsGP10K(x)      ((x) == KSFuelConsumptionGP10KUS || (x) == KSFuelConsumptionGP10KUS)



@interface AppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;

// CoreData support
@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;


#pragma mark Color Gradients

+ (CGGradientRef)blueGradient CF_RETURNS_NOT_RETAINED;
+ (CGGradientRef)greenGradient CF_RETURNS_NOT_RETAINED;
+ (CGGradientRef)orangeGradient CF_RETURNS_NOT_RETAINED;



#pragma mark Core Data Support

- (BOOL)saveContext:(NSManagedObjectContext *)context;
- (NSString *)modelIdentifierForManagedObject:(NSManagedObject *)object;
- (NSManagedObject *)managedObjectForModelIdentifier:(NSString *)identifier;
+ (NSManagedObject *)existingObject:(NSManagedObject *)object inManagedObjectContext:(NSManagedObjectContext *)moc;



#pragma mark Preconfigured Core Data Fetches

+ (NSFetchRequest *)fetchRequestForCarsInManagedObjectContext:(NSManagedObjectContext *)moc;

+ (NSFetchRequest *)fetchRequestForEventsForCar:(NSManagedObject *)car
                                      afterDate:(NSDate *)date
                                    dateMatches:(BOOL)dateMatches
                         inManagedObjectContext:(NSManagedObjectContext *)moc;

+ (NSFetchRequest *)fetchRequestForEventsForCar:(NSManagedObject *)car
                                     beforeDate:(NSDate *)date
                                    dateMatches:(BOOL)dateMatches
                         inManagedObjectContext:(NSManagedObjectContext *)moc;

+ (NSFetchedResultsController *)fetchedResultsControllerForCarsInContext:(NSManagedObjectContext *)managedObjectContext;

+ (NSArray *)objectsForFetchRequest:(NSFetchRequest *)fetchRequest
             inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

+ (BOOL)managedObjectContext:(NSManagedObjectContext *)managedObjectContext
        containsEventWithCar:(NSManagedObject *)car
                     andDate:(NSDate *)date;



#pragma mark Core Data Updates

+ (NSManagedObject *)addToArchiveWithCar:(NSManagedObject *)car
                                    date:(NSDate *)date
                                distance:(NSDecimalNumber *)distance
                                   price:(NSDecimalNumber *)price
                              fuelVolume:(NSDecimalNumber *)fuelVolume
                                filledUp:(BOOL)filledUp
                  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                     forceOdometerUpdate:(BOOL)forceOdometerUpdate;

+ (void)removeEventFromArchive:(NSManagedObject *)event
        inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
           forceOdometerUpdate:(BOOL)forceOdometerUpdate;

@end
