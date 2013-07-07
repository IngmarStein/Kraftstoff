// EditablePageCell.h
//
// Kraftstoff


#import "PageCell.h"
#import "EditablePageCellTextField.h"


@protocol EditablePageCellDelegate

- (id)valueForIdentifier:(NSString *)valueIdentifier;
- (void)valueChanged:(id)newValue identifier:(NSString *)valueIdentifier;

@optional

- (BOOL)valueValid:(id)newValue identifier:(NSString *)valueIdentifier;
- (void)focusNextFieldForValueIdentifier:(NSString *)valueIdentifier;

@end


@interface EditablePageCell : PageCell <UITextFieldDelegate> {}

- (UIColor *)invalidTextColor;

@property (nonatomic, strong) EditablePageCellTextField *textField;
@property (nonatomic, strong) NSString                  *valueIdentifier;

@property (nonatomic, weak) id<EditablePageCellDelegate> delegate;

@end
