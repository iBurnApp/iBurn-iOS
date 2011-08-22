// 
//  ArtInstall.m
//  iBurn
//
//  Created by Anna Hentzel on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ArtInstall.h"
#import "iBurnAppDelegate.h"
#import "Favorite.h"

@implementation ArtInstall 
@synthesize distanceAway;

@dynamic circularStreet;
@dynamic zoom;
@dynamic longitude;
@dynamic timeAddress;
@dynamic latitude;
@dynamic url;
@dynamic desc;
@dynamic bm_id;
@dynamic slug;
@dynamic year;
@dynamic artist;
@dynamic name;
@dynamic contactEmail;
@dynamic Favorite;



+ (ArtInstall*) artForName:(NSString*) sName {
  
  
  NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"ArtInstall" inManagedObjectContext:[t managedObjectContext]];
  [fetchRequest setEntity:entity];
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name = %@", sName];
  [fetchRequest setPredicate:predicate];	
  NSError *error;
  NSArray *objects = [[t managedObjectContext] executeFetchRequest:fetchRequest error:&error];
  
  if ([objects count] > 0) {
    return [objects objectAtIndex:0];
  }
  return nil;
  
}
@end
