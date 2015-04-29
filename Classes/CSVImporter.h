// CSVImporter.h
//
// Kraftstoff

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface CSVImporter : NSObject

- (BOOL)importFromCSVString:(NSString *)CSVString
               detectedCars:(NSInteger*)numCars
             detectedEvents:(NSInteger*)numEvents
                  sourceURL:(NSURL *)sourceURL
                  inContext:(NSManagedObjectContext *)managedObjectContext;

@end
