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
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
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





@end
