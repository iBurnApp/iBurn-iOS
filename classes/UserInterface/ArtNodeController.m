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


- (NSString *)getUrl {
 	NSString *theString;
	// theString = @"http://earth.burningman.com/api/0.1/2010/art/";	
	theString = @"http://playaevents.burningman.com/api/0.2/2012/art/";
	return theString;
}


- (void) createObjectFromDict:(NSDictionary*)dict {
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSManagedObjectContext *moc = [t managedObjectContext];
  ArtInstall *artInstall = [NSEntityDescription insertNewObjectForEntityForName:@"ArtInstall"
                                                  inManagedObjectContext:moc];
  if ([dict objectForKey:@"latitude"]) {
    artInstall.latitude = [dict objectForKey:@"latitude"];
    artInstall.longitude = [dict objectForKey:@"longitude"];
  }
  
  artInstall.bm_id = N([(NSString*)[self nullOrObject:[dict objectForKey:@"id"]] intValue]);
  
  artInstall.name = [self nullStringOrString:[dict objectForKey:@"name"]];
  artInstall.artist = [self nullStringOrString:[dict objectForKey:@"artist"]];
  artInstall.desc = [self nullStringOrString:[dict objectForKey:@"description"]];
  artInstall.url = [self nullStringOrString:[dict objectForKey:@"url"]];
  artInstall.contactEmail = [self nullStringOrString:[dict objectForKey:@"contact_email"]];
  artInstall.artistHometown = [self nullStringOrString:[dict objectForKey:@"artist_location"]];
	
	
	// camp.location = [dict objectForKey:@"artist_location"];
	// image_url
	
}





@end
