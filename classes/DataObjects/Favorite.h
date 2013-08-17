//
//  Favorite.h
//  iBurn
//
//  Created by Andrew Johnson on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>

@class ArtInstall;
@class Event;
@class ThemeCamp;

@interface Favorite :  NSManagedObject  
{
  
}

@property (nonatomic, strong) ThemeCamp * ThemeCamp;
@property (nonatomic, strong) Event * Event;
@property (nonatomic, strong) ArtInstall * ArtInstall;

+ (void) addFavorite:(NSString*) type id:(NSNumber*)bm_id;
+ (BOOL) isFavorite:(NSString*) type id:(NSNumber*)bm_id;
+ (NSArray*) favoritesForType:(NSString*) type;
+ (void) setSelected:(NSString*) type id:(NSNumber*)bm_id;
+ (BOOL) isSelected:(NSString*) type id:(NSNumber*)bm_id;

@end



