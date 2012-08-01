// CSVParser.m
//
// Kraftstoff


#import "CSVParser.h"


static NSString *separatorStrings [] =
{
    @";",
    @",",
    @"\t",
    nil
};


@interface CSVParser (private)

- (void)setSeparator: (NSString*)separatorString;

- (NSMutableArray*)parseHeader;
- (NSDictionary*)parseRecord;

- (NSString*)parseField;
- (NSString*)parseEscaped;
- (NSString*)parseNonEscaped;
- (NSString*)parseDoubleQuote;
- (NSString*)parseSeparator;
- (NSString*)parseEmptyLines;
- (NSString*)parseLineSeparator;
- (void)skipLine;
- (NSString*)parseTwoDoubleQuotes;
- (NSString*)parseTextData;

@end


@implementation CSVParser


+ (NSString*)simplifiedHeader: (NSString*)header
{
    header = [header stringByReplacingOccurrencesOfString: @":" withString: @""];
    header = [header stringByReplacingOccurrencesOfString: @"?" withString: @""];
    header = [header stringByReplacingOccurrencesOfString: @" " withString: @""];
    header = [header stringByReplacingOccurrencesOfString: @"-" withString: @""];
    header = [header uppercaseString];

    return header;
}


- (id)initWithString: (NSString*)aCSVString
{
    if ((self = [super init]))
    {
        csvString = aCSVString;
        scanner   = [[NSScanner alloc] initWithString: csvString];

        [scanner setCharactersToBeSkipped: nil];
    }

    return self;
}


- (void)setSeparator: (NSString*)separatorString
{
    if (! [separator isEqualToString: separatorString])
    {
        separator = separatorString;

        NSMutableCharacterSet *endTextMutableCharacterSet = [[NSCharacterSet newlineCharacterSet] mutableCopy];
        [endTextMutableCharacterSet addCharactersInString: @"\""];
        [endTextMutableCharacterSet addCharactersInString: [separator substringToIndex:1]];
        endTextCharacterSet = endTextMutableCharacterSet;
    }
}


- (NSInteger)numberOfNonEmtyFieldNames: (NSArray*)array
{
    NSInteger count = [array count];

    for (NSString *name in array)
    {
        if ([name isEqualToString: @""])
            count --;
    }

    return count;
}


- (NSArray*)parseTable
{
    while (! [scanner isAtEnd])
    {
        [self parseEmptyLines];

        NSUInteger location = [scanner scanLocation];
        NSInteger  index    = 0;

        while (separatorStrings [index] != nil)
        {
            [self setSeparator: separatorStrings [index++]];
            [scanner setScanLocation: location];

            fieldNames = [self parseHeader];

            if (fieldNames != nil && [fieldNames count] > 1 && [self parseLineSeparator])
                goto foundHeader;
        }

        [self skipLine];
    }

foundHeader:

    if ([scanner isAtEnd])
        return nil;

    NSMutableArray *records = [NSMutableArray array];

    if ([self numberOfNonEmtyFieldNames: fieldNames] < 2)
        return records;

    NSDictionary *record = [self parseRecord];

    if (!record)
        return records;

    while (record)
    {
        @autoreleasepool
        {
            [records addObject: record];

            if (![self parseLineSeparator])
                break;

            record = [self parseRecord];
        }
    }

    return records;
}


- (NSMutableArray*)parseHeader
{
    NSString *name = [self parseField];

    if (!name)
        return nil;

    NSMutableArray *names = [NSMutableArray array];

    while (name)
    {
        [names addObject: [CSVParser simplifiedHeader: name]];

        if (![self parseSeparator])
            break;

        name = [self parseField];
    }

    return names;
}


- (NSDictionary*)parseRecord
{
    if ([self parseEmptyLines])
        return nil;

    if ([scanner isAtEnd])
        return nil;

    NSString *field = [self parseField];

    if (!field)
        return nil;

    NSInteger fieldNamesCount = [fieldNames count];
    NSInteger fieldCount = 0;

    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity: [fieldNames count]];

    while (field)
    {
        NSString *fieldName;

        if (fieldNamesCount > fieldCount)
        {
            fieldName = [fieldNames objectAtIndex: fieldCount];
        }
        else
        {
            fieldName = [NSString stringWithFormat: @"FIELD_%ld", (long)(fieldCount + 1)];
            [fieldNames addObject: fieldName];
            fieldNamesCount++;
        }

        [record setObject: field forKey: fieldName];
        fieldCount++;

        if (! [self parseSeparator])
            break;

        field = [self parseField];
    }

    return record;
}


- (NSString*)parseField
{
    [scanner scanCharactersFromSet: [NSCharacterSet whitespaceCharacterSet] intoString: NULL];
    
    NSString *escapedString = [self parseEscaped];

    if (escapedString)
        return escapedString;

    NSString *nonEscapedString = [self parseNonEscaped];

    if (nonEscapedString)
        return nonEscapedString;

    NSInteger currentLocation = [scanner scanLocation];

    if ([self parseSeparator] || [self parseLineSeparator] || [scanner isAtEnd])
    {
        [scanner setScanLocation: currentLocation];
        return @"";
    }

    return nil;
}


- (NSString*)parseEscaped
{
    if (! [self parseDoubleQuote])
        return nil;

    NSString *accumulatedData = [NSString string];

    while (YES)
    {
        NSString *fragment = [self parseTextData];

        if (!fragment)
        {
            fragment = [self parseSeparator];

            if (!fragment)
            {
                fragment = [self parseLineSeparator];

                if (!fragment)
                {
                    if ([self parseTwoDoubleQuotes])
                        fragment = @"\"";
                    else
                        break;
                }
            }
        }

        accumulatedData = [accumulatedData stringByAppendingString: fragment];
    }

    if (![self parseDoubleQuote])
        return nil;

    return accumulatedData;
}


- (NSString*)parseNonEscaped
{
    return [self parseTextData];
}


- (NSString*)parseTwoDoubleQuotes
{
    if ([scanner scanString: @"\"\"" intoString: NULL])
        return @"\"\"";
    else
        return nil;
}


- (NSString*)parseDoubleQuote
{
    if ([scanner scanString: @"\"" intoString: NULL])
        return @"\"";
    else
        return nil;
}


- (NSString*)parseSeparator
{
    if ([scanner scanString: separator intoString: NULL])
        return separator;
    else
        return nil;
}


- (NSString*)parseEmptyLines
{
    NSString *matchedNewlines = nil;

    NSUInteger location = [scanner scanLocation];

    [scanner scanCharactersFromSet: [NSCharacterSet whitespaceCharacterSet]
                        intoString: &matchedNewlines];

    if (matchedNewlines == nil)
    {
        [scanner scanCharactersFromSet: [NSCharacterSet characterSetWithCharactersInString: @",;"]
                            intoString: &matchedNewlines];
    }

    if (matchedNewlines == nil)
    {
        matchedNewlines = @"";
    }

    if ([self parseLineSeparator] == nil)
    {
        [scanner setScanLocation: location];
        return nil;
    }

    return matchedNewlines;
}


- (NSString*)parseLineSeparator
{
    if ([scanner scanString: @"\r\n" intoString: NULL])
        return @"\n";

    if ([scanner scanString: @"\n" intoString: NULL])
        return @"\n";

    if ([scanner scanString: @"\r" intoString: NULL])
        return @"\n";
    
    return nil;
}


- (void)skipLine
{
    [scanner scanUpToCharactersFromSet: [NSCharacterSet newlineCharacterSet] intoString: NULL];
    [self parseLineSeparator];
}


- (NSString*)parseTextData
{
    NSString *data = nil;

    [scanner scanUpToCharactersFromSet: endTextCharacterSet intoString: &data];

    return data;
}

@end
