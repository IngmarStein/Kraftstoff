// PickerImageView.h
//
// Kraftstoff

#import <UIKit/UIKit.h>

@interface PickerImageView : UIImageView {}

@property (nonatomic, strong) NSString     *textualDescription;
@property (nonatomic, weak)   UIPickerView *pickerView;
@property (nonatomic)         NSInteger     rowIndex;

@end
