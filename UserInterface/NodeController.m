//
//  NodeController.m
//  TrailTracker
//
//  Created by Andrew Johnson on 7/27/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "NodeController.h"
#import "ASIHTTPRequest.h"
//#import "Reachability.h"
#import "CJSONDeserializer.h"
//#import "Networking.h"
//#import "DBOperations.h"
#import "iBurnAppDelegate.h"

@implementation NodeController

@synthesize nodes, delegate;

- (void) updateObject:(id)object withDict:(NSDictionary*)dict {}


- (NSArray*) getNamesFromDicts:(NSArray*)dicts {
  NSMutableArray *names = [[[NSMutableArray alloc] init] autorelease];
  for (NSDictionary *dict in dicts) {
    [names addObject:[dict objectForKey:@"name"]];
  }
  return names;
}  


#define F(N$)  [NSNumber numberWithFloat: (N$)]

- (NSMutableArray*) getPredicateArrayForUpperLeft:(CLLocationCoordinate2D)upperLeft 
                                       lowerRight:(CLLocationCoordinate2D)lowerRight {
  NSPredicate *p = [NSPredicate predicateWithFormat: @"latitude >= %@ AND latitude <= %@", 
                    F(lowerRight.latitude), F(upperLeft.latitude)]; 
  NSPredicate *lonPredicate;
  if (upperLeft.longitude > lowerRight.longitude) {
  	lonPredicate = [NSPredicate predicateWithFormat: @"longitude >= %@ OR longitude <= %@", 
                    [NSNumber numberWithDouble:upperLeft.longitude], 
                    [NSNumber numberWithDouble:lowerRight.longitude]];
  } else {
    lonPredicate = [NSPredicate predicateWithFormat: @"longitude >= %@ AND longitude <= %@", 
                    [NSNumber numberWithDouble:upperLeft.longitude], 
                    [NSNumber numberWithDouble:lowerRight.longitude]];
  }      
  //return [NSMutableArray arrayWithObjects:p, lonPredicate, nil];
  return [[[NSMutableArray alloc]init]autorelease];
}


- (NSArray*)getObjectsForType:(NSString*)type 
                        names:(NSArray*)names
                    upperLeft:(CLLocationCoordinate2D)upperLeft 
                   lowerRight:(CLLocationCoordinate2D)lowerRight {  
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];  
  //NSMutableArray *predicates = [self getPredicateArrayForUpperLeft:(CLLocationCoordinate2D)upperLeft 
//                                                        lowerRight://(CLLocationCoordinate2D)lowerRight];  
  //NSPredicate *finalPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSEntityDescription *entity = [NSEntityDescription entityForName:type inManagedObjectContext:[t managedObjectContext]];
  [fetchRequest setEntity:entity];
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name IN %@", names];
  [fetchRequest setPredicate:predicate];	
  NSError *error;
  NSArray *objects = [[[t managedObjectContext] executeFetchRequest:fetchRequest error:&error]retain];
  [fetchRequest release];
  fetchRequest = nil;
  /*for (KnownPlace *kp in knownPlaces) {    
   Place *place = [[[Place alloc]initWithKnownPlace:kp] autorelease];
   [self tagPlaceWithDistanceAway:place];
   [places addObject:place];
   }*/
  [pool release];
	return objects;
}


- (NSObject*) nullOrObject:(NSObject*)str {
  if (str && [str isEqual:[NSNull null]]) {
    return nil;
  } else return str;
}


- (NSString*) nullStringOrString:(NSString*)str {
  //NSLog(@"hi: %@",str);
  if ([str isEqual:[NSNull null]] || !str || [str isEqualToString:@""]) {
    return @"";
  } else return str;
}


- (void) saveObjects:(NSArray*)objects {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSManagedObjectContext *moc = [t bgMoc];
  [objects retain];
  NSError *error;
  if (![moc save:&error]) {}
  [objects release];
  [pool release];
}


- (void) createAndUpdate:(NSArray*)knownObjects 
             withObjects:(NSArray*)objects 
            forClassName:(NSString*)className {
 	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSManagedObjectContext *moc = [t bgMoc];
  for (NSDictionary *dict in objects) {
    id matchedCamp = nil;
    for (id c in knownObjects) {
      if ([[c bm_id] isEqual:[self nullOrObject:[dict objectForKey:@"id"]]]) {
        matchedCamp = c;
        break;
      }
    }
    if (!matchedCamp) {
      matchedCamp = [NSEntityDescription insertNewObjectForEntityForName:className
                                                  inManagedObjectContext:moc];      
    }
    [self updateObject:matchedCamp withDict:[dict retain]];
    [dict release];
  }
  [self saveObjects:knownObjects];
}  


- (id)init {
	if (self = [super init]) {
		self.nodes = nil;
	}
	return self;
}

  
- (void) dealloc {
  self.nodes = nil;
  [super dealloc];
}


- (NSString *)getUrl {return nil;}


- (void) getNodes {
  [self getNodes:[self getUrl]];  
}

- (NSDictionary*) getLocationDictionary:(NSDictionary*) dict {
  NSObject *locPoint = (NSDictionary*)[self nullOrObject:[dict objectForKey:@"location_point"]];
  NSDictionary* locDict;
  if ([locPoint isKindOfClass:[NSString class]]) {
    NSData *jsonData = [locPoint dataUsingEncoding:NSUTF32BigEndianStringEncoding];	
    locDict =  [[CJSONDeserializer deserializer] deserialize:jsonData error:nil];
  } else {
    locDict = locPoint;
  } 

  return locDict;
    
}

- (void) getNodes:(NSString*) url {
	//if ([[Networking sharedInstance] canConnectToInternet]) {
		ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:url]];
		[request setDelegate:self];
    [request setUsername:@"earthteam"];
    [request setPassword:@"f0rthedust"];
		[request setDidFinishSelector:@selector(requestDone:)];
		[request setDidFailSelector:@selector(requestWentWrong:)];
    [request setTimeOutSeconds:60];
	  [request startAsynchronous];
  //} else {
  //  if (self.delegate) {
  //    [(NSObject*)self.delegate performSelectorOnMainThread:@selector(requestDone) withObject:nil waitUntilDone:YES];
  //  }
  //}    
}


- (void) processJSONThreaded:(ASIHTTPRequest *) request {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];

  NSManagedObjectContext* moc = [t bgMoc];
  
	NSError *error;
	NSData *jsonData = [[request responseString] dataUsingEncoding:NSUTF32BigEndianStringEncoding];	
  NSArray* jsonNodes = [[CJSONDeserializer deserializer] deserialize:jsonData error:&error];
  [moc lock];
  [self getNodesFromJson:jsonNodes];
	if (self.delegate) {
		[(NSObject*)self.delegate performSelectorOnMainThread:@selector(requestDone) withObject:nil waitUntilDone:NO];
	}
  [moc unlock];
  [pool release];
  [request release];
}


- (void) getNodesFromJson:(NSObject*) jsonNodes {}


- (void)requestDone:(ASIHTTPRequest *)request {
  //NSLog(@"response is %@", [request responseString]); 
  [NSThread detachNewThreadSelector:@selector(processJSONThreaded:) toTarget:self withObject:request];
}


- (void)requestWentWrong:(ASIHTTPRequest *)request {
  NSLog(@"ERROR is %@", [request error]); 

  NSLog(@"ERROR is %@", [request responseString]); 
  [request release];
}


@end
