// PickerTableCell.h
//
// Kraftstoff


#import "EditableProxyPageCell.h"

@interface PickerTableCell : EditableProxyPageCell <UIPickerViewDataSource, UIPickerViewDelegate> {}

@property (nonatomic, retain) UIPickerView *picker;
@property (nonatomic, retain) NSArray      *pickerLabels;

@end
