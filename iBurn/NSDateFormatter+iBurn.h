//
//  NSDateFormatter+iBurn.h
//  
//
//  Created by Christopher Ballinger on 7/31/14.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDateFormatter (iBurn)

/** e.g. 2024-08-27T13:00:00-07:00 */
@property (nonatomic, class, readonly) NSISO8601DateFormatter* brc_iso8601DateFormatter;

/** e.g. 2015-09-04T11:00:00-07:00 */
@property (nonatomic, class, readonly) NSDateFormatter* brc_playaEventsAPIDateFormatter;

/** e.g. 2015-09-04 11 */
@property (nonatomic, class, readonly) NSDateFormatter* brc_eventGroupHourlyDateFormatter;

/** e.g. 2015-09-04 */
@property (nonatomic, class, readonly) NSDateFormatter* brc_eventGroupDateFormatter;

/** e.g. 4:19 AM */
@property (nonatomic, class, readonly) NSDateFormatter* brc_timeOnlyDateFormatter;

/** e.g. Monday */
@property (nonatomic, class, readonly) NSDateFormatter* brc_dayOfWeekDateFormatter;

/** e.g. 8/23 */
@property (nonatomic, class, readonly) NSDateFormatter* brc_shortDateFormatter;

@end

NS_ASSUME_NONNULL_END
