//
//  ThemeCamp.h
//  iBurn
//
//  Created by Anna Hentzel on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "BurnDataObject.h"

@class Favorite, CLLocation;

@interface ThemeCamp :  NSManagedObject <BurnDataObject>
{
  CLLocation * geolocation;
  float lastLatitude;
	float distanceAway;
}

@property (nonatomic, strong) NSNumber * zoom;
@property (nonatomic, strong) NSNumber * longitude;
@property (nonatomic, strong) NSString * url;
@property (nonatomic, strong) NSNumber * latitude;
@property (nonatomic, strong) NSString * playaLocation;
@property (nonatomic, strong) NSString * desc;
@property (nonatomic, strong) NSString * location;
@property (nonatomic, strong) NSNumber * bm_id;
@property (nonatomic, strong) NSNumber * year;
@property (nonatomic, strong) NSString * name;
@property (nonatomic, strong) NSString * contactEmail, * simpleName;
@property (nonatomic, strong) Favorite * Favorite;

+ (ThemeCamp*) campForID:(int) campId;

@end



