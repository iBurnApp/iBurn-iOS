//
//  ThemeCamp.h
//  iBurn
//
//  Created by Anna Hentzel on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>

@class Favorite;

@interface ThemeCamp :  NSManagedObject  
{
	
	float distanceAway;
}

@property (nonatomic, assign) float distanceAway;
@property (nonatomic, retain) NSNumber * zoom;
@property (nonatomic, retain) NSNumber * longitude;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSString * desc;
@property (nonatomic, retain) NSString * location;
@property (nonatomic, retain) NSNumber * bm_id;
@property (nonatomic, retain) NSNumber * year;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * contactEmail, * simpleName;
@property (nonatomic, retain) Favorite * Favorite;

+ (ThemeCamp*) campForSimpleName:(NSString*) sName;

@end



