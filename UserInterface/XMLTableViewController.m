//
//  XMLTableViewController.m
//  iBurn
//
//  Created by Andrew Johnson on 6/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "XMLTableViewController.h"
#import "ThemeCamp.h"
#import "iBurnAppDelegate.h"
#import "MyCLController.h"

@implementation XMLTableViewController

- (void) sortByDistance { 
	[self sortByName];
	for (id object in objects) {
		CLLocation *loc = [[[CLLocation alloc]initWithLatitude:[[object latitude] floatValue] longitude:[[object longitude] floatValue]]autorelease];
		[object setDistanceAway:[loc distanceFromLocation:[MyCLController sharedInstance].locationManager.location]*0.000621371192];		
	}
	NSSortDescriptor *sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"distanceAway"
																																	ascending:YES] autorelease];
	NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
	NSArray * newObjects = [objects sortedArrayUsingDescriptors:sortDescriptors];
	[objects release];
	objects = [newObjects retain];
}


- (void) sortByNameForEntity:(NSString*)entityName { 
	iBurnAppDelegate *iBurnDelegate = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSManagedObjectContext *moc = [iBurnDelegate managedObjectContext];
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:entityName
																											 inManagedObjectContext:moc];
	NSFetchRequest *request = [[[NSFetchRequest alloc]init]autorelease];
	[request setEntity:entityDescription];
	NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
	[request setSortDescriptors:[NSArray arrayWithObject:sort]];
	[sort release];
	NSError *error;
	objects = [(NSMutableArray*)[moc executeFetchRequest:request error:&error]retain];
	if(objects == nil) {
		NSLog(@"Fetch failed with error: %@", error);
	}	
}


- (void) sortByFavorites { 
	iBurnAppDelegate *iBurnDelegate = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSManagedObjectContext *moc = [iBurnDelegate managedObjectContext];
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Favorite" 
																											 inManagedObjectContext:moc];
	NSFetchRequest *request = [[[NSFetchRequest alloc]init]autorelease];
	[request setEntity:entityDescription];
	NSError *error;
	NSArray *favs = [moc executeFetchRequest:request error:&error];
	if(favs == nil) {
		NSLog(@"Fetch failed with error: %@", error);
	}
	[objects release];
  objects = [[NSMutableArray alloc]init];
	[self makeObjectsForFavs:favs];
}




- (void) sortTable:(id)sender {
	switch ([sender selectedSegmentIndex]) {
    case 0:  // name
			[self sortByName];
      break;
    case 1:  // distance
			[self sortByDistance];
      break;
    default: // favorites
			[self sortByFavorites];
      break;
  }  
  [self.tableView reloadData];
}


- (void) showOnMapForIndexPath {
	int index = [touchedIndexPath indexAtPosition: [touchedIndexPath length] - 1];
	id obj = [objects objectAtIndex: index];
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  [[t tabBarController]setSelectedViewController:[[[t tabBarController]viewControllers]objectAtIndex:0]];
  [[[[[t tabBarController]viewControllers]objectAtIndex:0]visibleViewController] showMapForObject:obj];
}


// pass nil for searchPlaceholder if there is no UISearchView for the viewController
- (id) initWithSearchPlaceholder:(NSString*)searchPlaceholder {
	if (self = [super init]) {
		
		sortControl = [[UISegmentedControl alloc]initWithItems:[NSArray arrayWithObjects:@"Name", @"Distance", @"Favorites",nil]];
		CGRect fr = sortControl.frame;
		fr.size.width = self.view.frame.size.width;
		sortControl.frame = fr;
		
		sortControl.tintColor = [UIColor colorWithRed:35/255.0f green:97/255.0f blue:222/255.0f alpha:1];
		sortControl.backgroundColor = [UIColor blackColor];
		sortControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		sortControl.segmentedControlStyle = UISegmentedControlStyleBar;
		[sortControl addTarget:self action:@selector(sortTable:) forControlEvents:UIControlEventValueChanged];

		self.tableView.tableHeaderView = sortControl;
		
		
    if (NO && searchPlaceholder) {
      searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,0,320,44)];
      searchBar.delegate = self;
      searchBar.barStyle = UIBarStyleBlackTranslucent;
      searchBar.placeholder = searchPlaceholder;
      UITextField *searchField = [[searchBar subviews] lastObject];
      [searchField setReturnKeyType:UIReturnKeyDone];
      self.tableView.tableHeaderView = searchBar;
      [searchBar release];
    }      
		if ([objects count] == 0) {
			//NSString * path = @"http://bme.burningman.com/feeds/Messages/all/";
			//[self parseXMLFileAtURL:path];
		}
	}
  return self;
}

- (void) loadObjectsForEntity:(NSString *)entityName {
	sortControl.selectedSegmentIndex = 0;
}


- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	cellSize = CGSizeMake([self.tableView bounds].size.width, 60);	
}


- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}


#pragma mark Table view methods

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}


- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [objects count];
}


- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  return nil;
}



- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {}


- (void)searchBarSearchButtonClicked:(UISearchBar *)sb{
	[sb resignFirstResponder];
}


- (void)dealloc {
  [touchedIndexPath release];
	[sortControl release];
  [super dealloc];
}


- (void) showDetails {
  [self tableView:self.tableView didSelectRowAtIndexPath:touchedIndexPath];
}


- (void) showOnMap {
  [self showOnMapForIndexPath];
}


- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)index {
  switch (index) {
    case 0:
      [self showDetails];
			break;
    case 1:
      [self showOnMap];
			break;
    default:
      break;
  }
  [touchedIndexPath release];
  touchedIndexPath = nil;
}


- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
  [self tableView:tableView didSelectRowAtIndexPath:indexPath];
  //touchedIndexPath = [indexPath retain];
  //UIActionSheet *as = [[[UIActionSheet alloc]initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Show Details", @"Show On Map", nil]autorelease];
  //iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  //[as showInView:t.tabBarController.view];
}


@end

