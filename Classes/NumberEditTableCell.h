// NumberEditTableCell.h
//
// Kraftstoff


#import "EditablePageCell.h"


@interface NumberEditTableCell : EditablePageCell {}

@property (nonatomic, retain) NSNumberFormatter *numberFormatter;
@property (nonatomic, retain) NSNumberFormatter *alternateNumberFormatter;
@property (nonatomic, retain) NSString          *textFieldSuffix;

@end
