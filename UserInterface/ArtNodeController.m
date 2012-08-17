//
//  ArtNodeController.m
//  iBurn
//
//  Created by Andrew Johnson on 8/1/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ArtNodeController.h"
#import "ArtInstall.h"
#import "util.h"
#import "CJSONDeserializer.h"
#import "iBurnAppDelegate.h"
#import "ThemeCamp.h"
@implementation ArtNodeController


- (NSArray*) getAllArt {  
  NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"ArtInstall" inManagedObjectContext:[t managedObjectContext]];
  [fetchRequest setEntity:entity];
  
  NSError *error;
  NSArray *objects = [[t managedObjectContext] executeFetchRequest:fetchRequest error:&error];
  
	return objects;
}

- (void) importDataFromFile:(NSString*)filename {
	NSString *path = [[NSBundle mainBundle] pathForResource:filename ofType:@"json"];
	NSData *fileData = [NSData dataWithContentsOfFile:path];
	NSArray *artArray = [[CJSONDeserializer deserializer] deserialize:fileData error:nil];
  //CLLocationCoordinate2D dummy = {0,0};
  NSArray *knownArts = [self getAllArt];
  
  [self createAndUpdate:knownArts
            withObjects:artArray 
           forClassName:@"ArtInstall"
							 fromFile:YES];
}


- (NSString *)getUrl {
 	NSString *theString;
	// theString = @"http://earth.burningman.com/api/0.1/2010/art/";	
	theString = @"http://playaevents.burningman.com/api/0.2/2012/art/";
	return theString;
}


- (void) updateObjectFromFile:(id<BurnDataObject>)object withDict:(NSDictionary*)dict {
  ArtInstall *camp = (ArtInstall*)object;
  
  if ([dict objectForKey:@"latitude"]) {
    camp.latitude = [dict objectForKey:@"latitude"];
    camp.longitude = [dict objectForKey:@"longitude"];
  }
  
  camp.bm_id = N([(NSString*)[self nullOrObject:[dict objectForKey:@"id"]] intValue]);
  
  camp.name = [self nullStringOrString:[dict objectForKey:@"name"]];
  camp.artist = [self nullStringOrString:[dict objectForKey:@"artist"]];
  camp.desc = [self nullStringOrString:[dict objectForKey:@"description"]];
  camp.url = [self nullStringOrString:[dict objectForKey:@"url"]];
  camp.contactEmail = [self nullStringOrString:[dict objectForKey:@"contact_email"]];
  camp.artistHometown = [self nullStringOrString:[dict objectForKey:@"artist_location"]];
	
	
	// camp.location = [dict objectForKey:@"artist_location"];
	// image_url
	
}

- (void) createAndUpdate:(NSArray*)knownObjects 
             withObjects:(NSArray*)objects 
            forClassName:(NSString*)className 
								fromFile:(BOOL)fromFile {
 	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSManagedObjectContext *moc = [t managedObjectContext];
  for (NSDictionary *dict in objects) {
    id matchedCamp = nil;

    NSString* name = (NSString*)[self nullOrObject:[dict objectForKey:@"name"]];
    if (!name) {
      name = (NSString*)[self nullOrObject:[dict objectForKey:@"title"]];
      if (!name) {
        name = (NSString*)[self nullOrObject:[dict objectForKey:@"Name"]];
      }
    }
    NSString* simpleName = [ThemeCamp createSimpleName:name];

    NSNumber* lat = nil;
    if ([dict objectForKey:lat]) {
      lat = [dict objectForKey:lat];
    }
    
		//NSLog(@"The title is %@", [dict objectForKey:@"title"]);
    for (ArtInstall * c in [self getAllArt]) {
      NSString* artSimpleName = [ThemeCamp createSimpleName:[c name]];

      if ([artSimpleName isEqualToString:simpleName]) {
        if (lat && c.latitude && ![c.latitude isEqualToNumber:lat]) continue;
        matchedCamp = c;
        break;
      }
      
    }
    if (!matchedCamp) {
      if (fromFile) {
        NSLog(@"failed to match art %@", name);
      }
      matchedCamp = [NSEntityDescription insertNewObjectForEntityForName:className
                                                    inManagedObjectContext:moc];  
    }
		if (fromFile) {
      [self updateObjectFromFile:matchedCamp withDict:dict];
		} else {
      [self updateObject:matchedCamp withDict:dict];
		}
  }
  [self saveObjects:knownObjects];
}  


- (void) updateObject:(ArtInstall*)camp withDict:(NSDictionary*)dict {
  camp.bm_id = N([(NSString*)[self nullOrObject:[dict objectForKey:@"id"]] intValue]);

  camp.name = [self nullStringOrString:[dict objectForKey:@"name"]];
  camp.artist = [self nullStringOrString:[dict objectForKey:@"artist"]];
  camp.desc = [self nullStringOrString:[dict objectForKey:@"description"]];
  camp.url = [self nullStringOrString:[dict objectForKey:@"url"]];
  camp.contactEmail = [self nullStringOrString:[dict objectForKey:@"contact_email"]];
  camp.artistHometown = [self nullStringOrString:[dict objectForKey:@"artist_location"]];

  NSDictionary *locPoint = [self getLocationDictionary:dict];
  if (locPoint) {
    //NSArray *coordArray = [locPoint objectForKey:@"coordinates"];
    //camp.latitude = [coordArray objectAtIndex:1];
    //camp.longitude = [coordArray objectAtIndex:0];
    NSLog(@"%1.5f, %1.5f", [camp.latitude floatValue], [camp.longitude floatValue]);
  }

  //NSLog(@"dict: %@", dict);
  //camp.location = [NSString stringWithFormat:@"%1.5f, %1.5f", [camp.latitude floatValue], [camp.longitude floatValue]];
}


- (void) getNodesFromJson:(NSObject*) jsonNodes {
  NSMutableArray* arts = [NSMutableArray arrayWithArray:(NSArray*)jsonNodes];
  CLLocationCoordinate2D dummy = {0,0};
  NSArray *knownArts = [self getObjectsForType:@"ArtInstall" 
                                          names:[self getNamesFromDicts:arts] 
                                      upperLeft:dummy 
                                     lowerRight:dummy];
  [self createAndUpdate:knownArts
            withObjects:arts 
           forClassName:@"ArtInstall"
							 fromFile:NO];
  [self importDataFromFile:@"art_data_and_locations"];
}


@end
