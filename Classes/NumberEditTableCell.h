// NumberEditTableCell.h
//
// Kraftstoff


#import "EditablePageCell.h"


@interface NumberEditTableCell : EditablePageCell {}

@property (nonatomic, strong) NSNumberFormatter *numberFormatter;
@property (nonatomic, strong) NSNumberFormatter *alternateNumberFormatter;
@property (nonatomic, strong) NSString          *textFieldSuffix;

@end
