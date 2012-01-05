// CSVImporter.h
//
// Kraftstoff


@interface CSVImporter : NSObject
{
    NSMutableSet        *carIDs;
    NSMutableDictionary *nameForID;
    NSMutableDictionary *modelForID;
    NSMutableDictionary *carForID;
}

- (BOOL)importFromCSVString: (NSString*)CSVString
               detectedCars: (NSInteger*)numCars
             detectedEvents: (NSInteger*)numEvents
                  sourceURL: (NSURL*)sourceURL
                  inContext: (NSManagedObjectContext*)managedObjectContext;

@end
