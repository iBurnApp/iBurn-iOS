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
	NSArray *artArray = [[[CJSONDeserializer deserializer] deserialize:fileData error:nil]retain];
  CLLocationCoordinate2D dummy = {0,0};
  NSArray *knownArts = [self getAllArt];
  
  [self createAndUpdate:knownArts
            withObjects:artArray 
           forClassName:@"ArtInstall"
							 fromFile:YES];
}


- (NSString *)getUrl {
 	NSString *theString;
	// theString = @"http://earth.burningman.com/api/0.1/2010/art/";	
	theString = @"http://playaevents.burningman.com/api/0.2/2011/art/";
	return theString;
}


- (void) updateObjectFromFile:(ArtInstall*)camp withDict:(NSDictionary*)dict {
  if (!camp.name) {
    camp.name = [self nullStringOrString:[dict objectForKey:@"title"]];
  }
  
  if ([dict objectForKey:@"lat"]) {
    camp.latitude = [dict objectForKey:@"lat"];
    camp.longitude = [dict objectForKey:@"lon"];
  }

  if ([dict objectForKey:@"description"]) {
    camp.desc = [dict objectForKey:@"description"];
    camp.url = [dict objectForKey:@"url"];
    camp.contactEmail = [dict objectForKey:@"contact"];
    NSString *artists = @"by ";
    int x = 0;
    for (NSString *name in [dict objectForKey:@"artists"]) {
      artists = [artists stringByAppendingString:name];
      if (x != [[dict objectForKey:@"artists"]count]-1) {
        artists = [artists stringByAppendingString:@", "];
      }
      x++;
    }
    if(![artists isEqualToString:@"by "]) {
      camp.artist = [self nullStringOrString:artists];
    }
  }
	
	
	//camp.location = [dict objectForKey:@"artist_location"];
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

    NSString* name = [self nullOrObject:[dict objectForKey:@"name"]];
    if (!name) {
      name = [self nullOrObject:[dict objectForKey:@"title"]];
      if (!name) {
        name = [self nullOrObject:[dict objectForKey:@"Name"]];
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
  camp.bm_id = N([[self nullOrObject:[dict objectForKey:@"id"]] intValue]);

  camp.name = [self nullStringOrString:[dict objectForKey:@"name"]];
  camp.artist = [self nullStringOrString:[dict objectForKey:@"artist"]];
  camp.desc = [self nullStringOrString:[dict objectForKey:@"description"]];
  camp.url = [self nullStringOrString:[dict objectForKey:@"url"]];
  camp.contactEmail = [self nullStringOrString:[dict objectForKey:@"contact_email"]];

  NSDictionary *locPoint = [self getLocationDictionary:dict];
  if (locPoint) {
    NSArray *coordArray = [locPoint objectForKey:@"coordinates"];
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
	[self importDataFromFile:@"allart_public"];
	[self importDataFromFile:@"art-info"];
}


@end
