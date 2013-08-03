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

@end



