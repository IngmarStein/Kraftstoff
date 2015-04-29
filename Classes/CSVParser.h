// CSVParser.h
//
// Kraftstoff

#import <Foundation/Foundation.h>

@interface CSVParser : NSObject

// Simplify CSV header names by stripping special characters and conversion to upper case
+ (NSString *)simplifyCSVHeaderName:(NSString *)header;

// Setup a CSV parser with a given input string
- (instancetype)initWithString:(NSString *)inputCSVString NS_DESIGNATED_INITIALIZER;

// Reset the parser to the beginning of the input string
- (void)revertToBeginning;

// Parse the next CSV-table from the input string
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *parseTable;

@end
