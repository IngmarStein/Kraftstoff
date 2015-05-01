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

// Create a shadow layer that fades downwards / or upwards
+ (CAGradientLayer*)shadowWithFrame:(CGRect)frame
                         darkFactor:(CGFloat)darkFactor
                        lightFactor:(CGFloat)lightFactor
                      fadeDownwards:(BOOL)downwards;

+ (CGGradientRef)backGradient CF_RETURNS_NOT_RETAINED;
+ (CGGradientRef)blueGradient CF_RETURNS_NOT_RETAINED;
+ (CGGradientRef)greenGradient CF_RETURNS_NOT_RETAINED;
+ (CGGradientRef)orangeGradient CF_RETURNS_NOT_RETAINED;
+ (CGGradientRef)infoGradient CF_RETURNS_NOT_RETAINED;
+ (CGGradientRef)knobGradient CF_RETURNS_NOT_RETAINED;



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



#pragma mark Locale Units

+ (KSVolume)volumeUnitFromLocale;
+ (KSFuelConsumption)fuelConsumptionUnitFromLocale;
+ (KSDistance)distanceUnitFromLocale;



#pragma mark Conversion Constants

+ (NSDecimalNumber *)litersPerUSGallon;
+ (NSDecimalNumber *)litersPerImperialGallon;
+ (NSDecimalNumber *)kilometersPerStatuteMile;

+ (NSDecimalNumber *)kilometersPerLiterToMilesPerUSGallon;
+ (NSDecimalNumber *)kilometersPerLiterToMilesPerImperialGallon;
+ (NSDecimalNumber *)litersPer100KilometersToMilesPer10KUSGallon;
+ (NSDecimalNumber *)litersPer100KilometersToMilesPer10KImperialGallon;



#pragma mark Conversion to/from internal Data Format

+ (NSDecimalNumber *)litersForVolume:(NSDecimalNumber *)volume withUnit:(KSVolume)unit;
+ (NSDecimalNumber *)volumeForLiters:(NSDecimalNumber *)liters withUnit:(KSVolume)unit;

+ (NSDecimalNumber *)kilometersForDistance:(NSDecimalNumber *)distance withUnit:(KSDistance)unit;
+ (NSDecimalNumber *)distanceForKilometers:(NSDecimalNumber *)kilometers withUnit:(KSDistance)unit;

+ (NSDecimalNumber *)pricePerLiter:(NSDecimalNumber *)price withUnit:(KSVolume)unit;
+ (NSDecimalNumber *)pricePerUnit:(NSDecimalNumber *)literPrice withUnit:(KSVolume)unit;



#pragma mark Consumption/Efficiency Computation

+ (NSDecimalNumber *)consumptionForKilometers:(NSDecimalNumber *)distance
                                       Liters:(NSDecimalNumber *)volume
                                       inUnit:(KSFuelConsumption)unit;



#pragma mark Unit Strings/Descriptions

+ (NSString *)consumptionUnitString:(KSFuelConsumption)unit;
+ (NSString *)consumptionUnitDescription:(KSFuelConsumption)unit;
+ (NSString *)consumptionUnitShortDescription:(KSFuelConsumption)unit;
+ (NSString *)consumptionUnitAccesibilityDescription:(KSFuelConsumption)unit;

+ (NSString *)fuelUnitString:(KSVolume)unit;
+ (NSString *)fuelUnitDescription:(KSVolume)unit discernGallons:(BOOL)discernGallons pluralization:(BOOL)plural;
+ (NSString *)fuelPriceUnitDescription:(KSVolume)unit;

+ (NSString *)odometerUnitString:(KSDistance)unit;
+ (NSString *)odometerUnitDescription:(KSDistance)unit pluralization:(BOOL)plural;

@end
