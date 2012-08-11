// DemoData.m
//
// Kraftstoff


#import "DemoData.h"


typedef struct
{
    char const *date;

    int distance;       // *10^-1
    int fuelVolume;     // *10^-2
    int price;          // *10^-3

} demoData_t;

static demoData_t demoData [] =
{
    { "2009-09-25 12:00:GMT+0200", 1900,  760, 1079 },
    { "2009-10-10 12:00:GMT+0200", 5810, 2488, 1079 },
    { "2009-10-22 12:00:GMT+0200", 5740, 2494, 1119 },
    { "2009-11-05 12:00:GMT+0100", 6010, 2753, 1119 },
    { "2009-11-18 12:00:GMT+0100", 5790, 2754, 1079 },
    { "2009-12-05 12:00:GMT+0100", 6750, 3000, 1099 },
    { "2009-12-19 12:00:GMT+0100", 5460, 2592, 1099 },
    { "2010-01-06 12:00:GMT+0100", 5310, 2625, 1159 },
    { "2010-01-20 12:00:GMT+0100", 5570, 2740, 1119 },
    { "2010-02-04 12:00:GMT+0100", 5300, 2702, 1159 },

    { "2010-02-18 12:00:GMT+0100", 5910, 2689, 1179 },
    { "2010-03-02 12:00:GMT+0100", 5660, 2560, 1159 },
    { "2010-03-16 12:00:GMT+0100", 6220, 2992, 1229 },
    { "2010-03-26 12:00:GMT+0100", 6330, 2771, 1219 },
    { "2010-04-11 12:00:GMT+0200", 5600, 2502, 1189 },
    { "2010-04-25 12:00:GMT+0200", 5530, 2369, 1269 },
    { "2010-05-07 12:00:GMT+0200", 5520, 2561, 1229 },
    { "2010-05-21 12:00:GMT+0200", 6010, 2495, 1219 },
    { "2010-06-10 12:00:GMT+0200", 6330, 2711, 1269 },
    { "2010-06-24 12:00:GMT+0200", 6080, 2642, 1269 },

    { "2010-07-08 12:00:GMT+0200", 6070, 2731, 1229 },
    { "2010-07-21 12:00:GMT+0200", 6130, 2629, 1239 },
    { "2010-08-03 12:00:GMT+0200", 6220, 2782, 1199 },
    { "2010-08-14 12:00:GMT+0200", 6070, 2735, 1199 },
    { "2010-08-30 12:00:GMT+0200", 6210, 2608, 1199 },
    { "2010-09-10 12:00:GMT+0200", 6220, 2596, 1229 },
    { "2010-09-25 12:00:GMT+0200", 6440, 2783, 1179 },
    { "2010-10-08 12:00:GMT+0200", 6790, 2886, 1249 },
    { "2010-10-18 12:00:GMT+0200", 4580, 2034, 1179 },
    { "2010-10-27 08:56:GMT+0200", 5440, 2570, 1219 },

    { "2010-11-08 08:49:GMT+0100", 5410, 2496, 1199 },
    { "2010-11-19 08:43:GMT+0100", 5480, 2583, 1269 },
    { "2010-12-02 08:47:GMT+0100", 5400, 2731, 1199 },
    { "2010-12-14 08:46:GMT+0100", 5000, 2434, 1269 },
    { "2010-12-28 18:47:GMT+0100", 5000, 2410, 1279 },
    { "2011-01-10 17:58:GMT+0100", 5320, 2672, 1319 },
    { "2011-01-22 21:35:GMT+0100", 5470, 2641, 1369 },
    { "2011-02-11 08:30:GMT+0100", 7473, 3786, 1369 },
    { "2011-02-23 08:44:GMT+0100", 5440, 2614, 1399 },
    { "2011-03-08 08:44:GMT+0100", 5220, 2524, 1459 },

    { "2011-03-22 08:36:GMT+0100", 5810, 2471, 1429 },
    { "2011-04-06 08:29:GMT+0100", 5950, 2682, 1459 },
    { "2011-04-19 08:43:GMT+0100", 6360, 2837, 1449 },
    { "2011-05-07 20:20:GMT+0100", 6260, 2770, 1359 },
    { "2011-05-21 20:20:GMT+0100", 6007, 2559, 1379 },
    { "2011-06-06 08:25:GMT+0100", 6190, 2717, 1369 },
    { "2011-06-18 17:21:GMT+0100", 5976, 2596, 1399 },
    { "2011-07-06 08:34:GMT+0100", 6121, 2748, 1399 },
    { "2011-07-19 22:04:GMT+0100", 6375, 2722, 1389 },
    { "2011-08-03 17:52:GMT+0100", 6442, 2839, 1369 },

    { "2011-08-17 18:56:GMT+0100", 6126, 2838, 1349 },
    { "2011-08-31 17:53:GMT+0100", 6063, 2644, 1359 },
    { "2011-09-16 08:21:GMT+0200", 6570, 2728, 1459 },
    { "2011-09-30 08:31:GMT+0200", 5913, 2586, 1419 },
    { "2011-10-13 08:08:GMT+0200", 5871, 2464, 1439 },
    { "2011-10-27 08:24:GMT+0200", 5872, 2528, 1469 },
    { "2011-11-12 19:43:GMT+0100", 5770, 2651, 1439 },
    { "2011-11-28 08:48:GMT+0100", 5811, 2749, 1419 },
    { "2011-12-12 08:23:GMT+0100", 5520, 2659, 1469 },
    { "2011-12-17 12:06:GMT+0100", 5031, 2473, 1359 },

    { "2012-01-06 08:38:GMT+0100", 5584, 2446, 1449 },
    { "2012-01-18 08:29:GMT+0100", 5310, 2500, 1469 },
    { "2012-02-02 08:31:GMT+0100", 5686, 2700, 1439 },
    { "2012-02-14 18:34:GMT+0100", 4669, 2358, 1439 },
    { "2012-02-24 08:23:GMT+0100", 5370, 2620, 1499 },
    { "2012-03-09 20:06:GMT+0100", 5370, 2517, 1479 },
    { "2012-03-22 17:59:GMT+0100", 5790, 2597, 1489 },
    { "2012-04-04 18:21:GMT+0200", 5390, 2350, 1489 },
    { "2012-04-17 20:51:GMT+0200", 5820, 2469, 1479 },
    { "2012-05-02 19:25:GMT+0200", 5810, 2573, 1439 },

    { "2012-05-18 18:35:GMT+0200", 6460, 2655, 1389 },
    { "2012-06-03 16:04:GMT+0200", 6261, 2441, 1379 },
    { "2012-06-20 18:27:GMT+0200", 6370, 2727, 1349 },
};

#define DEMO_DATA_CNT ((int)(sizeof (demoData) / sizeof (demoData [0])))


@implementation DemoData

+ (void)addDemoEventsForCar: (NSManagedObject*)car inContext: (NSManagedObjectContext*)context
{
    NSDateFormatter *df = [[NSDateFormatter alloc] init];

    [df setLocale: [NSLocale systemLocale]];
    [df setDateFormat: @"yyyy-MM-dd HH:mm:Z"];

    @autoreleasepool
    {
        for (int i = 0; i < DEMO_DATA_CNT; i++)
        {
            NSManagedObject *newEvent = [NSEntityDescription insertNewObjectForEntityForName: @"fuelEvent" inManagedObjectContext: context];

            NSDecimalNumber *distance   = [NSDecimalNumber decimalNumberWithMantissa: demoData [i].distance   exponent: -1 isNegative: NO];
            NSDecimalNumber *fuelVolume = [NSDecimalNumber decimalNumberWithMantissa: demoData [i].fuelVolume exponent: -2 isNegative: NO];
            NSDecimalNumber *price      = [NSDecimalNumber decimalNumberWithMantissa: demoData [i].price      exponent: -3 isNegative: NO];

            [newEvent setValue: [df dateFromString: @(demoData [i].date)] forKey: @"timestamp"];

            [newEvent setValue: car        forKey: @"car"];
            [newEvent setValue: distance   forKey: @"distance"];
            [newEvent setValue: price      forKey: @"price"];
            [newEvent setValue: fuelVolume forKey: @"fuelVolume"];

            [car setValue: [[car valueForKey: @"distanceTotalSum"]   decimalNumberByAdding: distance]   forKey: @"distanceTotalSum"];
            [car setValue: [[car valueForKey: @"fuelVolumeTotalSum"] decimalNumberByAdding: fuelVolume] forKey: @"fuelVolumeTotalSum"];
        }

        [car setValue: [car valueForKey: @"distanceTotalSum"] forKey: @"odometer"];
    }
}

@end
