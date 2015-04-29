// DemoData.h
//
// Kraftstoff


#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface DemoData : NSObject

+ (void)addDemoEventsForCar:(NSManagedObject *)car inContext:(NSManagedObjectContext *)context;

@end
