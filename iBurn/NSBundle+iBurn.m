//
//  NSBundle+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/9/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "NSBundle+iBurn.h"

@implementation NSBundle (iBurn)

/** Return iBurn-Data bundle */
+ (NSBundle*) brc_dataBundle {
    NSString *folderName = @"2017";
    NSString *bundlePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:folderName];
    NSBundle *dataBundle = [NSBundle bundleWithPath:bundlePath];
    NSParameterAssert(dataBundle != nil);
    return dataBundle;
}

@end
