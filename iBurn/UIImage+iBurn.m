//
//  UIImage+iBurn.m
//  iBurn
//
//  Created by David Chiles on 8/8/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "UIImage+iBurn.h"

@implementation UIImage (iBurn)

- (UIImage *)brc_imageTintedWithColor:(UIColor *)color
{
	return [self brc_imageTintedWithColor:color percent:0.4];
}


- (UIImage *)brc_imageTintedWithColor:(UIColor *)color percent:(CGFloat)percent
{
	if (color) {

		UIImage *image;
		
		UIGraphicsBeginImageContextWithOptions([self size], NO, 0.0f);
        
		CGRect rect = CGRectZero;
		rect.size = [self size];
		
		[color set];
		UIRectFill(rect);
		
		[self drawInRect:rect blendMode:kCGBlendModeDestinationIn alpha:1.0];
		
		if (percent > 0.0) {
			[self drawInRect:rect blendMode:kCGBlendModeSourceAtop alpha:percent];
		}
		image = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		
		return image;
	}
	
	return self;
}

@end
