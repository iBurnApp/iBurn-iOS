//
//  NSDateFormatter+iBurn.h
//  
//
//  Created by Christopher Ballinger on 7/31/14.
//
//

#import <Foundation/Foundation.h>

@interface NSDateFormatter (iBurn)

+ (NSDateFormatter*) brc_threadSafeDateFormatter;

+ (NSDateFormatter*) brc_threadSafeGroupDateFormatter;

@end
