// NSDecimalNumber_extension.m
//
// Kraftstoff


#import "NSDecimalNumber_extension.h"


@implementation NSDecimalNumber (NSDecimalNumber_kraftstoff)

- (NSDecimalNumber*)min: (NSDecimalNumber*)other
{
    if ([self compare: other] != NSOrderedAscending)
        return other;
    else
        return self;
}

- (NSDecimalNumber*)max: (NSDecimalNumber*)other
{
    if ([self compare: other] != NSOrderedDescending)
        return other;
    else
        return self;
}

@end
