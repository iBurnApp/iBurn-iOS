//
//  CampNodeController.m
//  TrailTracker
//
//  Created by Anna Hentzel on 5/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "CampNodeController.h"
#import "ThemeCamp.h"
#import "iBurnAppDelegate.h"
#import "util.h"
#import "CJSONDeserializer.h"
#import "JSONKit.h"

@implementation CampNodeController


- (NSArray*) getAllThemeCamps {  
  NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"ThemeCamp" inManagedObjectContext:[t managedObjectContext]];
  [fetchRequest setEntity:entity];
 
  NSError *error;
  NSArray *objects = [[t managedObjectContext] executeFetchRequest:fetchRequest error:&error];
  
	return objects;
}

- (void) importDataFromFile:(NSString*)filename {
	NSString *path = [[NSBundle mainBundle] pathForResource:filename ofType:@"json"];
	NSData *fileData = [NSData dataWithContentsOfFile:path];
	NSArray *campArray = [[CJSONDeserializer deserializer] deserialize:fileData error:nil];
	//NSLog(@"The camp array is %@", campArray);
  //CLLocationCoordinate2D dummy = {0,0};
  NSArray *knownCamps = [self getAllThemeCamps];
  
  [self createAndUpdate:knownCamps
            withObjects:campArray 
           forClassName:@"ThemeCamp"
							 fromFile:YES];
}


- (NSString *)getUrl {
 	NSString *theString;
	theString = @"http://playaevents.burningman.com/api/0.2/2012/camp/";
	// theString = @"http://earth.burningman.com/api/0.1/2010/camp/";	
	return theString;
}


- (void) updateObjectFromFile:(id<BurnDataObject>)object withDict:(NSDictionary*)dict {
  ThemeCamp *camp = (ThemeCamp*)object;
  if ([dict objectForKey:@"name"]) {
    camp.name = [self nullStringOrString:[dict objectForKey:@"name"]];
	} else {
    if ([dict objectForKey:@"Name"]) {
      camp.name = [self nullStringOrString:[dict objectForKey:@"Name"]];
    }
  }
	
  camp.simpleName = [ThemeCamp createSimpleName:camp.name];    
  if ([dict objectForKey:@"Latitude"]) {
    camp.latitude = [dict objectForKey:@"Latitude"];
    camp.longitude = [dict objectForKey:@"Longitude"];
  }

  if ([dict objectForKey:@"description"]) {
    camp.desc = [dict objectForKey:@"description"];
    camp.url = [dict objectForKey:@"url"];
    camp.contactEmail = [dict objectForKey:@"contact"];
    camp.location = [dict objectForKey:@"hometown"];
  }

}


- (void) updateObject:(ThemeCamp*)camp withDict:(NSDictionary*)dict {
  camp.bm_id = N([(NSString*)[self nullOrObject:[dict objectForKey:@"id"]] intValue]);
  camp.name = [self nullStringOrString:[dict objectForKey:@"name"]];
  camp.contactEmail = [self nullStringOrString:[dict objectForKey:@"contact_email"]];
  camp.desc = [self nullStringOrString:[dict objectForKey:@"description"]];
  camp.url = [self nullStringOrString:[dict objectForKey:@"url"]];
  camp.simpleName = [ThemeCamp createSimpleName:camp.name];                        

  NSDictionary *locPoint = [self getLocationDictionary:dict];
  if (locPoint) {
    NSArray *coordArray = [locPoint objectForKey:@"coordinates"];
    camp.latitude = [coordArray objectAtIndex:1];
    camp.longitude = [coordArray objectAtIndex:0];
    NSLog(@"%1.5f, %1.5f", [camp.latitude floatValue], [camp.longitude floatValue]);
  }
}


- (void) getNodesFromJson:(NSObject*) jsonNodes {
  NSLog(@"parsing camps");
  NSMutableArray* camps = [NSMutableArray arrayWithArray:(NSArray*)jsonNodes];

  NSArray *knownCamps = [self getAllThemeCamps];
  [self createAndUpdate:knownCamps
            withObjects:camps 
           forClassName:@"ThemeCamp"
							fromFile:NO];
  [self importDataFromFile:@"playaevents-camps-2012"];
	[self importDataFromFile:@"camps-2012"];
  [self importLocationDataFromFile:@"camp-locations-2012" knownCamps:knownCamps];
}

- (void) importLocationDataFromFile:(NSString*)fileName knownCamps:(NSArray*)knownCamps {
  JSONDecoder *decoder = [JSONDecoder decoder];
  NSString *path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"json"];
  NSData *locationData = [NSData dataWithContentsOfFile:path];
  NSError *error = nil;
  NSArray *campLocations = [decoder objectWithData:locationData error:&error];
  
  NSMutableDictionary *campLocDict = [NSMutableDictionary dictionaryWithCapacity:[campLocations count]];
  for (NSDictionary *dictionary in campLocations) {
    NSString *key = [ThemeCamp createSimpleName:[dictionary objectForKey:@"name"]];
    [campLocDict setObject:dictionary forKey:key];
  }
  for (ThemeCamp * c in knownCamps) {
    NSDictionary *locDict = [campLocDict objectForKey:c.simpleName];
    if (locDict) {
      NSNumberFormatter * f = [[[NSNumberFormatter alloc] init] autorelease];
      [f setNumberStyle:NSNumberFormatterDecimalStyle];
      c.latitude =  [f numberFromString:[locDict objectForKey:@"latitude"]];
      c.longitude = [f numberFromString:[locDict objectForKey:@"longitude"]];
    }
  }

  [self saveObjects:knownCamps];
}


- (void) createAndUpdate:(NSArray*)knownObjects 
             withObjects:(NSArray*)objects 
            forClassName:(NSString*)className 
								fromFile:(BOOL)fromFile {
 	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSManagedObjectContext *moc = [t managedObjectContext];
  for (NSDictionary *dict in objects) {
    if (!dict || [dict isEqual:[NSNull null]]) {
      continue;
    }
    id matchedCamp = nil;
    NSString* name = (NSString*)[self nullOrObject:[dict objectForKey:@"title"]];
    if (fromFile) {
      name = (NSString*)[self nullOrObject:[dict objectForKey:@"name"]];
      if (!name) {
        name = (NSString*)[self nullOrObject:[dict objectForKey:@"Name"]];
      }
    }

    NSString * simpleName = [ThemeCamp createSimpleName:name];
		//NSLog(@"The title is %@", [dict objectForKey:@"title"]);
    for (ThemeCamp * c in knownObjects) {
      if ([[c bm_id] isEqual:[self nullOrObject:[dict objectForKey:@"id"]]]
					|| [c.simpleName isEqual:simpleName]) {
        matchedCamp = c;
        break;
      } else if (simpleName && [c.simpleName hasPrefix:simpleName]) {
       // NSLog(@"USING PREFIX name %@ name %@", name, [c name]);

        matchedCamp = c;
        break;
      }
    }
    if (!matchedCamp) {
      if (fromFile) {
        NSLog(@"%@", name);
      } else {
        matchedCamp = [NSEntityDescription insertNewObjectForEntityForName:className
                                                    inManagedObjectContext:moc];  
      }
    }
		if (fromFile) {
      [self updateObjectFromFile:matchedCamp withDict:dict];
		} else {
      [self updateObject:matchedCamp withDict:dict];
		}
  }
  [self saveObjects:knownObjects];
}  


@end
