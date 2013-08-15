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
  CLLocation * geolocation;
  float lastLatitude;
  float distanceAway;
}

@property (nonatomic, strong) NSString * name;
@property (nonatomic, strong) NSDate * startTime;
@property (nonatomic, strong) NSDate * endTime;
@property (nonatomic, strong) NSString * url;
@property (nonatomic, strong) NSString * desc;

@property (nonatomic, strong) NSNumber * allDay;
@property (nonatomic, strong) NSString * campHost;
@property (nonatomic, strong) NSNumber * year;
@property (nonatomic, strong) NSNumber * bm_id;
@property (nonatomic, strong) NSNumber * camp_id;
@property (nonatomic, strong) NSNumber * zoom;
@property (nonatomic, strong) Favorite * Favorite;

@property (nonatomic, strong) NSNumber * longitude;
@property (nonatomic, strong) NSNumber * latitude;
@property (nonatomic, strong) NSString * day;


@property (nonatomic, strong) ThemeCamp *camp;

+ (NSArray*) eventsForDay:(NSString*) day;
+ (NSString*) getDay:(NSDate*) date;
+ (NSArray*) getTodaysEvents;
+ (Event*) eventForName:(NSString*) sName;
+ (Event*) eventForID:(NSNumber*) bm_id;


@end



