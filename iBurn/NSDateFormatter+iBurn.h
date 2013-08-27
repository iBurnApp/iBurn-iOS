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

/** e.g. 4:19 AM */
+ (NSDateFormatter*) brc_timeOnlyDateFormatter;

/** e.g. Monday */
+ (NSDateFormatter*) brc_dayOfWeekDateFormatter;

/** e.g. 8/23 */
+ (NSDateFormatter*) brc_shortDateFormatter;


@end
