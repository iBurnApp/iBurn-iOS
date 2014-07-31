//
//  NSDate+iBurn.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/31/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (iBurn)

+ (NSInteger)brc_daysBetweenDate:(NSDate*)fromDateTime andDate:(NSDate*)toDateTime;

@end
