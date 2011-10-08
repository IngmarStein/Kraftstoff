//  FuelCalculatorPageCell.h
//
//  Kraftstoffrechner


#import "PageCell.h"
#import "FuelCalculatorTextField.h"


@protocol FuelCalculatorPageCellDelegate

- (void)valueChanged: (id)newValue identifier: (NSString*)valueIdentifier;

@end


@interface FuelCalculatorPageCell : PageCell <UITextFieldDelegate> {}

@property (nonatomic, retain) FuelCalculatorTextField *textField;
@property (nonatomic, retain) NSString                *valueIdentifier;

@property (nonatomic, assign) id<FuelCalculatorPageCellDelegate> delegate;

@end
