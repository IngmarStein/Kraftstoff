// PickerTableCell.m
//
// Kraftstoff


#import "PickerTableCell.h"


// Standard cell geometry
static CGFloat const PickerViewCellWidth  = 290.0;
static CGFloat const PickerViewCellHeight =  44.0;


@implementation PickerTableCell

@synthesize picker;
@synthesize pickerLabels;
@synthesize pickerShortLabels;


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
    self.pickerShortLabels = [(NSDictionary*)dataObject objectForKey: @"shortLabels"];
    [picker reloadAllComponents];

    // (Re-)configure initial selected row
    NSInteger initialIndex = [[self.delegate valueForIdentifier: self.valueIdentifier] integerValue];

    [picker selectRow: initialIndex inComponent: 0 animated: NO];
    [picker reloadComponent: 0];

    self.textFieldProxy.text = [((pickerShortLabels) ? pickerShortLabels : pickerLabels) objectAtIndex: initialIndex];
}


- (void)selectRow: (NSInteger)row
{
    self.textFieldProxy.text = [((pickerShortLabels) ? pickerShortLabels : pickerLabels) objectAtIndex: row];

    [self.delegate valueChanged: @((int)row) identifier: self.valueIdentifier];
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


- (UIView*)pickerView: (UIPickerView*)pickerView viewForRow: (NSInteger)row forComponent: (NSInteger)component reusingView: (UIView*)view
{
    UILabel* label = (UILabel*)view;

    if (!label)
    {
        label = [[UILabel alloc] init];
        label.font = [UIFont boldSystemFontOfSize:18];
        label.frame = CGRectMake (0.0f, 0.0f, PickerViewCellWidth-20, PickerViewCellHeight);
        label.backgroundColor = [UIColor clearColor];
    }
    
    label.text = [self pickerView:pickerView titleForRow:row forComponent:component];

    return label;
}

@end
