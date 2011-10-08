// PageCellDescription.h
//
// Kraftstoff


@interface PageCellDescription : NSObject {}

@property (nonatomic, assign, readonly) Class cellClass;
@property (nonatomic, retain) id cellData;

- (id)initWithCellClass: (Class)class andData: (id)object;

@end
