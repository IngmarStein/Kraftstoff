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

- (id)initWithString: (NSString*)aCSVString;
- (NSArray*)parseTable;

+ (NSString*)simplifiedHeader: (NSString*)header;

@end
