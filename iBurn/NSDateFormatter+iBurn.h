//
//  NSDateFormatter+iBurn.h
//  
//
//  Created by Christopher Ballinger on 7/31/14.
//
//

#import <Foundation/Foundation.h>

@interface NSTimeZone (iBurn)

/** PST */
+ (NSTimeZone*) brc_burningManTimeZone;

@end

@interface NSDateFormatter (iBurn)

/** e.g. 2015-09-04 11:00:00 */
+ (NSDateFormatter*) brc_playaEventsAPIDateFormatter;

/** e.g. 2015-09-04 11 */
+ (NSDateFormatter*) brc_eventGroupHourlyDateFormatter;

/** e.g. 2015-09-04 */
+ (NSDateFormatter*) brc_eventGroupDateFormatter;

/** e.g. 4:19 AM */
+ (NSDateFormatter*) brc_timeOnlyDateFormatter;

/** e.g. Monday */
+ (NSDateFormatter*) brc_dayOfWeekDateFormatter;

/** e.g. 8/23 */
+ (NSDateFormatter*) brc_shortDateFormatter;


@end
