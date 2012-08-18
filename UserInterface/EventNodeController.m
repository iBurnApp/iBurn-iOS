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
#import "CJSONDeserializer.h"

@implementation EventNodeController
@synthesize eventDateHash;


- (id) init {
  self = [super init];
  return self;
}

  
- (NSString *)getUrl {
 	NSString *theString;

	//theString = @"http://earth.burningman.com/api/0.1/2010/event/";	
	theString = @"http://playaevents.burningman.com/api/0.2/2012/event/";	
	return theString;
}


- (NSDate*) getDateFromString:(NSString*)dateString {
  if (!dateString ||[dateString length] < 8) {
		return nil;
	}
  static NSDateFormatter *gpxDateFormatter;
  if (!gpxDateFormatter) {
    gpxDateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale;
    enUSPOSIXLocale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
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
    [eventDateHash setValue:[[[NSMutableArray alloc]init]autorelease] forKey:dow];
    //NSLog(@"Making new array %@",dow);
  }
  if (dow) [[eventDateHash objectForKey:dow]addObject:event];  
}


- (void) updateObject:(Event*)event withDict:(NSDictionary*)dict occurenceIndex:(int)idx {
  NSObject *bmid = [self nullOrObject:[dict objectForKey:@"id"]];
  if (bmid) event.bm_id = N([(NSString*)bmid intValue]);

  event.name = [self nullStringOrString:[dict objectForKey:@"title"]];
  NSDictionary *locPoint = [self getLocationDictionary:dict];
  if (locPoint) {
    NSArray *coordArray = [locPoint objectForKey:@"coordinates"];
    event.latitude = [coordArray objectAtIndex:1];
    event.longitude = [coordArray objectAtIndex:0];
    //NSLog(@"%1.5f, %1.5f", [event.latitude floatValue], [event.longitude floatValue]);
  }
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
  event.allDay = B([[self nullOrObject:[dict objectForKey:@"all_day"]] boolValue]);
 
  NSDictionary* hostDict =  (NSDictionary*)[self nullOrObject:[dict objectForKey:@"hosted_by_camp"]];
  if (!hostDict) return;
  event.campHost = [hostDict objectForKey:@"name"];
  NSString* campSimpleName = [ThemeCamp createSimpleName:event.campHost];
  ThemeCamp* camp = [ThemeCamp campForSimpleName:campSimpleName];
  //NSLog(@"camp match %@ %@", [camp name], camp.latitude);
  event.latitude = camp.latitude;
  event.longitude = camp.longitude;
  event.camp_id = N([[hostDict objectForKey:@"id"] intValue]);
}


- (void) getNodesFromJson:(NSObject*) jsonNodes {
  //NSLog(@"%@", jsonNodes);
  NSLog(@"parsing events");
  NSMutableArray* arts = [NSMutableArray arrayWithArray:(NSArray*)jsonNodes];
  NSSortDescriptor *lastDescriptor =
  [[[NSSortDescriptor alloc] initWithKey:@"start_time"
                               ascending:YES
                                selector:@selector(compare:)] autorelease];
  NSArray *descriptors = [NSArray arrayWithObjects:lastDescriptor, nil];
  NSArray *sortedArray = [arts sortedArrayUsingDescriptors:descriptors];
  CLLocationCoordinate2D dummy = {0,0};
  NSArray *events = [self getObjectsForType:@"Event" 
                                         names:[self getNamesFromDicts:sortedArray] 
                                     upperLeft:dummy 
                                    lowerRight:dummy];
  [self createAndUpdate:events
            withObjects:sortedArray 
           forClassName:@"Event"];
  /*
  NSString *path = [[NSBundle mainBundle] pathForResource:@"event_data_and_locations" ofType:@"json"];
	NSData *fileData = [NSData dataWithContentsOfFile:path];
	NSArray *eventArray = [[CJSONDeserializer deserializer] deserialize:fileData error:nil];
 
  [self createAndUpdate:events
            withObjects:eventArray
           forClassName:@"Event"];
   */
}

- (NSArray*) getNamesFromDicts:(NSArray*)dicts {
  NSMutableArray *names = [[[NSMutableArray alloc] init] autorelease];
  for (NSDictionary *dict in dicts) {
    [names addObject:[dict objectForKey:@"title"]];
  }
  return names;
}  


- (void) createAndUpdate:(NSArray*)knownObjects 
             withObjects:(NSArray*)objects 
            forClassName:(NSString*)className {
 	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSManagedObjectContext *moc = [t managedObjectContext];
  //[self.eventDateHash removeAllObjects];
  for (NSDictionary *dict in objects) {
    id matchedCamp = nil;
    if (knownObjects && [knownObjects isKindOfClass:[NSArray class]]) {
      for (id c in knownObjects) {
        if ([c respondsToSelector:@selector(bm_id)]) {
          if ([[c bm_id] isEqual:[self nullOrObject:[dict objectForKey:@"id"]]]) {
            matchedCamp = c;
            break;
          }
        }
      }
    }
    if (!matchedCamp) {
      matchedCamp = [NSEntityDescription insertNewObjectForEntityForName:className
                                                  inManagedObjectContext:moc]; 
      [self updateObject:matchedCamp withDict:dict occurenceIndex:0];
      NSArray* occurrenceSet = (NSArray*)[self nullOrObject:[dict objectForKey:@"occurrence_set"]];
      if (occurrenceSet && [occurrenceSet count] > 0) {
        for (int i = 1; i < [occurrenceSet count]; i++) {
          matchedCamp = [NSEntityDescription insertNewObjectForEntityForName:className
                                                      inManagedObjectContext:moc]; 
          [self updateObject:matchedCamp withDict:dict occurenceIndex:i];
        }
      }
           
    } else { 
      [self updateObject:matchedCamp withDict:dict];
    }
  }
  [self saveObjects:knownObjects];
}  


- (void) loadDBEvents {
  if (self.eventDateHash) return;
  eventDateHash = [[NSMutableDictionary alloc]init];

	iBurnAppDelegate *iBurnDelegate = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSManagedObjectContext *moc = [iBurnDelegate managedObjectContext];
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Event"
																											 inManagedObjectContext:moc];
	NSFetchRequest *request = [[[NSFetchRequest alloc]init]autorelease];
	[request setEntity:entityDescription];
	NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
	[request setSortDescriptors:[NSArray arrayWithObject:sort]];
	[sort release];
	NSError *error;
	NSArray *events = [moc executeFetchRequest:request error:&error];
	if(events == nil || [events count] == 0) {
		//NSLog(@"Fetch failed with error: %@", error);
	} else {
    NSSortDescriptor *lastDescriptor =
    [[[NSSortDescriptor alloc] initWithKey:@"startTime"
                                 ascending:YES
                                  selector:@selector(compare:)] autorelease];
    NSArray *descriptors = [NSArray arrayWithObjects:lastDescriptor, nil];
    NSArray *sortedArray = [events sortedArrayUsingDescriptors:descriptors];
    for (Event* event in sortedArray) {
      [self addEventToHash:event];
    }
  }
}





@end
