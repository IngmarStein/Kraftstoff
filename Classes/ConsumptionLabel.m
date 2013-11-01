// ConsumptionLabel.m
//
// Kraftstoff


#import "ConsumptionLabel.h"
#import "AppDelegate.h"
#import "NSString+Kraftstoff.h"


@implementation ConsumptionLabel

@synthesize highlightStrings;


- (void)drawRect:(CGRect)rect
{
    // Clear background
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:rect];

    [[UIColor clearColor] setFill];
    [path fill];

    // Get size of string and font size
    CGFloat fontSize  = 0.0;
    CGSize stringSize = [self.text sizeWithFont:self.font
                                    minFontSize:rint (self.font.pointSize * self.minimumScaleFactor)
                                 actualFontSize:&fontSize
                                       forWidth:self.frame.size.width];

    CGPoint where = CGPointMake (floorf ((self.frame.size.width  - stringSize.width)  /2),
                                 floorf ((self.frame.size.height - stringSize.height) /2));

    CGFloat offset = 0.0;

    // Draw textportions with different colors
    NSString *text = self.text;
    UIFont *actualFont = [self.font fontWithSize:fontSize];
    NSDictionary *normalAttributes = @{NSFontAttributeName:actualFont, NSForegroundColorAttributeName:self.textColor};
    NSDictionary *highightAttributes = @{NSFontAttributeName:actualFont, NSForegroundColorAttributeName:self.highlightedTextColor};

    for (NSString *subString in highlightStrings) {

        NSRange range = [text rangeOfString:subString];

        if (range.location != NSNotFound) {

            // Text portion until match in normal colors
            if (range.location > 0) {

                NSString *prefix = [text substringToIndex:range.location];
                [prefix drawAtPoint:CGPointMake (where.x + offset, where.y) withAttributes:normalAttributes];
                offset += rintf ([prefix sizeWithAttributes:normalAttributes].width);
            }

            // Match in highlight colors
            [subString drawAtPoint:CGPointMake (where.x + offset, where.y) withAttributes:highightAttributes];
            offset += rintf ([subString sizeWithAttributes:highightAttributes].width);

            // Cut away matched drawn prefix
            text = [text substringFromIndex:range.location + range.length];
        }
    }

    // Draw remaining text
    [text drawAtPoint:CGPointMake (where.x + offset, where.y) withAttributes:normalAttributes];
}

@end
