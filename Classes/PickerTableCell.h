// PickerTableCell.h
//
// Kraftstoff


#import "EditableProxyPageCell.h"

@interface PickerTableCell : EditableProxyPageCell <UIPickerViewDataSource, UIPickerViewDelegate> {}

@property (nonatomic, strong) UIPickerView *picker;
@property (nonatomic, strong) NSArray      *pickerLabels;
@property (nonatomic, strong) NSArray      *pickerShortLabels;

@end
