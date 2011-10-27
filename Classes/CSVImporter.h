// CSVImporter.h
//
// Kraftstoff


@interface CSVImporter : NSObject
{
    NSMutableSet        *carIDs;
    NSMutableDictionary *nameForID;
    NSMutableDictionary *modelForID;
}

- (BOOL)importCarIDs:  (NSArray*)records;
- (BOOL)importRecords: (NSArray*)records detectedCars: (NSInteger*)numCars detectedEvents: (NSInteger*)numEvents sourceURL: (NSURL*)sourceURL;

@end
