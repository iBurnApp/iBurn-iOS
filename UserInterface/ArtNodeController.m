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

@implementation ArtNodeController

- (NSString *)getUrl {
 	NSString *theString;
	theString = @"http://earth.burningman.com/api/0.1/2010/art/";	
	return theString;
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
    camp.latitude = [coordArray objectAtIndex:1];
    camp.longitude = [coordArray objectAtIndex:0];
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
           forClassName:@"ArtInstall"];
}


@end
