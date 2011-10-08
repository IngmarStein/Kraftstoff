// PickerImageView.h
//
// Kraftstoff


@interface PickerImageView : UIImageView {}

@property (nonatomic, retain) NSString     *textualDescription;
@property (nonatomic, assign) UIPickerView *pickerView;
@property (nonatomic)         NSInteger     rowIndex;

- (void)viewTapped: (id)sender;

@end
