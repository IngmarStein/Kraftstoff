// CarTableCell.h
//
// Kraftstoff


#import "EditableProxyPageCell.h"

@interface CarTableCell : EditableProxyPageCell <UIPickerViewDataSource, UIPickerViewDelegate> {}

@property (nonatomic, strong) UIPickerView *carPicker;
@property (nonatomic, strong) NSArray      *fetchedObjects;

@end
