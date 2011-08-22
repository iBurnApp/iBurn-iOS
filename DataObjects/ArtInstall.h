//
//  ArtInstall.h
//  iBurn
//
//  Created by Anna Hentzel on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>

@class Favorite;

@interface ArtInstall :  NSManagedObject  
{
	float distanceAway;
}

@property (nonatomic, assign) float distanceAway;
@property (nonatomic, retain) NSString * timeAddress;

@property (nonatomic, retain) NSNumber * circularStreet;
@property (nonatomic, retain) NSNumber * zoom;
@property (nonatomic, retain) NSNumber * longitude;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSString * desc;
@property (nonatomic, retain) NSNumber * bm_id;
@property (nonatomic, retain) NSString * slug;
@property (nonatomic, retain) NSNumber * year;
@property (nonatomic, retain) NSString * artist;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * contactEmail;
@property (nonatomic, retain) Favorite * Favorite;

@end



