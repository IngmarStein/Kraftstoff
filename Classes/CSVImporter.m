// CSVImporter.m
//
// Kraftstoff


#import "CSVImporter.h"
#import "CSVParser.h"
#import "AppDelegate.h"
#import "TextEditTableCell.h"
#import "kraftstoff-Swift.h"



@implementation CSVImporter
{
    NSMutableSet        *carIDs;
    NSMutableDictionary *carForID;
    NSMutableDictionary *modelForID;
    NSMutableDictionary *plateForID;
}


- (instancetype)init
{
    if ((self = [super init]))
    {
        carIDs     = [NSMutableSet setWithCapacity:7];
        carForID   = [NSMutableDictionary dictionaryWithCapacity:7];
        modelForID = [NSMutableDictionary dictionaryWithCapacity:7];
        plateForID = [NSMutableDictionary dictionaryWithCapacity:7];
    }

    return self;
}



#pragma mark -
#pragma mark Core Data Support



- (NSManagedObject *)addCarWithName:(NSString *)name
                             order:(NSInteger)order
                             plate:(NSString *)plate
                      odometerUnit:(KSDistance)odometerUnit
                        volumeUnit:(KSVolume)volumeUnit
               fuelConsumptionUnit:(KSFuelConsumption)fuelConsumptionUnit
                         inContext:(NSManagedObjectContext *)managedObjectContext
{
    // Create and configure new car object
    NSManagedObject *newCar = [NSEntityDescription insertNewObjectForEntityForName:@"car"
                                                            inManagedObjectContext:managedObjectContext];

    [newCar setValue:@(order)                    forKey:@"order"];
    [newCar setValue:[NSDate date]               forKey:@"timestamp"];
    [newCar setValue:name                        forKey:@"Name"];
    [newCar setValue:plate                       forKey:@"numberPlate"];
    [newCar setValue:@((int)odometerUnit)        forKey:@"odometerUnit"];
    [newCar setValue:[NSDecimalNumber zero]      forKey:@"odometer"];
    [newCar setValue:@((int)volumeUnit)          forKey:@"fuelUnit"];
    [newCar setValue:@((int)fuelConsumptionUnit) forKey:@"fuelConsumptionUnit"];

    return newCar;
}


- (NSManagedObject *)addEventForCar:(NSManagedObject *)car
                              date:(NSDate *)date
                          distance:(NSDecimalNumber *)distance
                             price:(NSDecimalNumber *)price
                        fuelVolume:(NSDecimalNumber *)fuelVolume
                     inheritedCost:(NSDecimalNumber *)inheritedCost
                 inheritedDistance:(NSDecimalNumber *)inheritedDistance
               inheritedFuelVolume:(NSDecimalNumber *)inheritedFuelVolume
                          filledUp:(BOOL)filledUp
                         inContext:(NSManagedObjectContext *)managedObjectContext
{
    NSManagedObject *newEvent = [NSEntityDescription insertNewObjectForEntityForName:@"fuelEvent"
                                                              inManagedObjectContext:managedObjectContext];

    [newEvent setValue:car        forKey:@"car"];
    [newEvent setValue:date       forKey:@"timestamp"];
    [newEvent setValue:distance   forKey:@"distance"];
    [newEvent setValue:price      forKey:@"price"];
    [newEvent setValue:fuelVolume forKey:@"fuelVolume"];

    if (filledUp == NO)
        [newEvent setValue:@(filledUp) forKey:@"filledUp"];

    NSDecimalNumber *zero = [NSDecimalNumber zero];

    if ([inheritedCost isEqualToNumber:zero] == NO)
        [newEvent setValue:inheritedCost forKey:@"inheritedCost"];

    if ([inheritedDistance isEqualToNumber:zero] == NO)
        [newEvent setValue:inheritedDistance forKey:@"inheritedDistance"];

    if ([inheritedFuelVolume isEqualToNumber:zero] == NO)
        [newEvent setValue:inheritedFuelVolume forKey:@"inheritedFuelVolume"];

    [car setValue:[[car valueForKey:@"distanceTotalSum"]   decimalNumberByAdding:distance]   forKey:@"distanceTotalSum"];
    [car setValue:[[car valueForKey:@"fuelVolumeTotalSum"] decimalNumberByAdding:fuelVolume] forKey:@"fuelVolumeTotalSum"];

    return newEvent;
}



#pragma mark -
#pragma mark Data Import Helpers



- (NSString *)guessModelFromURL:(NSURL *) sourceURL
{
    if ([sourceURL isFileURL])
    {
        NSArray *nameComponents = [[[[sourceURL path] lastPathComponent] stringByDeletingPathExtension] componentsSeparatedByString:@"__"];

        // CSV file exported in new format: model is first part of filename
        if ([nameComponents count] == 2)
        {
            NSString *part = nameComponents[0];

            if ([part length] > 0)
            {
                if ([part length] > maximumTextFieldLength)
                    part = [part substringToIndex:maximumTextFieldLength];

                return part;
            }
        }
    }

    return nil;
}


- (NSString *)guessPlateFromURL:(NSURL *) sourceURL
{
    if ([sourceURL isFileURL])
    {
        NSArray *nameComponents = [[[[sourceURL path] lastPathComponent] stringByDeletingPathExtension] componentsSeparatedByString:@"__"];

        // CSV file in new format: plate is second part of filename
        //     for unknown format: use the whole filename if it is a single component
        if (nameComponents.count <= 2)
        {
            NSString *part = [nameComponents lastObject];

            if ([part length] > 0)
            {
                if ([part length] > maximumTextFieldLength)
                    part = [part substringToIndex:maximumTextFieldLength];

                return part;
            }
        }
    }

    return nil;
}


- (BOOL)importCarIDs:(NSArray *)records
{
    NSDictionary *first = records[0];

    if ([first count] < 3)
        return NO;

    if (first[@"ID"] == nil)
        return NO;

    NSString *modelKey = [self keyForModel:first];

    if (modelKey == nil)
        return NO;

    if (first[@"NAME"] == nil)
        return NO;

    NSInteger previousCarIDCount = carIDs.count;

    for (NSDictionary *record in records)
    {
        NSNumber *ID = [self scanNumberWithString:record[@"ID"]];

        if (ID != nil && [carIDs containsObject:ID] == NO)
        {
            NSString *model = record[modelKey];
            NSString *plate = record[@"NAME"];

            if (model != nil && plate != nil)
            {
                [carIDs addObject:ID];
                modelForID[ID] = model;
                plateForID[ID] = plate;
            }
        }
    }

    return ([carIDs count] > previousCarIDCount);
}


- (NSInteger)createCarObjectsInContext:(NSManagedObjectContext *)managedObjectContext
{
    // Fetch already existing cars for later update of order attribute
    NSFetchRequest *carRequest = [AppDelegate fetchRequestForCarsInManagedObjectContext:managedObjectContext];
    NSArray *fetchedCarObjects = [AppDelegate objectsForFetchRequest:carRequest
                                              inManagedObjectContext:managedObjectContext];


    // Create car objects
    [carForID removeAllObjects];

    for (NSNumber *carID in carIDs)
    {
        NSString *model = modelForID[carID];

        if (model == nil)
            model = [NSString stringWithFormat:@"%@", NSLocalizedString(@"Imported Car", @"")];

        if ([model length] > maximumTextFieldLength)
            model = [model substringToIndex:maximumTextFieldLength];


        NSString *plate = plateForID[carID];

        if (plate == nil)
            plate = @"";

        if ([plate length] > maximumTextFieldLength)
            plate = [plate substringToIndex:maximumTextFieldLength];


        NSManagedObject *newCar = [self addCarWithName:model
                                                 order:[carForID count]
                                                 plate:plate
                                          odometerUnit:[AppDelegate distanceUnitFromLocale]
                                            volumeUnit:[AppDelegate volumeUnitFromLocale]
                                   fuelConsumptionUnit:[AppDelegate fuelConsumptionUnitFromLocale]
                                             inContext:managedObjectContext];

        carForID[carID] = newCar;
    }


    // Now update order attribute of old car objects
    for (NSManagedObject *oldCar in fetchedCarObjects)
    {
        NSInteger order = [[oldCar valueForKey:@"order"] integerValue];
        [oldCar setValue:@(order+[carForID count]) forKey:@"order"];
    }

    return [carForID count];
}



- (NSDecimalNumber *)guessDistanceForParsedDistance:(NSDecimalNumber *)distance
                                     andFuelVolume:(NSDecimalNumber *)liters
{
    NSDecimalNumber *convDistance = [distance decimalNumberByMultiplyingByPowerOf10:3];
    
    
    if ([[NSDecimalNumber zero] compare:liters] != NSOrderedAscending)
        return distance;
    
    // consumption with parsed distance
    NSDecimalNumber *rawConsumption  = [AppDelegate consumptionForKilometers:distance
                                                                      Liters:liters
                                                                      inUnit:KSFuelConsumptionLitersPer100km];
    
    if ([rawConsumption isEqual:[NSDecimalNumber notANumber]])
        return distance;
    
    // consumption with increased distance
    NSDecimalNumber *convConsumption = [AppDelegate consumptionForKilometers:convDistance
                                                                      Liters:liters
                                                                      inUnit:KSFuelConsumptionLitersPer100km];
    
    if ([convConsumption isEqual:[NSDecimalNumber notANumber]])
        return distance;
    
    // consistency checks
    NSDecimalNumber *loBound = [NSDecimalNumber decimalNumberWithMantissa:  2 exponent:0 isNegative:NO];
    NSDecimalNumber *hiBound = [NSDecimalNumber decimalNumberWithMantissa:20 exponent:0 isNegative:NO];
    
    // conversion only when unconverted >= lowerBound
    if ([rawConsumption compare:hiBound] == NSOrderedAscending)
        return distance;
    
    // conversion only when lowerBound <= convConversion <= highBound
    if ([convConsumption compare:loBound] == NSOrderedAscending || [convConsumption compare:hiBound] == NSOrderedDescending)
        return distance;
    
    // converted distance is more logical
    return convDistance;
}



- (BOOL)importRecords:(NSArray *)records
      formatIsTankPro:(BOOL)isTankProImport
       detectedEvents:(NSInteger*)numEvents
            inContext:(NSManagedObjectContext *)managedObjectContext
{
    // Analyse record headers
    NSDictionary *first = records[0];

    KSDistance distanceUnit = KSDistanceInvalid;
    KSDistance odometerUnit = KSDistanceInvalid;
    KSVolume   volumeUnit   = KSVolumeInvalid;

    NSString *IDKey           = [self keyForCarID:first];
    NSString *dateKey         = [self keyForDate:first];
    NSString *timeKey         = [self keyForTime:first];
    NSString *distanceKey     = [self keyForDistance:first unit:&distanceUnit];
    NSString *odometerKey     = [self keyForOdometer:first unit:&odometerUnit];
    NSString *volumeKey       = [self keyForVolume:first unit:&volumeUnit];
    NSString *volumeAmountKey = [self keyForVolume:first];
    NSString *volumeUnitKey   = [self keyForVolumeUnit:first];
    NSString *priceKey        = [self keyForPrice:first];
    NSString *fillupKey       = [self keyForFillup:first];


    // Common consistency check for CSV headers
    if (dateKey == nil
        || (odometerKey == nil && distanceKey == nil)
        || (volumeKey == nil && (volumeAmountKey == nil || volumeUnitKey == nil))
        || priceKey == nil)
        return NO;


    // Additional consistency check for CSV headers on import from TankPro
    if (isTankProImport)
        if (IDKey == nil || distanceKey != nil || odometerKey == nil || volumeKey != nil || volumeUnitKey == nil || fillupKey == nil)
            return NO;


    // Sort records according time and odometer
    NSMutableArray *sortedRecords = [NSMutableArray arrayWithCapacity:[records count]];

    [sortedRecords addObjectsFromArray:records];
    [sortedRecords sortUsingComparator:
        ^NSComparisonResult (id obj1, id obj2)
        {
            NSComparisonResult cmpResult = NSOrderedSame;

            NSDate *date1 = [self scanDate:obj1[dateKey] withOptionalTime:obj1[timeKey]];
            NSDate *date2 = [self scanDate:obj2[dateKey] withOptionalTime:obj2[timeKey]];

            if (date1 != nil && date2 != nil)
            {
                cmpResult = [date1 compare:date2];
            }

            if (cmpResult == NSOrderedSame && odometerKey != nil)
            {
                NSNumber *odometer1 = [self scanNumberWithString:obj1[odometerKey]];
                NSNumber *odometer2 = [self scanNumberWithString:obj2[odometerKey]];

                if (odometer1 != nil && odometer2 != nil)
                    cmpResult = [odometer1 compare:odometer2];
            }

            return cmpResult;
        }];


    // For all cars...
    for (NSNumber *carID in carIDs)
    {
        NSManagedObject *car = carForID[carID];


        NSDate *lastDate         = [NSDate distantPast];
        NSTimeInterval lastDelta = 0.0;
        BOOL detectedEvents      = NO;
        BOOL initialFillUpSeen   = NO;

        NSDecimalNumber *zero                = [NSDecimalNumber zero];
        NSDecimalNumber *odometer            = zero;
        NSDecimalNumber *inheritedCost       = zero;
        NSDecimalNumber *inheritedDistance   = zero;
        NSDecimalNumber *inheritedFuelVolume = zero;


        // For all records...
        for (NSDictionary *record in sortedRecords)
        {
            // Match car IDs when importing from Tank Pro
            if (isTankProImport)
                if ([carID isEqualToNumber:[self scanNumberWithString:record[IDKey]]] == NO)
                    continue;

            NSDate *date         = [self scanDate:record[dateKey] withOptionalTime:record[timeKey]];
            NSTimeInterval delta = [date timeIntervalSinceDate:lastDate];

            if (delta <= 0.0 || lastDelta > 0.0)
            {
                lastDelta = (delta > 0.0) ? 0.0 : ceilf (fabs (delta) + 60.0);
                date      = [date dateByAddingTimeInterval:lastDelta];
            }

            if ([date timeIntervalSinceDate:lastDate] <= 0.0)
                continue;


            NSDecimalNumber *distance = nil;

            if (distanceKey != nil)
            {
                distance = [self scanNumberWithString:record[distanceKey]];

                if (distance)
                    distance = [AppDelegate kilometersForDistance:distance withUnit:distanceUnit];
            }
            else
            {
                NSDecimalNumber *newOdometer = [self scanNumberWithString:record[odometerKey]];

                if (newOdometer)
                {
                    newOdometer = [AppDelegate kilometersForDistance:newOdometer withUnit:odometerUnit];
                    distance    = [newOdometer decimalNumberBySubtracting:odometer];
                    odometer    = newOdometer;
                }
            }


            NSDecimalNumber *volume = nil;

            if (volumeUnit != KSVolumeInvalid)
            {
                volume = [self scanNumberWithString:record[volumeKey]];

                if (volume)
                    volume = [AppDelegate litersForVolume:volume withUnit:volumeUnit];
            }
            else
            {
                volume = [self scanNumberWithString:record[volumeAmountKey]];

                if (volume)
                    volume = [AppDelegate litersForVolume:volume withUnit:[self scanVolumeUnitWithString:record[volumeUnitKey]]];
            }


            NSDecimalNumber *price = [self scanNumberWithString:record[priceKey]];

            if (isTankProImport)
            {
                // TankPro stores total costs not the price per unit...
                if (volume == nil || [volume isEqualToNumber:[NSDecimalNumber zero]])
                    price = [NSDecimalNumber zero];
                else
                    price = [price decimalNumberByDividingBy:volume
                                                withBehavior:[AppDelegate sharedPriceRoundingHandler]];
            }
            else if (price)
            {
                if (volumeUnit != KSVolumeInvalid)
                    price = [AppDelegate pricePerLiter:price withUnit:volumeUnit];
                else
                    price = [AppDelegate pricePerLiter:price withUnit:[self scanVolumeUnitWithString:record[volumeUnitKey]]];
            }


            BOOL filledUp = [self scanBooleanWithString:record[fillupKey]];


            // For TankPro ignore events until after the first full fill-up
            if (isTankProImport && initialFillUpSeen == NO)
            {
                initialFillUpSeen = filledUp;
                continue;
            }


            // Consistency check and import
            if ([distance compare:zero] == NSOrderedDescending && [volume compare:zero] == NSOrderedDescending)
            {
                distance = [self guessDistanceForParsedDistance:distance andFuelVolume:volume];
                
                // Add event for car
                [self addEventForCar:car
                                date:date
                            distance:distance
                               price:price
                          fuelVolume:volume
                       inheritedCost:inheritedCost
                   inheritedDistance:inheritedDistance
                 inheritedFuelVolume:inheritedFuelVolume
                            filledUp:filledUp
                           inContext:managedObjectContext];

                if (filledUp)
                {
                    inheritedCost       = zero;
                    inheritedDistance   = zero;
                    inheritedFuelVolume = zero;
                }
                else
                {
                    inheritedCost       = [inheritedCost       decimalNumberByAdding:[volume decimalNumberByMultiplyingBy:price]];
                    inheritedDistance   = [inheritedDistance   decimalNumberByAdding:distance];
                    inheritedFuelVolume = [inheritedFuelVolume decimalNumberByAdding:volume];
                }

                *numEvents     = *numEvents + 1;
                detectedEvents = YES;
                lastDate       = date;
            }
        }

        // Fixup car odometer
        if (detectedEvents)
            [car setValue:[odometer max:[car valueForKey:@"distanceTotalSum"]] forKey:@"odometer"];
    }

    return YES;
}



#pragma mark -
#pragma mark Data Import



- (BOOL)importFromCSVString:(NSString *)CSVString
               detectedCars:(NSInteger*)numCars
             detectedEvents:(NSInteger*)numEvents
                  sourceURL:(NSURL *)sourceURL
                  inContext:(NSManagedObjectContext *)managedObjectContext
{
    CSVParser *parser = [[CSVParser alloc] initWithString:CSVString];


    // Check for TankPro import:search for tables containing car definitions
    BOOL importFromTankPro = YES;

    while (YES) {
        NSArray *CSVTable = [parser parseTable];

        if (CSVTable == nil)
            break;

        if (CSVTable.count == 0)
            continue;

        [self importCarIDs:CSVTable];
    }


    // Not a TankPro import:create a dummy car definition
    if ([carIDs count] == 0) {
        id dummyID = [NSNull null];

        [carIDs addObject:dummyID];
        [modelForID setValue:[self guessModelFromURL:sourceURL] forKey:dummyID];
        [plateForID setValue:[self guessPlateFromURL:sourceURL] forKey:dummyID];

        importFromTankPro = NO;
    }


    // Create objects for detected cars
    *numCars = [self createCarObjectsInContext:managedObjectContext];

    if (*numCars == 0)
        return NO;

    // Search for tables containing data records
    [parser revertToBeginning];

    *numEvents = 0;

    while (YES) {
        NSArray *CSVTable = [parser parseTable];

        if (CSVTable == nil)
            break;

        if ([CSVTable count] == 0)
            continue;

        [self importRecords:CSVTable
            formatIsTankPro:importFromTankPro
             detectedEvents:numEvents
                  inContext:managedObjectContext];
    }

    return (*numEvents > 0);
}



#pragma mark -
#pragma mark Scanning Support



- (NSDecimalNumber *)scanNumberWithString:(NSString *)string
{
    if (string == nil)
        return nil;

    // Scan via NSScanner (fast, strict)
    NSScanner *scanner = [NSScanner scannerWithString:string];
    NSDecimal d;

    [scanner setLocale:[NSLocale currentLocale]];
    [scanner setScanLocation:0];

    if ([scanner scanDecimal:&d] && [scanner isAtEnd])
        return [NSDecimalNumber decimalNumberWithDecimal:d];

    [scanner setLocale:[NSLocale systemLocale]];
    [scanner setScanLocation:0];

    if ([scanner scanDecimal:&d] && [scanner isAtEnd])
        return [NSDecimalNumber decimalNumberWithDecimal:d];


    // Scan with localized numberformatter (sloppy, catches grouping separators)
    static NSNumberFormatter *nf_system  = nil;
    static NSNumberFormatter *nf_current = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        nf_current = [[NSNumberFormatter alloc] init];

        [nf_current setGeneratesDecimalNumbers:YES];
        [nf_current setUsesGroupingSeparator:YES];
        [nf_current setNumberStyle:NSNumberFormatterDecimalStyle];
        [nf_current setLenient:YES];
        [nf_current setLocale:[NSLocale currentLocale]];

        nf_system = [[NSNumberFormatter alloc] init];

        [nf_system setGeneratesDecimalNumbers:YES];
        [nf_system setUsesGroupingSeparator:YES];
        [nf_system setNumberStyle:NSNumberFormatterDecimalStyle];
        [nf_system setLenient:YES];
        [nf_system setLocale:[NSLocale systemLocale]];
    });

    NSNumber *dn;

    if ((dn = [nf_current numberFromString:string]))
        return (NSDecimalNumber *)dn;

    if ((dn = [nf_system numberFromString:string]))
        return (NSDecimalNumber *)dn;

    return nil;
}


- (NSDate *)scanDate:(NSString *)dateString withOptionalTime:(NSString *)timeString
{
    NSDate *date = [self scanDateWithString:dateString];
    NSDate *time = nil;

    if (date == nil)
        return nil;

    if (timeString != nil)
        time = [self scanTimeWithString:timeString];
    
    if (time != nil)
        return [date dateByAddingTimeInterval:[NSDate timeIntervalSinceBeginningOfDay:time]];
    else
        return [date dateByAddingTimeInterval:43200];
}


- (NSDate *)scanDateWithString:(NSString *)string
{
    static NSDateFormatter *df_system  = nil;
    static NSDateFormatter *df_current = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        df_system = [[NSDateFormatter alloc] init];
        [df_system setLocale:[NSLocale systemLocale]];
        [df_system setDateFormat:@"yyyy-MM-dd"];
        [df_system setLenient:NO];

        df_current = [[NSDateFormatter alloc] init];
        [df_current setLocale:[NSLocale currentLocale]];
        [df_current setDateStyle:NSDateFormatterShortStyle];
        [df_current setTimeStyle:NSDateFormatterNoStyle];
        [df_current setLenient:YES];

    });

    NSDate *d;

    if (string == nil)
        return nil;

    // Strictly scan own format in system locale
    if ((d = [df_system dateFromString:string]))
        return d;

    // Alternatively scan date in short local style
    if ((d = [df_current dateFromString:string]))
        return d;

    return nil;
}


- (NSDate *)scanTimeWithString:(NSString *)string
{
    static NSDateFormatter *df_system  = nil;
    static NSDateFormatter *df_current = nil;
    static dispatch_once_t pred;

    dispatch_once (&pred, ^{

        df_system = [[NSDateFormatter alloc] init];
        [df_system setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        [df_system setLocale:[NSLocale systemLocale]];
        [df_system setDateFormat:@"HH:mm"];
        [df_system setLenient:NO];

        df_current = [[NSDateFormatter alloc] init];
        [df_current setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        [df_current setLocale:[NSLocale currentLocale]];
        [df_current setTimeStyle:NSDateFormatterShortStyle];
        [df_current setDateStyle:NSDateFormatterNoStyle];
        [df_current setLenient:YES];

    });

    NSDate *d;

    if (string == nil)
        return nil;

    // Strictly scan own format in system locale
    if ((d = [df_system dateFromString:string]))
        return d;

    // Alternatively scan date in short local style
    if ((d = [df_current dateFromString:string]))
        return d;

    return nil;
}


- (BOOL)scanBooleanWithString:(NSString *)string
{
    if (string == nil)
        return YES;

    NSNumber *n = [self scanNumberWithString:string];

    if (n != nil) {
        return ([n integerValue] != 0);
    } else {
        string = [string uppercaseString];
        return (![string isEqualToString:@"NO"] && ![string isEqualToString:@"NEIN"]);
    }
}


- (KSVolume)scanVolumeUnitWithString:(NSString *)string
{
    if (string == nil)
        return KSVolumeLiter;

    string = [CSVParser simplifyCSVHeaderName:string];


    // Catch Tank Pro exports
    if ([string isEqualToString:@"L"])
        return KSVolumeLiter;

    if ([string isEqualToString:@"G"]) {
        // TankPro seems to export both gallons simply as "G" => search locale for feasible guess
        if ([AppDelegate volumeUnitFromLocale] == KSVolumeGalUS)
            return KSVolumeGalUS;
        else
            return KSVolumeGalUK;
    }


    // Catch some other forms of gallons
    NSRange range = [string rangeOfString:@"GAL"];

    if (range.location != NSNotFound) {
        range = [string rangeOfString:@"US"];

        if (range.location != NSNotFound)
            return KSVolumeGalUS;

        range = [string rangeOfString:@"UK"];

        if (range.location != NSNotFound)
            return KSVolumeGalUK;

        if ([AppDelegate volumeUnitFromLocale] == KSVolumeGalUS)
            return KSVolumeGalUS;
        else
            return KSVolumeGalUK;
    }


    // Liters as default
    return KSVolumeLiter;
}



#pragma mark -
#pragma mark Interpretation of CSV Header Names



- (NSString *)keyForDate:(NSDictionary *)record
{
    for (NSString *key in @[ @"JJJJMMTT", @"YYYYMMDD", @"DATE", @"DATUM" ])
        if (record[key])
            return key;

    return nil;
}


- (NSString *)keyForTime:(NSDictionary *)record
{
    for (NSString *key in @[ @"HHMM", @"TIME", @"ZEIT" ])
        if (record[key])
            return key;

    return nil;
}


- (NSString *)keyForDistance:(NSDictionary *)record unit:(KSDistance*)unit
{
    for (NSString *key in @[ @"KILOMETERS", @"KILOMETER", @"STRECKE" ])
        if (record[key]) {
            *unit = KSDistanceKilometer;
            return key;
        }

    for (NSString *key in @[ @"MILES", @"MEILEN" ])
        if (record[key]) {
            *unit = KSDistanceStatuteMile;
            return key;
        }

    return nil;
}


- (NSString *)keyForOdometer:(NSDictionary *)record unit:(KSDistance*)unit
{
    for (NSString *key in @[ @"ODOMETER(KM)", @"KILOMETERSTAND(KM)" ])
        if (record[key]) {
            *unit = KSDistanceKilometer;
            return key;
        }

    for (NSString *key in @[ @"ODOMETER(MI)", @"KILOMETERSTAND(MI)" ])
        if (record[key]) {
            *unit = KSDistanceStatuteMile;
            return key;
        }

    return nil;
}


- (NSString *)keyForVolume:(NSDictionary *)record unit:(KSVolume*)unit;
{
    for (NSString *key in @[ @"LITERS", @"LITER", @"TANKMENGE" ])
        if (record[key]) {
            *unit = KSVolumeLiter;
            return key;
        }

    for (NSString *key in @[ @"GALLONS(US)", @"GALLONEN(US)" ])
        if (record[key]) {
            *unit = KSVolumeGalUS;
            return key;
        }

    for (NSString *key in @[ @"GALLONS(UK)", @"GALLONEN(UK)" ])
        if (record[key]) {
            *unit = KSVolumeGalUK;
            return key;
        }

    return nil;
}


- (NSString *)keyForVolume:(NSDictionary *)record
{
    for (NSString *key in @[ @"GETANKT", @"AMOUNTFILLED" ])
        if (record[key])
            return key;

    return nil;
}


- (NSString *)keyForVolumeUnit:(NSDictionary *)record
{
    // 'MAFLEINHEIT' happens when Windows encoding is misinterpreted as MacRoman...
    for (NSString *key in @[ @"MASSEINHEIT", @"UNIT", @"MAFLEINHEIT" ])
        if (record[key])
            return key;

    return nil;
}


- (NSString *)keyForPrice:(NSDictionary *)record
{
    for (NSString *key in @[ @"PRICEPERLITER", @"PRICEPERGALLON", @"PRICE", @"PREISPROLITER", @"PREISPROGALLONE", @"PREIS", @"KOSTEN/LITER" ])
        if (record[key])
            return key;

    return nil;
}


- (NSString *)keyForFillup:(NSDictionary *)record
{
    for (NSString *key in @[ @"FULLFILLUP", @"VOLLGETANKT" ])
        if (record[key])
            return key;

    return nil;
}


- (NSString *)keyForModel:(NSDictionary *)record
{
    for (NSString *key in @[ @"MODEL", @"MODELL" ])
        if (record[key])
            return key;

    return nil;
}


- (NSString *)keyForCarID:(NSDictionary *)record
{
    for (NSString *key in @[ @"CARID", @"FAHRZEUGID" ])
        if (record[key])
            return key;

    return nil;
}

@end
