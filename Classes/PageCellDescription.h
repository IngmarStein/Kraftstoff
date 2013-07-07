// PageCellDescription.h
//
// Kraftstoff


@interface PageCellDescription : NSObject {}

@property (nonatomic, weak, readonly) Class cellClass;
@property (nonatomic, strong) id cellData;

- (id)initWithCellClass:(Class)class andData:(id)object;

@end
