// 
//  Event.m
//  iBurn
//
//  Created by Anna Hentzel on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "Event.h"

#import "Favorite.h"
#import "iBurnAppDelegate.h"
#import "MyCLController.h"

@implementation Event 
@synthesize camp;

@dynamic longitude;
@dynamic url;
@dynamic latitude;
@dynamic desc;
@dynamic campHost;
@dynamic bm_id;
@dynamic endTime;
@dynamic allDay;
@dynamic year;
@dynamic camp_id;
@dynamic startTime;
@dynamic name;
@dynamic zoom;
@dynamic Favorite;
@dynamic day;

- (void) dealloc {
  self.camp = nil;
  [super dealloc];
}

+ (NSString*) getDay:(NSDate*) date {
  static NSDateFormatter *dateFormatter = nil;
  if (dateFormatter == nil) {
    dateFormatter = [[NSDateFormatter alloc]init]; 
    [dateFormatter setDateFormat:@"dd"];
  }                                   
  NSString *dow = [dateFormatter stringFromDate:date];
  return dow;
}

+ (NSArray*) getTodaysEvents {
  NSString* day = [Event getDay:[NSDate date]];
  return [Event eventsForDay:day];
}

+ (NSArray*) eventsForDay:(NSString*) day {
  NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:[t managedObjectContext]];
  [fetchRequest setEntity:entity];
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"day = %@", day];
  [fetchRequest setPredicate:predicate];	
  NSError *error;
  NSArray *objects = [[t managedObjectContext] executeFetchRequest:fetchRequest error:&error];
  
  
  return objects;
}


+ (Event*) eventForName:(NSString*) sName {
  
  
  NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:[t managedObjectContext]];
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

- (ThemeCamp*) camp {
  if (camp) {
    return camp;
  }
  iBurnAppDelegate *iBurnDelegate = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSManagedObjectContext *moc = [iBurnDelegate managedObjectContext];
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"ThemeCamp"
																											 inManagedObjectContext:moc];
	NSFetchRequest *request = [[[NSFetchRequest alloc]init]autorelease];
	[request setEntity:entityDescription];
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"bm_id = %@", self.camp_id];
  [request setPredicate:predicate];
	NSError *error;
	NSArray *objects = [moc executeFetchRequest:request error:&error];
	if(objects && [objects count] > 0) {
    self.camp = [objects objectAtIndex:0];
	}
  return camp;
}

- (float) distanceAway {
  ThemeCamp *themeCamp = [self camp];
  if (!themeCamp) {
    return 100;
  }
  float lat = [[themeCamp latitude] floatValue];
  float lon = [[themeCamp longitude] floatValue];
  if (lat == 0 || lon == 0) {
    return 100;
  }
  CLLocation *loc = [[[CLLocation alloc]initWithLatitude:lat  longitude:lon]autorelease];
  return [[MyCLController sharedInstance] currentDistanceToLocation:loc] * 0.000621371192;
}

@end
