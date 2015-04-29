// PageCellDescription.h
//
// Kraftstoff

#import <Foundation/Foundation.h>

@interface PageCellDescription : NSObject {}

@property (nonatomic, weak, readonly) Class cellClass;
@property (nonatomic, strong) id cellData;

- (id)initWithCellClass:(Class)class andData:(id)object;

@end
