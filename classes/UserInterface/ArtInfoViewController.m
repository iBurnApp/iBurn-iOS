//
//  ArtInfoViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-18.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "ArtInfoViewController.h"
#import "ArtInstall.h"
#import "Favorite.h"
#import "ArtTableViewController.h"
#import "iBurnAppDelegate.h"
#import "MyCLController.h"
#import "MapViewController.h"
#import "util.h"

@implementation ArtInfoViewController


- (void) showOnMap {
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  [[t tabBarController]setSelectedViewController:[[[t tabBarController]viewControllers]objectAtIndex:0]];
  [[[[t tabBarController]viewControllers]objectAtIndex:0] popToRootViewControllerAnimated:YES];
  MapViewController *mapViewController = (MapViewController*)[[[[t tabBarController]viewControllers]objectAtIndex:0]visibleViewController];
  [Favorite setSelected:@"ArtInstall" id:art.bm_id];

  [mapViewController showMapForObject:art];
}


- (void) setupViewInfo {
  NSMutableArray *tempTitles = [[NSMutableArray alloc]init];
  NSMutableArray *tempTexts = [[NSMutableArray alloc]init];
  if (art.name && ![art.name isEqualToString:@""]) {
    [tempTitles addObject:@"Name"];
    if ([art.latitude floatValue] > 1 
        && [art.longitude floatValue] < -1) {
      CLLocation *loc = [[CLLocation alloc]initWithLatitude:[art.latitude floatValue] longitude:[art.longitude floatValue]];
      float distanceAway = [[MyCLController sharedInstance] currentDistanceToLocation:loc];
      if (distanceAway > 0) {
        [tempTexts addObject:[art.name stringByAppendingFormat:@" (%@)", [util distanceString:distanceAway convertMax:1000 includeUnit:YES decimalPlaces:2]]];
      } else {
        [tempTexts addObject:art.name];
      }      
    } else {      
      [tempTexts addObject:art.name];
    }
  }
  if (art.artist && ![art.artist isEqualToString:@""]) {
    [tempTitles addObject:@"Artist"];
    [tempTexts addObject:art.artist];
  }
  if (art.url && ![art.url isEqualToString:@""]) {
    [tempTitles addObject:@"URL"];
    if ([art.url rangeOfString:@"http://"].location == NSNotFound) {
      art.url = [@"http://" stringByAppendingString:art.url]; 
    }
    [tempTexts addObject:art.url];
  }
  if (art.contactEmail && ![art.contactEmail isEqualToString:@""]) {
    [tempTitles addObject:@"Contact Email"];
    [tempTexts addObject:art.contactEmail];
  }
  if (art.artistHometown && ![art.artistHometown isEqualToString:@""]) {
    [tempTitles addObject:@"Artist Hometown"];
    [tempTexts addObject:art.artistHometown];
  }
  if ([art.latitude floatValue] > 1 
      && [art.longitude floatValue] < -1) {
    [tempTitles addObject:@"Coordinates"];
			NSString *locString = [NSString stringWithFormat:@"%1.5f, %1.5f",[art.latitude floatValue], [art.longitude floatValue]];
			[tempTexts addObject:locString];
  }
  if (art.desc && ![art.desc isEqualToString:@""] ) {
    [tempTitles addObject:@"Description"];
    [tempTexts addObject:art.desc];
  }  
  cellTexts = tempTexts;
  headerTitles = tempTitles;
  
  
}

- (id)initWithArt:(ArtInstall*)artInstall {
	self = [super initWithTitle:artInstall.name];
	art = artInstall;
  [self setupViewInfo];
  return self;
}


- (CGFloat)tableView:(UITableView *)tb heightForRowAtIndexPath:(NSIndexPath *) indexPath {
  return [super tableView:tb heightForRowAtIndexPath:indexPath object:art];  
}



- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void) addToFavorites: (id) sender {
  [Favorite addFavorite:@"ArtInstall" id:art.bm_id];

}


@end