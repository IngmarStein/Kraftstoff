// CSVParser.h
//
// Kraftstoff


@interface CSVParser : NSObject
{
	NSString       *csvString;
	NSString       *separator;
	NSScanner      *scanner;

	NSMutableArray *fieldNames;
	NSCharacterSet *endTextCharacterSet;
}

// Simplify CSV header names by stripping special characters and conversion to upper case
+ (NSString*)simplifyCSVHeaderName: (NSString*)header;

// Setup a CSV parser with a given input string
- (id)initWithString: (NSString*)inputCSVString;

// Reset the parser to the beginning of the input string
- (void)revertToBeginning;

// Parse the next CSV-table from the input string
- (NSArray*)parseTable;

@end
