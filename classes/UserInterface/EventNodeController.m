//
//  EventNodeController.m
//  iBurn
//
//  Created by Andrew Johnson on 8/1/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "EventNodeController.h"
#import "Event.h"
#import "iBurnAppDelegate.h"
#import "util.h"
#import "ThemeCamp.h"
#import "NSManagedObject_util.h"
#import "JSONKit.h"

@implementation EventNodeController
@synthesize eventDateHash;


- (id) init {
  self = [super init];
  return self;
}

  
- (NSString *)getUrl {
 	return @"https://s3.amazonaws.com/uploads.hipchat.com/24265/137546/r6dbjfjzdlcoxda/event_data_and_locations.json";
}


- (NSDate*) getDateFromString:(NSString*)dateString {
  if (!dateString ||[dateString length] < 8) {
		return nil;
	}
  static NSDateFormatter *gpxDateFormatter;
  if (!gpxDateFormatter) {
    gpxDateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale;
    enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [gpxDateFormatter setLocale:enUSPOSIXLocale];
	  [gpxDateFormatter setDateFormat:@"yyyy-MM-dd' 'HH:mm:ss"];
    [gpxDateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"MDT"]];
  }
  NSDate* date = [gpxDateFormatter dateFromString:dateString];
  //NSLog(@"%@", date);
  return date;
}	



- (void) addEventToHash:(Event*)event {
  static NSDateFormatter *dateFormatter = nil;
  if (dateFormatter == nil) {
    dateFormatter = [[NSDateFormatter alloc]init]; 
    [dateFormatter setDateFormat:@"dd"];
  }
 
  NSString *dow = [dateFormatter stringFromDate:event.startTime];
  if (dow && ![eventDateHash objectForKey:dow]) {
    [eventDateHash setValue:[[NSMutableArray alloc]init] forKey:dow];
    //NSLog(@"Making new array %@",dow);
  }
  if (dow) [[eventDateHash objectForKey:dow]addObject:event];  
}

- (ThemeCamp*) getThemeCamp:(NSArray*) themeCamps campId:(int)campId {
  for (ThemeCamp * tc in themeCamps) {
    if (campId == [tc.bm_id intValue]) {
      return tc;
    }
  }
  
  return nil;
}

- (void) updateObject:(Event*)event withDict:(NSDictionary*)dict occurenceIndex:(int)idx themeCamps:(NSArray*)themeCamps {
  NSObject *bmid = [self nullOrObject:[dict objectForKey:@"id"]];
  if (bmid) event.bm_id = N([(NSString*)bmid intValue]);

  event.name = [self nullStringOrString:[dict objectForKey:@"title"]];
 
  event.desc = [self nullStringOrString:[dict objectForKey:@"print_description"]];
  NSArray* occurrenceSet = (NSArray*)[self nullOrObject:[dict objectForKey:@"occurrence_set"]];
  if (occurrenceSet && [occurrenceSet count] > 0) {
    NSDictionary* times =  (NSDictionary*)[occurrenceSet objectAtIndex:idx];
    NSDate *startTime = [self getDateFromString:[times objectForKey:@"start_time"]];
    event.startTime = startTime;
    event.day = [Event getDay:event.startTime];

    event.endTime = [self getDateFromString:[times objectForKey:@"end_time"]];
    [self addEventToHash:event];
  }
  
  BOOL allDay = [(NSNumber*)[self nullOrObject:[dict objectForKey:@"all_day"]]boolValue];
  event.allDay = [NSNumber numberWithBool:allDay];
 
  NSDictionary* hostDict =  (NSDictionary*)[self nullOrObject:[dict objectForKey:@"hosted_by_camp"]];
  if (!hostDict) return;
  event.campHost = [hostDict objectForKey:@"name"];
  event.camp_id = N([[hostDict objectForKey:@"id"] intValue]);

  event.latitude = F([[dict objectForKey:@"latitude"] floatValue]);
  event.longitude = F([[dict objectForKey:@"longitude"] floatValue]);
}





- (NSArray*) getNamesFromDicts:(NSArray*)dicts {
  NSMutableArray *names = [[NSMutableArray alloc] init];
  for (NSDictionary *dict in dicts) {
    [names addObject:[dict objectForKey:@"title"]];
  }
  return names;
}  


- (void) createAndUpdate:objects {
  NSSortDescriptor *lastDescriptor =
  [[NSSortDescriptor alloc] initWithKey:@"start_time"
                              ascending:YES
                               selector:@selector(compare:)];
  
  NSArray *events = [objects sortedArrayUsingDescriptors:@[lastDescriptor]];
  
 	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSManagedObjectContext *moc = [t managedObjectContext];
  
  [self.eventDateHash removeAllObjects];
  //NSArray * themeCamps = [ThemeCamp allObjectsForEntity:@"ThemeCamp" inManagedObjectContext:moc];
  NSArray * themeCamps = nil;
  int i = 0;
  for (NSDictionary *dict in events) {
    
    Event * event = [NSEntityDescription insertNewObjectForEntityForName:@"Event"
                                                  inManagedObjectContext:moc];
    [self updateObject:event withDict:dict occurenceIndex:0 themeCamps:(NSArray*)themeCamps];
    NSArray* occurrenceSet = (NSArray*)[self nullOrObject:[dict objectForKey:@"occurrence_set"]];
    if (occurrenceSet && [occurrenceSet count] > 0) {
      for (int i = 1; i < [occurrenceSet count]; i++) {
        event = [NSEntityDescription insertNewObjectForEntityForName:@"Event"
                                              inManagedObjectContext:moc];
        [self updateObject:event withDict:dict occurenceIndex:i themeCamps:(NSArray*)themeCamps];
      }
    }
    if ((i++ % 500) == 0) {
      [self saveObjects:nil];
      [moc reset];

    }
  }
  
  [self saveObjects:nil];
}


- (void) loadDBEvents {
  if (self.eventDateHash) return;
  eventDateHash = [[NSMutableDictionary alloc]init];

	iBurnAppDelegate *iBurnDelegate = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSManagedObjectContext *moc = [iBurnDelegate managedObjectContext];
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Event"
																											 inManagedObjectContext:moc];
	NSFetchRequest *request = [[NSFetchRequest alloc]init];
	[request setEntity:entityDescription];
	NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
	[request setSortDescriptors:[NSArray arrayWithObject:sort]];
	NSError *error;
	NSArray *events = [moc executeFetchRequest:request error:&error];
	if(events == nil || [events count] == 0) {
		//NSLog(@"Fetch failed with error: %@", error);
	} else {
    NSSortDescriptor *lastDescriptor =
    [[NSSortDescriptor alloc] initWithKey:@"startTime"
                                 ascending:YES
                                  selector:@selector(compare:)];
    NSArray *descriptors = [NSArray arrayWithObjects:lastDescriptor, nil];
    NSArray *sortedArray = [events sortedArrayUsingDescriptors:descriptors];
    for (Event* event in sortedArray) {
      [self addEventToHash:event];
    }
  }
}





@end
