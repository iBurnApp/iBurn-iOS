//
//  ArtInstall.h
//  iBurn
//
//  Created by Anna Hentzel on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "BurnDataObject.h"

@class Favorite;

@interface ArtInstall :  NSManagedObject <BurnDataObject>
{
	float distanceAway;
  
  float lastLatitude;
  CLLocation * geolocation;
}

@property (nonatomic, strong) NSString * timeAddress;

@property (nonatomic, strong) NSNumber * circularStreet;
@property (nonatomic, strong) NSNumber * zoom;
@property (nonatomic, strong) NSNumber * longitude;
@property (nonatomic, strong) NSNumber * latitude;
@property (nonatomic, strong) NSString * url;
@property (nonatomic, strong) NSString * desc;
@property (nonatomic, strong) NSNumber * bm_id;
@property (nonatomic, strong) NSString * slug;
@property (nonatomic, strong) NSNumber * year;
@property (nonatomic, strong) NSString * artist;
@property (nonatomic, strong) NSString * name;
@property (nonatomic, strong) NSString * contactEmail;
@property (nonatomic, strong) NSString * artistHometown;
@property (nonatomic, strong) Favorite * Favorite;

+ (ArtInstall*) artForName:(NSString*) sName;

@end



