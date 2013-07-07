// AppDelegate.h
//
// Kraftstoff


#define kraftstoffDeviceShakeNotification @"kraftstoffDeviceShakeNotification"


// Shadow heights used within the app
extern CGFloat const TableBotShadowHeight;
extern CGFloat const TableTopShadowHeight;

// Standard heights for UI elements
extern CGFloat const TabBarHeight;
extern CGFloat const StatusBarHeight;


// Unit Constants
typedef enum
{
    KSDistanceInvalid = -1,
    KSDistanceKilometer,
    KSDistanceStatuteMile,
} KSDistance;

#define KSDistanceIsMetric(x) ((x) == KSDistanceKilometer)

typedef enum
{
    KSVolumeInvalid = -1,
    KSVolumeLiter,
    KSVolumeGalUS,
    KSVolumeGalUK,
} KSVolume;

#define KSVolumeIsMetric(x) ((x) == KSVolumeLiter)

typedef enum
{
    KSFuelConsumptionInvalid = -1,
    KSFuelConsumptionLitersPer100km,
    KSFuelConsumptionKilometersPerLiter,
    KSFuelConsumptionMilesPerGallonUS,
    KSFuelConsumptionMilesPerGallonUK,
    KSFuelConsumptionGP10KUS,
    KSFuelConsumptionGP10KUK,
} KSFuelConsumption;

#define KSFuelConsumptionIsMetric(x)     ((x) == KSFuelConsumptionLitersPer100km || (x) == KSFuelConsumptionKilometersPerLiter)
#define KSFuelConsumptionIsEfficiency(x) ((x) == KSFuelConsumptionKilometersPerLiter || (x) == KSFuelConsumptionMilesPerGallonUS || (x) == KSFuelConsumptionMilesPerGallonUK)
#define KSFuelConsumptionIsGP10K(x)      ((x) == KSFuelConsumptionGP10KUS || (x) == KSFuelConsumptionGP10KUS)



@interface AppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, strong) IBOutlet UIWindow *window;
@property (nonatomic, weak)   IBOutlet UITabBarController *tabBarController;

// CoreData support
@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;


#pragma mark Hardware/Software Version Check

+ (NSInteger)systemMajorVersion;
+ (BOOL)isLongPhone;



#pragma mark Color Gradients

// Create a shadow layer that fades downwards / or upwards
+ (CAGradientLayer*)shadowWithFrame:(CGRect)frame
                         darkFactor:(CGFloat)darkFactor
                        lightFactor:(CGFloat)lightFactor
                      fadeDownwards:(BOOL)downwards;

+ (CGGradientRef)backGradient;
+ (CGGradientRef)blueGradient;
+ (CGGradientRef)greenGradient;
+ (CGGradientRef)orangeGradient;
+ (CGGradientRef)infoGradient;
+ (CGGradientRef)knobGradient;



#pragma mark Shared Data Formatters

+ (NSDateFormatter *)sharedLongDateFormatter;
+ (NSDateFormatter *)sharedDateFormatter;
+ (NSDateFormatter *)sharedDateTimeFormatter;

+ (NSNumberFormatter *)sharedDistanceFormatter;
+ (NSNumberFormatter *)sharedFuelVolumeFormatter;
+ (NSNumberFormatter *)sharedPreciseFuelVolumeFormatter;
+ (NSNumberFormatter *)sharedCurrencyFormatter;
+ (NSNumberFormatter *)sharedEditPreciseCurrencyFormatter;
+ (NSNumberFormatter *)sharedPreciseCurrencyFormatter;
+ (NSNumberFormatter *)sharedAxisCurrencyFormatter;

+ (NSDecimalNumberHandler *)sharedConsumptionRoundingHandler;
+ (NSDecimalNumberHandler *)sharedPriceRoundingHandler;



#pragma mark Core Data Support

- (BOOL)saveContext:(NSManagedObjectContext *)context;

- (NSString *)cacheNameForFuelEventFetchWithParent:(NSManagedObject *)object;

- (NSString *)modelIdentifierForManagedObject:(NSManagedObject *)object;

- (NSManagedObject *)managedObjectForModelIdentifier:(NSString *)identifier;



#pragma mark Core Data Fetches

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
