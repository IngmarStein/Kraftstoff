// DateEditTableCell.h
//
// Kraftstoff


#import "EditableProxyPageCell.h"

@interface DateEditTableCell : EditableProxyPageCell {}

@property (nonatomic, strong) NSString        *valueTimestamp;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@property (nonatomic) BOOL autoRefreshedDate;

@end
