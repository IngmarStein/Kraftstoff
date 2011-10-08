// DateEditTableCell.h
//
// Kraftstoff


#import "EditableProxyPageCell.h"

@interface DateEditTableCell : EditableProxyPageCell {}

@property (nonatomic, retain) NSString        *valueTimestamp;
@property (nonatomic, retain) NSDateFormatter *dateFormatter;

@property (nonatomic) BOOL autoRefreshedDate;

@end
