// NSDecimalNumber+Kraftstoff.m
//
// Kraftstoff


#import "NSDecimalNumber+Kraftstoff.h"


@implementation NSDecimalNumber (Kraftstoff)

- (NSDecimalNumber*)min:(NSDecimalNumber *)other
{
    if (other != nil && [self compare:other] != NSOrderedAscending)
        return other;
    else
        return self;
}

- (NSDecimalNumber*)max:(NSDecimalNumber *)other
{
    if (other != nil && [self compare:other] != NSOrderedDescending)
        return other;
    else
        return self;
}

@end
