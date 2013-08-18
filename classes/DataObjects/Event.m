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


- (void)awakeFromFetch {
  geolocation = nil;
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
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:[t managedObjectContext]];
  [fetchRequest setEntity:entity];
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"day = %@", day];
  [fetchRequest setPredicate:predicate];	
  NSError *error;
  NSArray *objects = [[t managedObjectContext] executeFetchRequest:fetchRequest error:&error];
  
  
  return objects;
}

+ (Event*) eventForID:(NSNumber*) bm_id {
  
  
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:[t managedObjectContext]];
  [fetchRequest setEntity:entity];
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"bm_id = %@", bm_id];
  [fetchRequest setPredicate:predicate];
  NSError *error;
  NSArray *objects = [[t managedObjectContext] executeFetchRequest:fetchRequest error:&error];
  
  if ([objects count] > 0) {
    return [objects objectAtIndex:0];
  }
  return nil;
  
}

+ (Event*) eventForName:(NSString*) sName {
  
  
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
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
	NSFetchRequest *request = [[NSFetchRequest alloc]init];
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


- (CLLocation *)geolocation {
  if (!geolocation) {
    geolocation = [[CLLocation alloc] initWithLatitude:[self.latitude floatValue] 
                                          longitude:[self.longitude floatValue]];
  }
  return geolocation;
}

- (float) distanceAway {
	// prevent crash at start-up sometimes
  CLLocationManager* locationManager = [[MyCLController sharedInstance] locationManager];
  
  if (!locationManager.location) return 0;
  
  if (geolocation && distanceAway > 0 && lastLatitude == locationManager.location.coordinate.latitude) {
    return distanceAway;
  }
  
  lastLatitude = locationManager.location.coordinate.latitude;
  distanceAway = [locationManager.location distanceFromLocation:[self geolocation]];
  return distanceAway;
}

@end
