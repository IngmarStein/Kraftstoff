// FuelCalculatorPageCell.h
//
// Kraftstoff


#import "PageCell.h"
#import "EditablePageCellTextField.h"


@protocol EditablePageCellDelegate

- (id)valueForIdentifier: (NSString*)valueIdentifier;
- (void)valueChanged: (id)newValue identifier: (NSString*)valueIdentifier;

@optional

- (void)focusNextFieldForValueIdentifier: (NSString*)valueIdentifier;

@end


@interface EditablePageCell : PageCell <UITextFieldDelegate> {}

@property (nonatomic, retain) EditablePageCellTextField *textField;
@property (nonatomic, retain) NSString                  *valueIdentifier;

@property (nonatomic, assign) id<EditablePageCellDelegate> delegate;

@end
