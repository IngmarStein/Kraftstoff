// NSDecimalNumber_extension.m
//
// Kraftstoff


@implementation NSDecimalNumber (NSDecimalNumber_kraftstoff)

- (NSDecimalNumber*)min: (NSDecimalNumber*)other
{
    if (other != nil && [self compare: other] != NSOrderedAscending)
        return other;
    else
        return self;
}

- (NSDecimalNumber*)max: (NSDecimalNumber*)other
{
    if (other != nil && [self compare: other] != NSOrderedDescending)
        return other;
    else
        return self;
}

@end
