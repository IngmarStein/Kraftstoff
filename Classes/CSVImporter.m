// CSVImporter.m
//
// Kraftstoff


#import "CSVImporter.h"
#import "CSVParser.h"
#import "AppDelegate.h"
#import "TextEditTableCell.h"


@interface CSVImporter (private)

// CoreData Object Creattion
- (NSManagedObject*)addCarWithName: (NSString*)name
                             plate: (NSString*)plate
                      odometerUnit: (KSDistance)odometerUnit
                        volumeUnit: (KSVolume)volumeUnit
               fuelConsumptionUnit: (KSFuelConsumption)fuelConsumptionUnit
                         inContext: (NSManagedObjectContext*)managedObjectContext
                    fetchedObjects: (NSArray*)fetchedObjects;

- (NSManagedObject*)addEventForCar: (NSManagedObject*)car
                              date: (NSDate*)date
                          distance: (NSDecimalNumber*)distance
                             price: (NSDecimalNumber*)price
                        fuelVolume: (NSDecimalNumber*)fuelVolume
                     inheritedCost: (NSDecimalNumber*)inheritedCost
                 inheritedDistance: (NSDecimalNumber*)inheritedDistance
               inheritedFuelVolume: (NSDecimalNumber*)inheritedFuelVolume
                          filledUp: (BOOL)filledUp
                         inContext: (NSManagedObjectContext*)managedObjectContext;

// Scanning support for CSVs
- (NSDecimalNumber*)scanNumberWithString: (NSString*)string;

- (NSDate*)scanDate: (NSString*)dateString withOptionalTime: (NSString*)timeString;
- (NSDate*)scanDateWithString: (NSString*)string;
- (NSDate*)scanTimeWithString: (NSString*)string;

- (BOOL)scanBooleanWithString: (NSString*)string;

- (KSVolume)scanVolumeUnitWithString: (NSString*)string;

// CSV interpretation support
- (NSString*)hittestForKeystrings: (NSString**)keyStrings inDictionary: (NSDictionary*)record;

- (NSString*)keyForDate: (NSDictionary*)record;
- (NSString*)keyForTime: (NSDictionary*)record;

- (NSString*)keyForDistance: (NSDictionary*)record unit: (KSDistance*)unit;
- (NSString*)keyForOdometer: (NSDictionary*)record unit: (KSDistance*)unit;
- (NSString*)keyForVolume:   (NSDictionary*)record unit: (KSVolume*)unit;

- (NSString*)keyForVolume:     (NSDictionary*)record;
- (NSString*)keyForVolumeUnit: (NSDictionary*)record;

- (NSString*)keyForPrice: (NSDictionary*)record;
- (NSString*)keyForFillup: (NSDictionary*)record;

- (NSString*)keyForModel: (NSDictionary*)record;
- (NSString*)keyForCarID: (NSDictionary*)record;

@end



@implementation CSVImporter


- (id)init
{
    if ((self = [super init]))
    {
        carIDs     = [[NSMutableSet setWithCapacity: 7] retain];
        nameForID  = [[NSMutableDictionary dictionaryWithCapacity: 7] retain];
        modelForID = [[NSMutableDictionary dictionaryWithCapacity: 7] retain];
    }

    return self;
}


- (void)dealloc
{
    [carIDs     release];
    [nameForID  release];
    [modelForID release];

    [super dealloc];
}


- (BOOL)importCarIDs: (NSArray*)records
{
    NSDictionary *first = [records objectAtIndex: 0];

    if ([first count] != 3)
        return NO;

    if ([first objectForKey: @"ID"] == nil)
        return NO;

    NSString *modelKey = [self keyForModel: first];

    if (modelKey == nil)
        return NO;

    if ([first objectForKey: @"NAME"] == nil)
        return NO;

    [carIDs     removeAllObjects];
    [nameForID  removeAllObjects];
    [modelForID removeAllObjects];

    for (NSDictionary *record in records)
    {
        NSNumber *ID = [self scanNumberWithString: [record objectForKey: @"ID"]];

        if (ID != nil && [carIDs containsObject: ID] == NO)
        {
            NSString *name  = [record objectForKey: @"NAME"];
            NSString *model = [record objectForKey: modelKey];

            if (name != nil && model != nil)
            {
                [carIDs addObject: ID];
                [nameForID  setObject: name  forKey: ID];
                [modelForID setObject: model forKey: ID];
            }
        }
    }

    return ([carIDs count] != 0);
}


- (NSManagedObject*)addCarWithName: (NSString*)name
                             plate: (NSString*)plate
                      odometerUnit: (KSDistance)odometerUnit
                        volumeUnit: (KSVolume)volumeUnit
               fuelConsumptionUnit: (KSFuelConsumption)fuelConsumptionUnit
                         inContext: (NSManagedObjectContext*)managedObjectContext
                    fetchedObjects: (NSArray*)fetchedObjects
{
    // Update order of existing objects
    for (NSManagedObject *managedObject in fetchedObjects)
    {
        NSInteger order = [[managedObject valueForKey: @"order"] integerValue];

        [managedObject setValue: [NSNumber numberWithInt: order+1] forKey: @"order"];
    }

    // Create and configure new car object
    NSManagedObject *newCar = [NSEntityDescription insertNewObjectForEntityForName: @"car"
                                                            inManagedObjectContext: managedObjectContext];

    if (odometerUnit == -1)
        odometerUnit = [AppDelegate odometerUnitFromLocale];

    [newCar setValue: [NSNumber numberWithInt: 0]            forKey: @"order"];
    [newCar setValue: [NSDate date]                          forKey: @"timestamp"];
    [newCar setValue: name                                   forKey: @"Name"];
    [newCar setValue: plate                                  forKey: @"numberPlate"];
    [newCar setValue: [NSNumber numberWithInt: odometerUnit] forKey: @"odometerUnit"];
    [newCar setValue: [NSDecimalNumber zero]                 forKey: @"odometer"];

    if (volumeUnit == -1)
        volumeUnit = [AppDelegate fuelUnitFromLocale];

    [newCar setValue: [NSNumber numberWithInt: volumeUnit] forKey: @"fuelUnit"];

    if (fuelConsumptionUnit == -1)
        fuelConsumptionUnit = [AppDelegate fuelConsumptionUnitFromLocale];

    [newCar setValue: [NSNumber numberWithInt: fuelConsumptionUnit] forKey: @"fuelConsumptionUnit"];

    return newCar;
}


- (NSManagedObject*)addEventForCar: (NSManagedObject*)car
                              date: (NSDate*)date
                          distance: (NSDecimalNumber*)distance
                             price: (NSDecimalNumber*)price
                        fuelVolume: (NSDecimalNumber*)fuelVolume
                     inheritedCost: (NSDecimalNumber*)inheritedCost
                 inheritedDistance: (NSDecimalNumber*)inheritedDistance
               inheritedFuelVolume: (NSDecimalNumber*)inheritedFuelVolume
                          filledUp: (BOOL)filledUp
                         inContext: (NSManagedObjectContext*)managedObjectContext
{
    NSManagedObject *newEvent = [NSEntityDescription insertNewObjectForEntityForName: @"fuelEvent"
                                                              inManagedObjectContext: managedObjectContext];

    [newEvent setValue: car        forKey: @"car"];
    [newEvent setValue: date       forKey: @"timestamp"];
    [newEvent setValue: distance   forKey: @"distance"];
    [newEvent setValue: price      forKey: @"price"];
    [newEvent setValue: fuelVolume forKey: @"fuelVolume"];

    if (filledUp == NO)
        [newEvent setValue: [NSNumber numberWithBool: filledUp] forKey: @"filledUp"];

    NSDecimalNumber *zero = [NSDecimalNumber zero];

    if ([inheritedCost isEqualToNumber: zero] == NO)
        [newEvent setValue: inheritedCost forKey: @"inheritedCost"];

    if ([inheritedDistance isEqualToNumber: zero] == NO)
        [newEvent setValue: inheritedDistance forKey: @"inheritedDistance"];

    if ([inheritedFuelVolume isEqualToNumber: zero] == NO)
        [newEvent setValue: inheritedFuelVolume forKey: @"inheritedFuelVolume"];

    [car setValue: [[car valueForKey: @"distanceTotalSum"]   decimalNumberByAdding: distance]   forKey: @"distanceTotalSum"];
    [car setValue: [[car valueForKey: @"fuelVolumeTotalSum"] decimalNumberByAdding: fuelVolume] forKey: @"fuelVolumeTotalSum"];

    return newEvent;
}


- (BOOL)importRecords: (NSArray*)records detectedCars: (NSInteger*)numCars detectedEvents: (NSInteger*)numEvents sourceURL: (NSURL*)sourceURL
{
    // Analyze source URL for name/plate
    NSString *guessedName  = nil;
    NSString *guessedPlate = nil;    

    if ([sourceURL isFileURL])
    {
        NSArray *nameComponents = [[[[sourceURL path] lastPathComponent] stringByDeletingPathExtension] componentsSeparatedByString: @"__"];
        NSString *part;

        // New exported files
        if ([nameComponents count] == 2)
        {
            part = [nameComponents objectAtIndex: 0];

            if ([part length] > 0)
            {
                if ([part length] > maximumTextFieldLength)
                    part = [part substringToIndex: maximumTextFieldLength];

                guessedName = part;
            }

            part = [nameComponents objectAtIndex: 1];

            if ([part length] > 0)
            {
                if ([part length] > maximumTextFieldLength)
                    part = [part substringToIndex: maximumTextFieldLength];
                
                guessedPlate = part;
            }
        }

        // Old exported files
        else if ([nameComponents count] == 1)
        {            
            part = [nameComponents objectAtIndex: 0];

            if ([part length] > 0)
            {
                if ([part length] > maximumTextFieldLength)
                    part = [part substringToIndex: maximumTextFieldLength];
                
                guessedPlate = part;
            }
        }
    }
        
    
    // Analyse record headers
    NSDictionary *first = [records objectAtIndex: 0];

    BOOL importFromTankPro = NO;
    KSDistance distanceUnit = -1;
    KSDistance odometerUnit = -1;
    KSVolume   volumeUnit   = -1;

    NSString *IDKey           = [self keyForCarID: first];
    NSString *dateKey         = [self keyForDate: first];
    NSString *timeKey         = [self keyForTime: first];
    NSString *distanceKey     = [self keyForDistance: first unit: &distanceUnit];
    NSString *odometerKey     = [self keyForOdometer: first unit: &odometerUnit];
    NSString *volumeKey       = [self keyForVolume: first unit: &volumeUnit];
    NSString *volumeAmountKey = [self keyForVolume: first];
    NSString *volumeUnitKey   = [self keyForVolumeUnit: first];
    NSString *priceKey        = [self keyForPrice: first];
    NSString *fillupKey       = [self keyForFillup: first];

    if (dateKey == nil
        || (odometerKey == nil && distanceKey == nil)
        || (volumeKey == nil && (volumeAmountKey == nil || volumeUnitKey == nil))
        || priceKey == nil)
        return NO;

    if ([carIDs count])
    {
        if (IDKey != nil && distanceKey == nil && odometerKey != nil && volumeKey == nil && volumeUnitKey != nil && fillupKey != nil)
            importFromTankPro = YES;
    }

    // Dummy object for carID loop
    if (!importFromTankPro)
        [carIDs addObject: [NSNull null]];


    // Sort records according time and odometer
    NSMutableArray *sortedRecords = [NSMutableArray arrayWithCapacity: [records count]];

    [sortedRecords addObjectsFromArray: records];
    [sortedRecords sortUsingComparator:
        ^NSComparisonResult (id obj1, id obj2)
        {
            NSComparisonResult cmpResult = NSOrderedSame;

            NSDate *date1 = [self scanDate: [obj1 objectForKey: dateKey] withOptionalTime: [obj1 objectForKey: timeKey]];
            NSDate *date2 = [self scanDate: [obj2 objectForKey: dateKey] withOptionalTime: [obj2 objectForKey: timeKey]];

            if (date1 != nil && date2 != nil)
                cmpResult = [date1 compare: date2];

            if (cmpResult == NSOrderedSame && odometerKey != nil)
            {
                NSNumber *odometer1 = [self scanNumberWithString: [obj1 objectForKey: odometerKey]];
                NSNumber *odometer2 = [self scanNumberWithString: [obj2 objectForKey: odometerKey]];

                if (odometer1 != nil && odometer2 != nil)
                    cmpResult = [odometer1 compare: odometer2];
            }

            return cmpResult;
        }];


    // Parse all records for all cars
    NSManagedObjectContext *managedObjectContext = [[AppDelegate sharedDelegate] managedObjectContext];
    NSFetchedResultsController *fetchedResultsController = [AppDelegate fetchedResultsControllerForCarsInContext: managedObjectContext];

    for (NSNumber *importID in carIDs)
    {
        NSDate *lastDate         = [NSDate distantPast];
        NSTimeInterval lastDelta = 0.0;
        BOOL detectedEvents      = NO;

        NSDecimalNumber *zero                = [NSDecimalNumber zero];
        NSDecimalNumber *odometer            = zero;
        NSDecimalNumber *inheritedCost       = zero;
        NSDecimalNumber *inheritedDistance   = zero;
        NSDecimalNumber *inheritedFuelVolume = zero;

        *numCars = *numCars + 1;

        NSString *name = [modelForID objectForKey: importID];

        if (name == nil)
            name = guessedName;
        if (name == nil)
            name = [NSString stringWithFormat: @"%@", _I18N (@"Imported Car")];
        else if ([name length] > maximumTextFieldLength)
            name = [name substringToIndex: maximumTextFieldLength];

        NSString *plate = [nameForID objectForKey: importID];

        if (plate == nil)
            plate = guessedPlate;
        if (plate == nil)
            plate = @"";
        else if ([plate length] > maximumTextFieldLength)
            plate = [plate substringToIndex: maximumTextFieldLength];

        NSManagedObject *newCar = [self addCarWithName: name
                                                 plate: plate
                                          odometerUnit: (distanceUnit != -1) ? distanceUnit : odometerUnit
                                            volumeUnit: volumeUnit
                                   fuelConsumptionUnit: -1
                                             inContext: managedObjectContext
                                        fetchedObjects: [fetchedResultsController fetchedObjects]];

        for (NSDictionary *record in sortedRecords)
        {
            // Match car IDs when importing from Tank Pro
            if (importFromTankPro)
            {
                NSDecimalNumber *carID = [self scanNumberWithString: [record objectForKey: IDKey]];

                if (!carID || [importID isEqualToNumber: carID] == NO)
                    continue;
            }

            NSDate *date         = [self scanDate: [record objectForKey: dateKey] withOptionalTime: [record objectForKey: timeKey]];
            NSTimeInterval delta = [date timeIntervalSinceDate: lastDate];

            if (delta <= 0.0 || lastDelta > 0.0)
            {
                lastDelta = (delta > 0.0) ? 0.0 : ceilf (fabs (delta) + 60.0);
                date      = [date dateByAddingTimeInterval: lastDelta];
            }

            if ([date timeIntervalSinceDate: lastDate] <= 0.0)
                continue;

            NSDecimalNumber *distance = nil;

            if (distanceKey != nil)
            {
                distance = [self scanNumberWithString: [record objectForKey: distanceKey]];

                if (distance)
                    distance = [AppDelegate kilometersForDistance: distance withUnit: distanceUnit];
            }
            else
            {
                NSDecimalNumber *newOdometer = [self scanNumberWithString: [record objectForKey: odometerKey]];

                if (newOdometer)
                {
                    newOdometer = [AppDelegate kilometersForDistance: newOdometer withUnit: odometerUnit];
                    distance    = [newOdometer decimalNumberBySubtracting: odometer];
                    odometer    = newOdometer;
                }
            }

            NSDecimalNumber *volume = nil;

            if (volumeUnit != -1)
            {
                volume = [self scanNumberWithString: [record objectForKey: volumeKey]];

                if (volume)
                    volume = [AppDelegate litersForVolume: volume withUnit: volumeUnit];
            }
            else
            {
                volume = [self scanNumberWithString: [record objectForKey: volumeAmountKey]];

                if (volume)
                    volume = [AppDelegate litersForVolume: volume withUnit: [self scanVolumeUnitWithString: [record objectForKey: volumeUnitKey]]];
            }

            NSDecimalNumber *price = [self scanNumberWithString: [record objectForKey: priceKey]];


            // TankPro stores total costs not the price per liter...
            if (importFromTankPro)
            {
                if (volume == nil || [volume isEqualToNumber: [NSDecimalNumber zero]])
                    price = [NSDecimalNumber zero];
                else
                    price = [price decimalNumberByDividingBy: volume
                                                withBehavior: [AppDelegate sharedPriceRoundingHandler]];
            }

            BOOL filledUp = [self scanBooleanWithString: [record objectForKey: fillupKey]];

            // Consistency check and import
            if ([distance compare: zero] == NSOrderedDescending &&
                [volume   compare: zero] == NSOrderedDescending &&
                [price    compare: zero] == NSOrderedDescending)
            {
                [self addEventForCar: newCar
                                date: date
                            distance: distance
                               price: price
                          fuelVolume: volume
                       inheritedCost: inheritedCost
                   inheritedDistance: inheritedDistance
                 inheritedFuelVolume: inheritedFuelVolume
                            filledUp: filledUp
                           inContext: managedObjectContext];

                if (filledUp)
                {
                    inheritedCost       = zero;
                    inheritedDistance   = zero;
                    inheritedFuelVolume = zero;
                }
                else
                {
                    inheritedCost       = [inheritedCost       decimalNumberByAdding: [volume decimalNumberByMultiplyingBy: price]];
                    inheritedDistance   = [inheritedDistance   decimalNumberByAdding: distance];
                    inheritedFuelVolume = [inheritedFuelVolume decimalNumberByAdding: volume];
                }

                *numEvents = *numEvents + 1;
                detectedEvents = YES;
                lastDate = date;
            }
        }

        // Fixup car odometer
        if (detectedEvents)
            [newCar setValue: [odometer max: [newCar valueForKey: @"distanceTotalSum"]] forKey: @"odometer"];

        // Save imported objects
        [[AppDelegate sharedDelegate] saveContext: managedObjectContext];
    }

    if (!importFromTankPro)
        [carIDs removeAllObjects];

    return YES;
}



#pragma mark -
#pragma mark Scanning Support



- (NSDecimalNumber*)scanNumberWithString: (NSString*)string
{
    if (string == nil)
        return nil;

    // Scan via NSScanner (fast, strict)
    NSScanner *scanner = [NSScanner scannerWithString: string];
    NSDecimal d;

    [scanner setLocale: [NSLocale currentLocale]];
    [scanner setScanLocation: 0];

    if ([scanner scanDecimal: &d] && [scanner isAtEnd])
        return [NSDecimalNumber decimalNumberWithDecimal: d];

    [scanner setLocale: [NSLocale systemLocale]];
    [scanner setScanLocation: 0];

    if ([scanner scanDecimal: &d] && [scanner isAtEnd])
        return [NSDecimalNumber decimalNumberWithDecimal: d];


    // Scan with localized numberformatter (sloppy, catches grouping separators)
    static NSNumberFormatter *nf = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        nf = [[NSNumberFormatter alloc] init];

        [nf setGeneratesDecimalNumbers: YES];
        [nf setUsesGroupingSeparator: YES];
        [nf setNumberStyle: NSNumberFormatterDecimalStyle];
        [nf setLenient: YES];
    });

    NSNumber *dn;

    [nf setLocale: [NSLocale currentLocale]];

    if ((dn = [nf numberFromString: string]))
        return (NSDecimalNumber*)dn;

    [nf setLocale: [NSLocale systemLocale]];

    if ((dn = [nf numberFromString: string]))
        return (NSDecimalNumber*)dn;

    return nil;
}


- (NSDate*)scanDate: (NSString*)dateString withOptionalTime: (NSString*)timeString
{
    NSDate *date = [self scanDateWithString: dateString];
    NSDate *time = nil;

    if (date == nil)
        return nil;

    if (timeString != nil)
        time = [self scanTimeWithString: timeString];

    if (time == nil)
        time = [NSDate dateWithTimeIntervalSince1970: 43200];

    return [date dateByAddingTimeInterval: [time timeIntervalSince1970]];
}


- (NSDate*)scanDateWithString: (NSString*)string
{
    static NSDateFormatter *df = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        df = [[NSDateFormatter alloc] init];
    });

    NSDate *d;

    if (string == nil)
        return nil;

    // Strictly scan own format in system locale
    [df setLocale: [NSLocale systemLocale]];
    [df setDateFormat: @"yyyy-MM-dd"];
    [df setLenient: NO];

    if ((d = [df dateFromString: string]))
        return d;

    // Alternatively scan date in short local style
    [df setLocale: [NSLocale currentLocale]];
    [df setDateStyle: NSDateFormatterShortStyle];
    [df setTimeStyle: NSDateFormatterNoStyle];
    [df setLenient: YES];

    if ((d = [df dateFromString: string]))
        return d;

    return nil;
}


- (NSDate*)scanTimeWithString: (NSString*)string
{
    static NSDateFormatter *df = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        df = [[NSDateFormatter alloc] init];
        [df setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
    });

    NSDate *d;

    if (string == nil)
        return nil;

    // Strictly scan own format in system locale
    [df setLocale: [NSLocale systemLocale]];
    [df setDateFormat: @"HH:mm"];
    [df setLenient: NO];

    if ((d = [df dateFromString: string]))
        return d;

    // Alternatively scan date in short local style
    [df setLocale: [NSLocale currentLocale]];
    [df setTimeStyle: NSDateFormatterShortStyle];
    [df setDateStyle: NSDateFormatterNoStyle];
    [df setLenient: YES];

    if ((d = [df dateFromString: string]))
        return d;

    return nil;
}


- (BOOL)scanBooleanWithString: (NSString*)string
{
    if (string == nil)
        return YES;

    NSNumber *n = [self scanNumberWithString: string];

    if (n != nil)
    {
        return ([n integerValue] != 0);
    }
    else
    {
        string = [string uppercaseString];
        return (![string isEqualToString: @"NO"] && ![string isEqualToString: @"NEIN"]);
    }
}


- (KSVolume)scanVolumeUnitWithString: (NSString*)string
{
    if (string == nil)
        return KSVolumeLiter;

    string = [CSVParser simplifiedHeader: string];


    // Catch Tank Pro exports
    if ([string isEqualToString: @"L"])
        return KSVolumeLiter;

    if ([string isEqualToString: @"G"])
    {
        // TankPro seems to export both gallons simply as "G" => search locale for feasible guess
        if ([AppDelegate fuelUnitFromLocale] == KSVolumeGalUS)
            return KSVolumeGalUS;
        else
            return KSVolumeGalUK;
    }


    // Catch some other forms of gallons
    NSRange range = [string rangeOfString: @"GAL"];

    if (range.location != NSNotFound)
    {
        range = [string rangeOfString: @"US"];

        if (range.location != NSNotFound)
            return KSVolumeGalUS;

        range = [string rangeOfString: @"UK"];

        if (range.location != NSNotFound)
            return KSVolumeGalUK;

        if ([AppDelegate fuelUnitFromLocale] == KSVolumeGalUS)
            return KSVolumeGalUS;
        else
            return KSVolumeGalUK;
    }


    // Liters as default
    return KSVolumeLiter;
}



#pragma mark -
#pragma mark CSV Interpretation Support



- (NSString*)hittestForKeystrings: (NSString**)keyStrings inDictionary: (NSDictionary*)record
{
    for (int i = 0; keyStrings [i] != nil; i++)
        if ([record objectForKey: keyStrings [i]] != nil)
            return keyStrings [i];

    return nil;
}


- (NSString*)keyForDate: (NSDictionary*)record
{
    static NSString *dateStrings [] =
    {
        @"JJJJMMTT",
        @"YYYYMMDD",
        @"DATE",
        @"DATUM",
        nil
    };

    return [self hittestForKeystrings: dateStrings inDictionary: record];
}


- (NSString*)keyForTime: (NSDictionary*)record
{
    static NSString *timeStrings [] =
    {
        @"HHMM",
        @"TIME",
        @"ZEIT",
        nil
    };

    return [self hittestForKeystrings: timeStrings inDictionary: record];
}


- (NSString*)keyForDistance: (NSDictionary*)record unit: (KSDistance*)unit
{
    NSString *key;

    static NSString *kilometersStrings [] =
    {
        @"KILOMETERS",
        @"KILOMETER",
        nil
    };

    static NSString *milesStrings [] =
    {
        @"MILES",
        @"MEILEN",
        nil
    };

    if ((key = [self hittestForKeystrings: kilometersStrings inDictionary: record]))
    {
        *unit = KSDistanceKilometer;
        return key;
    }
    else if ((key = [self hittestForKeystrings: milesStrings inDictionary: record]))
    {
        *unit = KSDistanceStatuteMile;
        return key;
    }

    return nil;
}


- (NSString*)keyForOdometer:(NSDictionary *)record unit:(KSDistance*)unit
{
    NSString *key;

    static NSString *kilometersStrings [] =
    {
        @"ODOMETER(KM)",
        @"KILOMETERSTAND(KM)",
        nil
    };

    static NSString *milesStrings [] =
    {
        @"ODOMETER(MI)",
        @"KILOMETERSTAND(MI)",
        nil
    };

    if ((key = [self hittestForKeystrings: kilometersStrings inDictionary: record]))
    {
        *unit = KSDistanceKilometer;
        return key;
    }
    else if ((key = [self hittestForKeystrings: milesStrings inDictionary: record]))
    {
        *unit = KSDistanceStatuteMile;
        return key;
    }

    return nil;
}


- (NSString*)keyForVolume: (NSDictionary*)record unit: (KSVolume*)unit;
{
    NSString *key;

    static NSString *literStrings [] =
    {
        @"LITERS",
        @"LITER",
        nil
    };

    static NSString *galStringsUS [] =
    {
        @"GALLONS(US)",
        @"GALLONEN(US)",
        nil
    };

    static NSString *galStringsUK [] =
    {
        @"GALLONS(UK)",
        @"GALLONEN(UK)",
        nil
    };

    if ((key = [self hittestForKeystrings: literStrings inDictionary: record]))
    {
        *unit = KSVolumeLiter;
        return key;
    }
    else if ((key = [self hittestForKeystrings: galStringsUS inDictionary: record]))
    {
        *unit = KSVolumeGalUS;
        return key;
    }
    else if ((key = [self hittestForKeystrings: galStringsUK inDictionary: record]))
    {
        *unit = KSVolumeGalUK;
        return key;
    }

    return nil;
}


- (NSString*)keyForVolume: (NSDictionary*)record
{
    static NSString *filledStrings [] =
    {
        @"GETANKT",
        @"AMOUNTFILLED",
        nil
    };

    return [self hittestForKeystrings: filledStrings inDictionary: record];
}


- (NSString*)keyForVolumeUnit: (NSDictionary*)record
{
    static NSString *unitStrings [] =
    {
        @"MASSEINHEIT",
        @"UNIT",
        nil
    };

    return [self hittestForKeystrings: unitStrings inDictionary: record];
}


- (NSString*)keyForPrice: (NSDictionary*)record
{
    static NSString *priceStrings [] =
    {
        @"PRICEPERLITER",
        @"PRICEPERGALLON",
        @"PRICE",
        @"PREISPROLITER",
        @"PREISPROGALLONE",
        @"PREIS",
        nil
    };

    return [self hittestForKeystrings: priceStrings inDictionary: record];
}


- (NSString*)keyForFillup: (NSDictionary*)record
{
    static NSString *fillupStrings [] =
    {
        @"FULLFILLUP",
        @"VOLLGETANKT",
        nil
    };

    return [self hittestForKeystrings: fillupStrings inDictionary: record];
}


- (NSString*)keyForModel: (NSDictionary*)record
{
    static NSString *modelStrings [] =
    {
        @"MODEL",
        @"MODELL",
        nil
    };

    return [self hittestForKeystrings: modelStrings inDictionary: record];
}


- (NSString*)keyForCarID: (NSDictionary*)record
{
    static NSString *idStrings [] =
    {
        @"CARID",
        @"FAHRZEUGID",
        nil
    };

    return [self hittestForKeystrings: idStrings inDictionary: record];
}

@end
