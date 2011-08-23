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
		[self.tabBarItem initWithTitle:self.title image:[UIImage imageNamed:@"camps.png"] tag:0];
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
