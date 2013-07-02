// NSDate+Kraftstoff.m
//
// Kraftstoff


#import "NSDate+Kraftstoff.h"


// Calendar component-mask for date+time but without seconds
static NSUInteger noSecondsComponentMask = (NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit);

// Calendar component-mask for hour+minutes
static NSUInteger timeOfDayComponentMask = (NSHourCalendarUnit | NSMinuteCalendarUnit);


@implementation NSDate (Kraftstoff)


+ (NSDate*)dateWithOffsetInMonths:(NSInteger)numberOfMonths fromDate:(NSDate *)date
{
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    
    NSDateComponents *noSecComponents = [gregorianCalendar components:noSecondsComponentMask fromDate:date];
    NSDateComponents *deltaComponents = [[NSDateComponents alloc] init];
    
    [deltaComponents setMonth:numberOfMonths];
    
    return [gregorianCalendar dateByAddingComponents:deltaComponents
                                              toDate:[gregorianCalendar dateFromComponents:noSecComponents]
                                             options:0];
}


+ (NSDate*)dateWithoutSeconds:(NSDate *)date
{
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *noSecComponents = [gregorianCalendar components:noSecondsComponentMask fromDate:date];
    
    return [gregorianCalendar dateFromComponents:noSecComponents];
}


+ (NSTimeInterval)timeIntervalSinceBeginningOfDay:(NSDate *)date
{
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *timeOfDayComponents = [gregorianCalendar components:timeOfDayComponentMask fromDate:date];
    
    return timeOfDayComponents.hour * 3600 + timeOfDayComponents.minute * 60;
}


+ (NSInteger)numberOfCalendarDaysFrom:(NSDate *)startDate to:(NSDate *)endDate
{
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar];
    NSDate *referenceDate = [NSDate dateWithTimeIntervalSince1970: 0.0];
    
    NSInteger daysToStart = [[gregorian components:NSDayCalendarUnit
                                          fromDate:referenceDate
                                            toDate:startDate
                                           options:0] day];
    
    NSInteger daysToEnd   = [[gregorian components:NSDayCalendarUnit
                                          fromDate:referenceDate
                                            toDate:endDate
                                           options:0] day];
    
    return daysToEnd - daysToStart + 1;
}

@end
