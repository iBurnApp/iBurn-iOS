//
//  CampTableViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-12.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "CampTableViewController.h"
#import "ThemeCamp.h"
#import "CampInfoViewController.h"
#import "iBurnAppDelegate.h"
#import "RMMapView.h"
#import "Favorite.h"

@implementation CampTableViewController

//@synthesize mapDelegate;

- (void) makeObjectsForFavs:(NSArray*)favs {
	for (Favorite *f in favs) {
		if ([f ThemeCamp]) {
			[objects addObject:[f ThemeCamp]];
		}
	}
}


- (void) sortByName { 
  [self sortBySimpleNameForEntity:@"ThemeCamp"];
}


- (void) requestDone {
  [super loadObjectsForEntity:@"ThemeCamp"];
  [self.tableView reloadData];
}


- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
  if (!objects) {
    [super loadObjectsForEntity:@"ThemeCamp"];
  }
}


- (id)init {
	if(self = [super initWithSearchPlaceholder:@"search theme camps"]) {
    UITabBarItem *tabBarItem = [[[UITabBarItem alloc] initWithTitle:self.title image:[UIImage imageNamed:@"camps.png"] tag:0] autorelease];
		self.tabBarItem = tabBarItem;
		self.title = @"Camps";
		[self.navigationItem setTitle:@"Theme Camps"];
	}
  return self;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  ThemeCamp *camp;
  if (objectDict) {
    camp = [[objectDict objectAtIndex: indexPath.section]objectAtIndex:indexPath.row];
	} else {
    int campIndex = [indexPath indexAtPosition: [indexPath length] - 1];
    camp = [objects objectAtIndex: campIndex];
	}
	CampInfoViewController *campInfoView = [[[CampInfoViewController alloc] initWithCamp:camp]autorelease];
	[[self navigationController] pushViewController:campInfoView animated:YES];
}


- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *MyIdentifier = @"MyIdentifier";
	DetailTableCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
	if (cell == nil) {
		cell = [[[DetailTableCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:MyIdentifier] autorelease];
	}
	int storyIndex = [indexPath indexAtPosition: [indexPath length] - 1];
  ThemeCamp *camp = nil;
  
	if (objectDict) {
    camp = [[objectDict  objectAtIndex: indexPath.section]objectAtIndex:indexPath.row];
	} else {
    camp = [objects objectAtIndex: storyIndex];
	}
  cell.textLabel.text = camp.name;
  float distanceAway = camp.distanceAway;
  if (distanceAway >= 0 && distanceAway < 50) {
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%1.2f miles", camp.distanceAway];
  } else {
    cell.detailTextLabel.text = @"Unknown Location";
  }
  
	return cell;	
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end
