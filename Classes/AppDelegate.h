// AppDelegate.h
//
// Kraftstoff


#define kraftstoffDeviceShakeNotification (@"kraftstoffDeviceShakeNotification")


// Unit Constants
typedef enum
{
    KSDistanceKilometer,
    KSDistanceStatuteMile,
} KSDistance;

#define KSDistanceIsMetric(x) ((x) == KSDistanceKilometer)

typedef enum
{
    KSVolumeLiter,
    KSVolumeGalUS,
    KSVolumeGalUK,
} KSVolume;

#define KSVolumeIsMetric(x) ((x) == KSVolumeLiter)

typedef enum
{
    KSFuelConsumptionLitersPer100km,
    KSFuelConsumptionKilometersPerLiter,
    KSFuelConsumptionMilesPerGallonUS,
    KSFuelConsumptionMilesPerGallonUK,
} KSFuelConsumption;

#define KSFuelConsumptionIsMetric(x) ((x) == KSFuelConsumptionLitersPer100km || (x) == KSFuelConsumptionKilometersPerLiter)


// Shadow heights used within the app
extern CGFloat const LargeShadowHeight;
extern CGFloat const MediumShadowHeight;
extern CGFloat const SmallShadowHeight;

// Standard heights for UI elements
extern CGFloat const TabBarHeight;
extern CGFloat const NavBarHeight;
extern CGFloat const StatusBarHeight;
extern CGFloat const HugeStatusBarHeight;


@interface AppDelegate : NSObject <UIApplicationDelegate> {}

@property (nonatomic, strong) UIAlertView *importAlert;

@property (nonatomic, strong) IBOutlet UIWindow               *window;
@property (nonatomic, strong) IBOutlet UITabBarController     *tabBarController;
@property (nonatomic, strong) IBOutlet UINavigationController *calculatorNavigationController;
@property (nonatomic, strong) IBOutlet UINavigationController *statisticsNavigationController;
@property (nonatomic, strong) IBOutlet UIImageView            *background;

@property (nonatomic, strong, readonly) NSManagedObjectContext       *managedObjectContext;
@property (nonatomic, strong, readonly) NSManagedObjectModel         *managedObjectModel;
@property (nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;


// Setting the background image (for EventEditor)
- (void)setWindowBackground: (UIImage*)image animated: (BOOL)animated;

// The shared application delegate
+ (AppDelegate*)sharedDelegate;


#pragma mark Date Computations

// Adding a month offset to dates, also removes the second component
+ (NSDate*)dateWithOffsetInMonths: (NSInteger)numberOfMonths fromDate: (NSDate*)startDate;

// Removes the second component from a date
+ (NSDate*)dateWithoutSeconds: (NSDate*)date;


#pragma mark Color Gradients

// Create a shadow layer that fades downwards / or upwards when inverse is YES.
+ (CAGradientLayer*)shadowWithFrame: (CGRect)frame
                         darkFactor: (CGFloat)darkFactor
                        lightFactor: (CGFloat)lightFactor
                            inverse: (BOOL)inverse;

+ (CGGradientRef)backGradient;
+ (CGGradientRef)blueGradient;
+ (CGGradientRef)greenGradient;
+ (CGGradientRef)orangeGradient;
+ (CGGradientRef)infoGradient;
+ (CGGradientRef)knobGradient;


#pragma mark Shared Data Formatters

+ (NSDateFormatter*)sharedLongDateFormatter;
+ (NSDateFormatter*)sharedDateFormatter;
+ (NSDateFormatter*)sharedDateTimeFormatter;

+ (NSNumberFormatter*)sharedDistanceFormatter;
+ (NSNumberFormatter*)sharedFuelVolumeFormatter;
+ (NSNumberFormatter*)sharedCurrencyFormatter;
+ (NSNumberFormatter*)sharedEditPreciseCurrencyFormatter;
+ (NSNumberFormatter*)preciseCurrencyFormatter;
+ (NSNumberFormatter*)sharedAxisCurrencyFormatter;

+ (NSDecimalNumberHandler*)sharedConsumptionRoundingHandler;
+ (NSDecimalNumberHandler*)sharedPriceRoundingHandler;


#pragma mark Core Data Support

- (BOOL)saveContext: (NSManagedObjectContext*)context;

- (NSManagedObject*)managedObjectForURLString: (NSString*)URLString;


#pragma mark Core Data Fetches

+ (NSFetchedResultsController*)fetchedResultsControllerForCarsInContext: (NSManagedObjectContext*)managedObjectContext;

+ (NSString*)cacheNameForFuelEventFetchWithParent: (NSManagedObject*)object;

+ (NSFetchRequest*)fetchRequestForEventsForCar: (NSManagedObject*)car
                                     afterDate: (NSDate*)date
                                   dateMatches: (BOOL)dateMatches
                        inManagedObjectContext: (NSManagedObjectContext*)moc;

+ (NSFetchRequest*)fetchRequestForEventsForCar: (NSManagedObject*)car
                                    beforeDate: (NSDate*)date
                                   dateMatches: (BOOL)dateMatches
                        inManagedObjectContext: (NSManagedObjectContext*)moc;

+ (NSArray*)objectsForFetchRequest: (NSFetchRequest*)fetchRequest
            inManagedObjectContext: (NSManagedObjectContext*)managedObjectContext;

+ (BOOL)managedObjectContext: (NSManagedObjectContext*)managedObjectContext
        containsEventWithCar: (NSManagedObject*)car
                     andDate: (NSDate*)date;


#pragma mark Core Data Updates


+ (NSManagedObject*)addToArchiveWithCar: (NSManagedObject*)car
                                   date: (NSDate*)date
                               distance: (NSDecimalNumber*)distance
                                  price: (NSDecimalNumber*)price
                             fuelVolume: (NSDecimalNumber*)fuelVolume
                               filledUp: (BOOL)filledUp
                 inManagedObjectContext: (NSManagedObjectContext*)managedObjectContext
                    forceOdometerUpdate: (BOOL)forceOdometerUpdate;

+ (void)removeEventFromArchive: (NSManagedObject*)event
        inManagedObjectContext: (NSManagedObjectContext*)managedObjectContext
           forceOdometerUpdate: (BOOL)forceOdometerUpdate;


#pragma mark Locale Units

+ (KSVolume)fuelUnitFromLocale;
+ (KSFuelConsumption)fuelConsumptionUnitFromLocale;
+ (KSDistance)odometerUnitFromLocale;


#pragma mark Conversion Constants

+ (NSDecimalNumber*)litersPerUSGallon;
+ (NSDecimalNumber*)litersPerImperialGallon;
+ (NSDecimalNumber*)kilometersPerStatuteMile;


#pragma mark Conversion to/from internal Data Format

+ (NSDecimalNumber*)litersForVolume: (NSDecimalNumber*)volume withUnit: (KSVolume)unit;
+ (NSDecimalNumber*)volumeForLiters: (NSDecimalNumber*)liters withUnit: (KSVolume)unit;

+ (NSDecimalNumber*)kilometersForDistance: (NSDecimalNumber*)distance   withUnit: (KSDistance)unit;
+ (NSDecimalNumber*)distanceForKilometers: (NSDecimalNumber*)kilometers withUnit: (KSDistance)unit;

+ (NSDecimalNumber*)pricePerLiter: (NSDecimalNumber*)price      withUnit: (KSVolume)unit;
+ (NSDecimalNumber*)pricePerUnit:  (NSDecimalNumber*)literPrice withUnit: (KSVolume)unit;


#pragma mark Consumption/Efficiency Computation

+ (NSDecimalNumber*)consumptionForDistance: (NSDecimalNumber*)distance
                                    Volume: (NSDecimalNumber*)volume
                                  withUnit: (KSFuelConsumption)unit;

+ (NSDecimalNumber*)mpgUSFromKML: (NSDecimalNumber*)kmPerLiter;
+ (NSDecimalNumber*)mpgImperialFromKML: (NSDecimalNumber*)kmPerLiter;


#pragma mark Unit Strings/Descriptions

+ (NSString*)consumptionUnitString: (KSFuelConsumption)unit;
+ (NSString*)consumptionUnitDescription: (KSFuelConsumption)unit;
+ (NSString*)consumptionUnitShadedTableViewCellDescription: (KSFuelConsumption)unit;

+ (NSString*)fuelUnitString: (KSVolume)unit;
+ (NSString*)fuelUnitDescription: (KSVolume)unit discernGallons: (BOOL)discernGallons;
+ (NSString*)fuelPriceUnitDescription: (KSVolume)unit;

+ (NSString*)odometerUnitString: (KSDistance)unit;
+ (NSString*)odometerUnitDescription: (KSDistance)unit;


#pragma mark Mixed Pickles

+ (BOOL)runningOS5;

@end
