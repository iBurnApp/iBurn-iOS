//
//  ArtTableViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-24.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "ArtTableViewController.h"
#import "ArtInstall.h"
#import "ArtInfoViewController.h"
#import "DetailTableCell.h"
#import "iBurnAppDelegate.h"
#import "RMMapView.h"
#import "Favorite.h"

@implementation ArtTableViewController

- (void) sortByName { 
  [self sortByNameForEntity:@"ArtInstall"];
}


- (void) makeObjectsForFavs:(NSArray*)favs {
	for (Favorite *f in favs) {
		if ([f ArtInstall]) {
			[objects addObject:[f ArtInstall]];
		}
	}
}


- (void) requestDone {
  [super loadObjectsForEntity:@"ArtInstall"];
  [self.tableView reloadData];
}


- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
  [super loadObjectsForEntity:@"ArtInstall"];
}


- (id)init {
	if (self = [super initWithSearchPlaceholder:@"search art installations"]) {
		[self.tabBarItem initWithTitle:self.title image:[UIImage imageNamed:@"art2.png"] tag:0];
		self.title = @"Art";
		[self.navigationItem setTitle:@"Art Installations"];
	}
  return self;
}



- (void) showOnMapForIndexPath {
	int campIndex = [touchedIndexPath indexAtPosition: [touchedIndexPath length] - 1];
	ArtInstall *camp = [objects objectAtIndex: campIndex];
  CLLocationCoordinate2D point;
	point.latitude = [camp.latitude floatValue]; //Center of 2009 City
  point.longitude = [camp.longitude floatValue];
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  RMMapView* mapView = [[[[[t tabBarController]viewControllers]objectAtIndex:0]visibleViewController] view]; 
  [mapView moveToLatLong:point];                
  [[mapView contents] setZoom:16.0];
  [[t tabBarController]setSelectedIndex:0];
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	int artIndex = [indexPath indexAtPosition: [indexPath length] - 1];
	ArtInstall *art = [objects objectAtIndex: artIndex];
	ArtInfoViewController *artInfoView = [[[ArtInfoViewController alloc] initWithArt:art]autorelease];
	[[self navigationController] pushViewController:artInfoView animated:YES];
}


- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *MyIdentifier = @"MyIdentifier";
	DetailTableCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
	if (cell == nil) {
		cell = [[[DetailTableCell alloc] initWithFrame:CGRectZero reuseIdentifier:MyIdentifier] autorelease];
	}
	int storyIndex = [indexPath indexAtPosition: [indexPath length] - 1];
	if (objectDict) {
		cell.textLabel.text = [[[objectDict  objectAtIndex: indexPath.section]objectAtIndex:indexPath.row]name];
	} else {
		cell.textLabel.text = [[objects objectAtIndex: storyIndex]name];
	}
	return cell;	
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end

