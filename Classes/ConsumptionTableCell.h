// ConsumptionTableCell.h
//
// Kraftstoff


#import "PageCell.h"
#import "ConsumptionLabel.h"


@interface ConsumptionTableCell : PageCell {}

@property (nonatomic, strong, readonly) ConsumptionLabel *coloredLabel;

@end
