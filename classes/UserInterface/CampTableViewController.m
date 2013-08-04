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
#import "util.h"
#import "NSManagedObject_util.h"

@implementation CampTableViewController

//@synthesize mapDelegate;



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
    UITabBarItem *tabBarItem = [[UITabBarItem alloc] initWithTitle:self.title image:[UIImage imageNamed:@"camps.png"] tag:0];
		self.tabBarItem = tabBarItem;
		self.title = @"Camps";
    self.objectType = @"ThemeCamp";
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
	CampInfoViewController *campInfoView = [[CampInfoViewController alloc] initWithCamp:camp];
	[[self navigationController] pushViewController:campInfoView animated:YES];
}


- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *MyIdentifier = @"MyIdentifier";
	DetailTableCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
	if (cell == nil) {
		cell = [[DetailTableCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:MyIdentifier];
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
  if (distanceAway > 0 && distanceAway < 10000000) {
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", 
                            [util distanceString:camp.distanceAway convertMax:1000 includeUnit:YES decimalPlaces:2]];
  } else {
    cell.detailTextLabel.text = @"";
  }

  
	return cell;	
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end
