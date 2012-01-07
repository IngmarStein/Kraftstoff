// UIImage_extension.h
//
// Kraftstoff


@implementation UIImage (UIImage_kraftstoff)

+ (UIImage*)backgroundImageWithPattern: (UIImage*)pattern
{
    UIImage *image;

    // iOS 5
    if ([pattern respondsToSelector: @selector(resizableImageWithCapInsets:)])
    {
        image = [pattern resizableImageWithCapInsets: UIEdgeInsetsZero];
    }

    // iOS 4.3
    else
    {
        CGRect imageFrame = CGRectMake (0.0, 0.0, 320.0, pattern.size.height);

        UIGraphicsBeginImageContextWithOptions (imageFrame.size, YES, 0.0);
        {
            [pattern drawAsPatternInRect: imageFrame];
            image = UIGraphicsGetImageFromCurrentImageContext ();
        }
        UIGraphicsEndImageContext ();
    }

    return image;
}

@end
