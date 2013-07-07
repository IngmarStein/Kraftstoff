// CSVImporter.h
//
// Kraftstoff


@interface CSVImporter : NSObject

- (BOOL)importFromCSVString:(NSString *)CSVString
               detectedCars:(NSInteger*)numCars
             detectedEvents:(NSInteger*)numEvents
                  sourceURL:(NSURL *)sourceURL
                  inContext:(NSManagedObjectContext *)managedObjectContext;

@end
