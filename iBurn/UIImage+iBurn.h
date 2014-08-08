//
//  UIImage+iBurn.h
//  iBurn
//
//  Created by David Chiles on 8/8/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (iBurn)

- (UIImage *)brc_imageTintedWithColor:(UIColor *)color;
- (UIImage *)brc_imageTintedWithColor:(UIColor *)color percent:(CGFloat)percent;

@end
