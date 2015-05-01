// PageCellDescription.h
//
// Kraftstoff

#import <Foundation/Foundation.h>

@interface PageCellDescription : NSObject {}

@property (nonatomic, weak, readonly) Class cellClass;
@property (nonatomic, strong) id cellData;

- (instancetype)initWithCellClass:(Class)class andData:(id)object NS_DESIGNATED_INITIALIZER;

@end
