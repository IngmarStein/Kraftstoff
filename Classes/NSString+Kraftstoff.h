//  NSString+Kraftstoff.h
//
//  Kraftstoff


#import <UIKit/UIKit.h>

@interface NSString (Kraftstoff)

- (CGSize)sizeWithFont:(UIFont*)font
           minFontSize:(CGFloat)minPointSize
        actualFontSize:(CGFloat*)actualPointSize
              forWidth:(CGFloat)maxWidth;

@end
