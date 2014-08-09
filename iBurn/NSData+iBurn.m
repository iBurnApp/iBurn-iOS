//
//  NSData+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/9/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "NSData+iBurn.h"

@implementation NSData (iBurn)

// http://stackoverflow.com/a/9084784/805882
- (NSString *)brc_hexadecimalString {
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];
    if (!dataBuffer) {
        return @"";
    }
    
    NSUInteger dataLength  = [self length];
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < dataLength; ++i) {
        [hexString appendFormat:@"%02lx", (unsigned long)dataBuffer[i]];
    }
    
    return hexString;
}


@end
