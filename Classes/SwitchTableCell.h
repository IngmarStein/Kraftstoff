// SwitchTableCell.h
//
// Kraftstoff


#import "PageCell.h"
#import "EditablePageCell.h"



@interface SwitchTableCell : PageCell {}

@property (nonatomic, retain) UISwitch *valueSwitch;
@property (nonatomic, retain) UILabel  *valueLabel;
@property (nonatomic, retain) NSString *valueIdentifier;

@property (nonatomic, assign) id<EditablePageCellDelegate> delegate;

@end
