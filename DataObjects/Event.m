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
@implementation Event 

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

@end
