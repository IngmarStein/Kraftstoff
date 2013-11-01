//  NSString+Kraftstoff.m
//
//  Kraftstoff


#import "NSString+Kraftstoff.h"


@implementation NSString (Kraftstoff)

- (CGSize)sizeWithFont:(UIFont*)font
           minFontSize:(CGFloat)minPointSize
        actualFontSize:(CGFloat*)actualPointSize
              forWidth:(CGFloat)maxWidth
{
    // OS still supports deprecated original function...
    if ([self respondsToSelector:@selector(sizeWithFont:minFontSize:actualFontSize:forWidth:lineBreakMode:)]) {

        // Avoid deprecation warning, we checked wether the selector still exists
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [self sizeWithFont:font
                      minFontSize:minPointSize
                   actualFontSize:actualPointSize
                         forWidth:maxWidth
                    lineBreakMode:NSLineBreakByTruncatingTail];
        #pragma clang diagnostic pop

    } else {

        // Try out text sizes until width is no longer exceeded
        CGFloat pointSize = [font pointSize];

        if (pointSize < minPointSize)
            pointSize = minPointSize;

        for (;;) {

            // Compute size with current font size
            CGSize size = [self sizeWithAttributes:@{NSFontAttributeName:[font fontWithSize:pointSize]}];

            // String matches or minimum font size is reached
            if (size.width <= maxWidth || pointSize <= minPointSize) {

                if (actualPointSize)
                    *actualPointSize = pointSize;

                return size;
            }

            // Reduce point size, try again
            pointSize = pointSize * size.width/maxWidth;
        }
    }
}

@end
