// CarTableCell.h
//
// Kraftstoff


#import "EditableProxyPageCell.h"

@interface CarTableCell : EditableProxyPageCell <UIPickerViewDataSource, UIPickerViewDelegate> {}

@property (nonatomic, retain) UIPickerView *carPicker;
@property (nonatomic, retain) NSArray      *fetchedObjects;

@end
