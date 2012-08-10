//
//  Event.h
//  iBurn
//
//  Created by Anna Hentzel on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "BurnDataObject.h"

@class Favorite, ThemeCamp;

@interface Event :  NSManagedObject <BurnDataObject>
{
}

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSDate * startTime;
@property (nonatomic, retain) NSDate * endTime;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSString * desc;

@property (nonatomic, retain) NSNumber * allDay;
@property (nonatomic, retain) NSString * campHost;
@property (nonatomic, retain) NSNumber * year;
@property (nonatomic, retain) NSNumber * bm_id;
@property (nonatomic, retain) NSNumber * camp_id;
@property (nonatomic, retain) NSNumber * zoom;
@property (nonatomic, retain) Favorite * Favorite;

@property (nonatomic, retain) NSNumber * longitude;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSString * day;

@property (nonatomic, retain) ThemeCamp *camp;

+ (NSArray*) eventsForDay:(NSString*) day;
+ (NSString*) getDay:(NSDate*) date;
+ (NSArray*) getTodaysEvents;
+ (Event*) eventForName:(NSString*) sName;

- (float) distanceAway;

@end



