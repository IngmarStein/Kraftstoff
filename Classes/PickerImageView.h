// PickerImageView.h
//
// Kraftstoff


@interface PickerImageView : UIImageView {}

@property (nonatomic, strong)            NSString     *textualDescription;
@property (nonatomic, unsafe_unretained) UIPickerView *pickerView;
@property (nonatomic)                    NSInteger     rowIndex;

- (void)viewTapped: (id)sender;

@end
