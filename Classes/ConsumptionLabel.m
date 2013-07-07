// ConsumptionLabel.m
//
// Kraftstoff


#import "ConsumptionLabel.h"
#import "AppDelegate.h"


@implementation ConsumptionLabel

@synthesize highlightStrings;


- (void)drawRect:(CGRect)rect
{
    BOOL useOldStyle = ([AppDelegate systemMajorVersion] < 7);

    // Clear background
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:rect];

    [[UIColor clearColor] setFill];
    [path fill];

    // Get size of string and font size
    CGFloat fontSize  = 0.0;
    CGSize stringSize = [self.text sizeWithFont:self.font
                                    minFontSize:rint (self.font.pointSize * self.minimumScaleFactor)
                                 actualFontSize:&fontSize
                                       forWidth:self.frame.size.width
                                  lineBreakMode:NSLineBreakByTruncatingTail];

    CGPoint where = CGPointMake (floorf ((self.frame.size.width  - stringSize.width)  /2),
                                 floorf ((self.frame.size.height - stringSize.height) /2));

    CGFloat offset = 0.0;

    // Draw textportions with different colors
    NSString *text     = self.text;
    UIFont *actualFont = [self.font fontWithSize:fontSize];

    [self.highlightedTextColor setFill];

    for (NSString *subString in highlightStrings)
    {
        NSRange range = [text rangeOfString:subString];

        if (range.location != NSNotFound)
        {
            if (range.length > 0)
            {
                NSString *prefix  = [text substringToIndex:range.location];

                if (useOldStyle)
                {
                    [self.shadowColor setFill];
                    [prefix drawAtPoint:CGPointMake (where.x + self.shadowOffset.width + offset, where.y + self.shadowOffset.height)
                               withFont:self.font];
                }

                [self.textColor setFill];
                [prefix drawAtPoint:CGPointMake (where.x + offset, where.y)
                           withFont:self.font];

                offset += rintf ([prefix sizeWithFont:actualFont].width);
            }

            if (useOldStyle)
            {
                [self.shadowColor setFill];
                [subString drawAtPoint:CGPointMake (where.x + self.shadowOffset.width + offset, where.y + self.shadowOffset.height)
                              withFont:self.font];
            }

            [self.highlightedTextColor setFill];
            [subString drawAtPoint:CGPointMake (where.x + offset, where.y)
                          withFont:self.font];

            offset += rintf ([subString sizeWithFont:actualFont].width);
            text    = [text substringFromIndex:range.location + range.length];
        }
    }

    // Remaining text
    if (useOldStyle)
    {
        [self.shadowColor setFill];
        [text drawAtPoint:CGPointMake (where.x + self.shadowOffset.width + offset, where.y + self.shadowOffset.height)
                 withFont:self.font];
    }

    [self.highlightedTextColor setFill];
    [text drawAtPoint:CGPointMake (where.x + offset, where.y)
             withFont:self.font];
}

@end
