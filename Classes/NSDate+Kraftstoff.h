// NSDate+Kraftstoff.h
//
// Kraftstoff


@interface NSDate (Kraftstoff)

// Adding a month offset to dates, also removes the second component
+ (NSDate *)dateWithOffsetInMonths:(NSInteger)numberOfMonths fromDate:(NSDate *)startDate;

// Removes the second component from a date
+ (NSDate *)dateWithoutSeconds:(NSDate *)date;

// Timeinterval for hours/minutes ellapsed in the given day
+ (NSTimeInterval)timeIntervalSinceBeginningOfDay:(NSDate *)date;

// Number of days between two dates
+ (NSInteger)numberOfCalendarDaysFrom:(NSDate *)startDate to:(NSDate *)endDate;

@end
