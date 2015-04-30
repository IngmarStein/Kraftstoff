// PageCellDescription.m
//
// Kraftstoff


#import "PageCellDescription.h"


@implementation PageCellDescription

- (instancetype)initWithCellClass:(Class)class andData:(id)object
{
	if ((self = [super init])) {

		_cellClass = class;
		_cellData  = object;
	}

	return self;
}

@end
