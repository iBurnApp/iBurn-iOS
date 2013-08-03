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

- (void) importDataFromFile:(NSString*)filename {
	NSString *path = [[NSBundle mainBundle] pathForResource:filename ofType:@"json"];
	NSData *fileData = [NSData dataWithContentsOfFile:path];
	NSArray *campArray = [[CJSONDeserializer deserializer] deserialize:fileData error:nil];
	//NSLog(@"The camp array is %@", campArray);
  //CLLocationCoordinate2D dummy = {0,0};
  
  [self createAndUpdate:campArray];
}


- (NSString *)getUrl {
    // 
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
