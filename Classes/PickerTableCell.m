// PickerTableCell.m
//
// Kraftstoff


#import "PickerTableCell.h"


// Standard cell geometry
static CGFloat const PickerViewCellWidth  = 290.0;
static CGFloat const PickerViewCellHeight =  44.0;


@interface PickerTableCell (private)

- (void)selectRow: (NSInteger)row;

@end



@implementation PickerTableCell

@synthesize picker;
@synthesize pickerLabels;


- (void)finishConstruction
{
	[super finishConstruction];

    self.picker = [[UIPickerView alloc] init];

    picker.showsSelectionIndicator = YES;
    picker.dataSource              = self;
    picker.delegate                = self;

    self.textField.inputView = picker;
}


- (void)configureForData: (id)dataObject viewController: (id)viewController tableView: (UITableView*)tableView indexPath: (NSIndexPath*)indexPath
{
	[super configureForData: dataObject viewController: viewController tableView: tableView indexPath: indexPath];

    // Array of picker labels
    self.pickerLabels = [(NSDictionary*)dataObject objectForKey: @"labels"];
    [picker reloadAllComponents];

    // (Re-)configure initial selected row
    NSInteger initialIndex = [[self.delegate valueForIdentifier: self.valueIdentifier] integerValue];

    [picker selectRow: initialIndex inComponent: 0 animated: NO];
    [picker reloadComponent: 0];

    self.textFieldProxy.text = [self pickerView: picker titleForRow: initialIndex forComponent: 0];
}


- (void)selectRow: (NSInteger)row
{
    self.textFieldProxy.text = [self pickerView: picker titleForRow: row forComponent: 0];

    [self.delegate valueChanged: [NSNumber numberWithInteger: (int)row] identifier: self.valueIdentifier];
}



#pragma mark -
#pragma mark UIPickerViewDataSource



- (NSInteger)numberOfComponentsInPickerView: (UIPickerView*)pickerView
{
    return 1;
}


- (NSInteger)pickerView: (UIPickerView*)pickerView numberOfRowsInComponent: (NSInteger)component
{
    return [pickerLabels count];
}


- (void)pickerView: (UIPickerView*)pickerView didSelectRow: (NSInteger)row inComponent: (NSInteger)component
{
    [self selectRow: row];
}



#pragma mark -
#pragma mark UIPickerViewDelegate



- (CGFloat)pickerView: (UIPickerView*)pickerView rowHeightForComponent: (NSInteger)component
{
    return PickerViewCellHeight;
}


- (CGFloat)pickerView: (UIPickerView*)pickerView widthForComponent: (NSInteger)component
{
    return PickerViewCellWidth;
}


- (NSString*)pickerView: (UIPickerView*)pickerView titleForRow: (NSInteger)row forComponent: (NSInteger)component
{
    return [pickerLabels objectAtIndex: row];
}

@end
