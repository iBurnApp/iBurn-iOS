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

@implementation CampNodeController


- (NSArray*) getAllThemeCamps {  
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"ThemeCamp" inManagedObjectContext:[t managedObjectContext]];
  [fetchRequest setEntity:entity];
 
  NSError *error;
  NSArray *objects = [[t managedObjectContext] executeFetchRequest:fetchRequest error:&error];
  
	return objects;
}


- (NSString *)getUrl {
    return @"https://s3.amazonaws.com/uploads.hipchat.com/24265/137546/nrep0cpx19y3m26/camp_data_and_locations_ids.json";
}


- (void) createObjectFromDict:(NSDictionary*)dict {
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSManagedObjectContext *moc = [t managedObjectContext];
  ThemeCamp *camp = [NSEntityDescription insertNewObjectForEntityForName:@"ThemeCamp"
                                              inManagedObjectContext:moc];
  
  if ([dict objectForKey:@"name"]) {
    camp.name = [self nullStringOrString:[dict objectForKey:@"name"]];
	} else {
    if ([dict objectForKey:@"Name"]) {
      camp.name = [self nullStringOrString:[dict objectForKey:@"Name"]];
    }
  }
	
  camp.bm_id = N([dict objectForKey:@"id"]);
  if ([dict objectForKey:@"latitude"]) {
    NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];
    camp.latitude =  [f numberFromString:[dict objectForKey:@"latitude"]];
    camp.longitude = [f numberFromString:[dict objectForKey:@"longitude"]];
  }
  if ([dict objectForKey:@"location"]) {
    camp.playaLocation = [self nullStringOrString:[dict objectForKey:@"location"]];
  }

  if ([dict objectForKey:@"description"]) {
    camp.desc = [self nullStringOrString:[dict objectForKey:@"description"]];
    camp.url = [self nullStringOrString:[dict objectForKey:@"url"]];
    camp.contactEmail = [self nullStringOrString:[dict objectForKey:@"contact_email"]];
    camp.location = [self nullStringOrString:[dict objectForKey:@"hometown"]];
  }

}









@end
