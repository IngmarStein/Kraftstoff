// PageCellDescription.m
//
// Kraftstoff


#import "PageCellDescription.h"


@implementation PageCellDescription

@synthesize cellClass;
@synthesize cellData;

- (instancetype)initWithCellClass:(Class)class andData:(id)object
{
	if ((self = [super init])) {

		cellClass = class;
		cellData  = object;
	}

	return self;
}

@end
