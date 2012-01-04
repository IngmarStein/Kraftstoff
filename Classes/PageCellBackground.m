// PageCellBackground.m
//
// Kraftstoff


#import "PageCellBackground.h"
#import "PageViewController.h"


static CGFloat const PageCellBackgroundRadius = 10.0;


static CGGradientRef PageCellBackgroundGradient (BOOL selected)
{
	static CGGradientRef bgGradient [2] = { NULL, NULL };

	if (bgGradient [selected] == NULL)
	{
		UIColor *colorTop;
		UIColor *colorBot;

		if (selected)
		{
			colorTop = [UIColor colorWithRed: 0.818 green: 0.818 blue: 0.827 alpha: 1.00];
			colorBot = [UIColor colorWithRed: 0.746 green: 0.746 blue: 0.762 alpha: 1.00];
		}
		else
		{
			colorTop = [UIColor colorWithRed: 0.858 green: 0.858 blue: 0.867 alpha: 1.00];
			colorBot = [UIColor colorWithRed: 0.706 green: 0.706 blue: 0.722 alpha: 1.00];
		}

        CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB ();
        {
            CGFloat bgComponents [2][4];
            memcpy (bgComponents [0], CGColorGetComponents (colorTop.CGColor), sizeof (CGFloat) * 4);
            memcpy (bgComponents [1], CGColorGetComponents (colorBot.CGColor), sizeof (CGFloat) * 4);

            CGFloat const locations [2] = {0.0, 1.0};
            bgGradient [selected] = CGGradientCreateWithColorComponents (colorspace, (CGFloat const*)bgComponents, locations, 2);
        }
		CFRelease(colorspace);
	}

	return bgGradient [selected];
}


static CF_RETURNS_RETAINED CGPathRef allocPathWithRoundRect (CGRect rect, PageCellGroupPosition position, CGFloat cornerRadius)
{
	CGMutablePathRef path = CGPathCreateMutable ();
	CGPathMoveToPoint (path, NULL,
                       rect.origin.x,
                       rect.origin.y + rect.size.height - cornerRadius);

    if (position == PageCellGroupPositionTop || position == PageCellGroupPositionTopAndBottom)
    {
        CGPathAddArcToPoint (path, NULL,
                             rect.origin.x,
                             rect.origin.y,
                             rect.origin.x + rect.size.width,
                             rect.origin.y,
                             cornerRadius);

        CGPathAddArcToPoint (path, NULL,
                             rect.origin.x + rect.size.width,
                             rect.origin.y,
                             rect.origin.x + rect.size.width,
                             rect.origin.y + rect.size.height,
                             cornerRadius);
    }
    else
    {
        CGPathAddLineToPoint (path, NULL,
                              rect.origin.x,
                              rect.origin.y);

        CGPathAddLineToPoint (path, NULL,
                              rect.origin.x + rect.size.width,
                              rect.origin.y);
    }

    if (position == PageCellGroupPositionBottom || position == PageCellGroupPositionTopAndBottom)
    {
        CGPathAddArcToPoint (path, NULL,
                             rect.origin.x + rect.size.width,
                             rect.origin.y + rect.size.height,
                             rect.origin.x,
                             rect.origin.y + rect.size.height,
                             cornerRadius);

        CGPathAddArcToPoint (path, NULL,
                             rect.origin.x,
                             rect.origin.y + rect.size.height,
                             rect.origin.x,
                             rect.origin.y,
                             cornerRadius);
    }
    else
    {
        CGPathAddLineToPoint (path, NULL,
                              rect.origin.x + rect.size.width,
                              rect.origin.y + rect.size.height);

        CGPathAddLineToPoint (path, NULL,
                              rect.origin.x,
                              rect.origin.y + rect.size.height);
    }

	CGPathCloseSubpath (path);
	return path;
}


@implementation PageCellBackground


@synthesize strokeColor;
@synthesize position;


+ (PageCellGroupPosition)positionForIndexPath: (NSIndexPath*)indexPath inTableView: (UITableView*)tableView;
{
	PageCellGroupPosition result;

	if ([indexPath row] == 0)
		result = PageCellGroupPositionTop;
	else
        result = PageCellGroupPositionMiddle;

	PageViewController *pageViewController = (PageViewController*)[tableView delegate];

	if ([indexPath row] == [pageViewController tableView: tableView numberOfRowsInSection: indexPath.section] - 1)
	{
		if (result == PageCellGroupPositionTop)
			result = PageCellGroupPositionTopAndBottom;
		else
			result = PageCellGroupPositionBottom;
	}

	return result;
}


- (id)initSelected: (BOOL)isSelected grouped: (BOOL)isGrouped;
{
	if ((self = [super init]))
	{
		selected        = isSelected;
		groupBackground = isGrouped;

		self.strokeColor      = [UIColor colorWithWhite: 0.6 alpha: 1.0];
		self.backgroundColor  = [UIColor clearColor];
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	}

	return self;
}


- (void)layoutSubviews
{
	[super layoutSubviews];
	[self setNeedsDisplay];
}


- (void)setPosition: (PageCellGroupPosition)newPosition
{
	if (position != newPosition)
	{
		position = newPosition;
		[self setNeedsDisplay];
	}
}


- (void)drawRect: (CGRect)rect
{
	CGContextRef context  = UIGraphicsGetCurrentContext ();
	CGPathRef outlinePath = NULL;


    // Clipping for rounded cell border
    if (groupBackground)
    {
		outlinePath = allocPathWithRoundRect (CGRectInset (rect, 0.5, 0.5), position, PageCellBackgroundRadius);

		CGContextSaveGState (context);
		CGContextAddPath (context, outlinePath);
		CGContextClip (context);
	}


    // Cell gradient
	CGContextDrawLinearGradient (context,
                                 PageCellBackgroundGradient (selected),
                                 CGPointMake (0.0, rect.origin.y + 0.0),
                                 CGPointMake (0.0, rect.origin.y + rect.size.height),
                                 0);


    // Cell frame
    if (groupBackground)
	{
		CGContextRestoreGState (context);

		CGContextSetStrokeColorWithColor (context, strokeColor.CGColor);
		CGContextSetLineWidth (context, 1.0);
		CGContextAddPath (context, outlinePath);
		CGContextStrokePath (context);

		CGPathRelease (outlinePath);

		if (position != PageCellGroupPositionTop && position != PageCellGroupPositionTopAndBottom)
		{
            UIColor *white = [UIColor colorWithWhite: 0.90 alpha: 1.0];
            CGContextSetStrokeColorWithColor (context, white.CGColor);
			CGContextMoveToPoint (context, rect.origin.x + 1, rect.origin.y + 0.5);
			CGContextAddLineToPoint (context, rect.origin.x + rect.size.width - 1, rect.origin.y + 0.5);
			CGContextStrokePath (context);
		}
	}
	else
	{
		CGContextSetStrokeColorWithColor (context, strokeColor.CGColor);
		CGContextSetLineWidth (context, 1.0);
		CGContextMoveToPoint (context, rect.origin.x, rect.origin.y + rect.size.height - 0.5);
		CGContextAddLineToPoint (context, rect.origin.x + rect.size.width, rect.origin.y + rect.size.height - 0.5);
		CGContextStrokePath (context);
	}
}

@end
