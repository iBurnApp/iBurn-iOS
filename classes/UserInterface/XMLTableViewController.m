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
#import "MapViewController.h"
#import "NSManagedObject_util.h"
#import "Favorite.h"

@implementation XMLTableViewController
@synthesize objects, objectDict;

- (void) loadView {
  [super loadView];
  self.tableView.tableHeaderView = sortControl;

  
}

- (void) sortByDistance { 
	[self sortByName];
	self.objectDict = nil;
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"distanceAway"
																																	ascending:YES];
	NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
	NSArray * newObjects = [objects sortedArrayUsingDescriptors:sortDescriptors];
	self.objects = [NSMutableArray arrayWithArray:newObjects];
}


- (void) sortBySimpleNameForEntity:(NSString*)entityName { 
	iBurnAppDelegate *iBurnDelegate = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSManagedObjectContext *moc = [iBurnDelegate managedObjectContext];
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:entityName
																											 inManagedObjectContext:moc];
	NSFetchRequest *request = [[NSFetchRequest alloc]init];
	[request setEntity:entityDescription];
	NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"simpleName" ascending:YES];
	[request setSortDescriptors:[NSArray arrayWithObject:sort]];
	NSError *error;
	objects = (NSMutableArray*)[moc executeFetchRequest:request error:&error];
	if(objects == nil) {
		NSLog(@"Fetch failed with error: %@", error);
	}	
	[self objectDictItUp];

}


- (void) sortByNameForEntity:(NSString*)entityName { 
	iBurnAppDelegate *iBurnDelegate = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSManagedObjectContext *moc = [iBurnDelegate managedObjectContext];
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:entityName
																											 inManagedObjectContext:moc];
	NSFetchRequest *request = [[NSFetchRequest alloc]init];
	[request setEntity:entityDescription];
	NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
	[request setSortDescriptors:[NSArray arrayWithObject:sort]];
	NSError *error;
	objects = (NSMutableArray*)[moc executeFetchRequest:request error:&error];
	if(objects == nil) {
		NSLog(@"Fetch failed with error: %@", error);
	}	
	[self objectDictItUp];
}

- (void) objectDictItUp {
  NSSet * alphabetSet = [NSSet setWithArray:[NSArray arrayWithArray:
                       [@"A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z"
                        componentsSeparatedByString:@"|"]]];
  NSString * lettersAndSymbols = @"#";
  
	objectDict = [[NSMutableArray alloc]init];
	sections = [[NSMutableArray alloc]init];
	NSString *lastLetter = nil;
	int index = -1;
	
	NSMutableDictionary *tempDict = [NSMutableDictionary dictionary];
	for (id object in objects) {
		NSString *letter = [[[object name]substringToIndex:1]uppercaseString];
    if( ![alphabetSet containsObject:letter])
      letter = lettersAndSymbols;
		if (![tempDict objectForKey:letter]) {
			[tempDict setValue:[NSMutableArray arrayWithObject:object] forKey:letter];
			NSLog(@"New letter: %@", letter);
		} else {
  		[[tempDict objectForKey:letter] addObject:object];
			if(![sections containsObject:letter]) {
				[sections addObject:letter];
			}
			index++;
		}
		lastLetter = letter;
	}
	for (NSString *key in sections) {
		[objectDict addObject:[tempDict objectForKey:key]];
	}
}


- (void) sortByFavorites {
	objectDict = nil;

	iBurnAppDelegate *iBurnDelegate = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSManagedObjectContext *moc = [iBurnDelegate managedObjectContext];
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Favorite" 
																											 inManagedObjectContext:moc];
	NSFetchRequest *request = [[NSFetchRequest alloc]init];
	[request setEntity:entityDescription];
	NSError *error;
	NSArray *favs = [moc executeFetchRequest:request error:&error];
	if(favs == nil) {
		NSLog(@"Fetch failed with error: %@", error);
	}
  objects = [NSManagedObject objectsForKey:@"bm_id" values:[Favorite favoritesForType:self.objectType] entityName:self.objectType sortField:nil inManagedObjectContext:moc];

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

- (void) viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  if (sortControl.selectedSegmentIndex == -1) {
    sortControl.selectedSegmentIndex = 0;
    // sortByName must be called to populate the objects
    [self sortByName];
  }
  [self sortTable:sortControl];
}


- (void) showOnMapForIndexPath {
	int index = [touchedIndexPath indexAtPosition: [touchedIndexPath length] - 1];
	id obj = [objects objectAtIndex: index];
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  [[t tabBarController]setSelectedViewController:[[[t tabBarController]viewControllers]objectAtIndex:0]];
  MapViewController *mapViewController = (MapViewController*)[[[[t tabBarController]viewControllers]objectAtIndex:0]visibleViewController];
  [mapViewController showMapForObject:obj];
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

				
		
    if (NO && searchPlaceholder) {
      searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,0,320,44)];
      searchBar.delegate = self;
      searchBar.barStyle = UIBarStyleBlackTranslucent;
      searchBar.placeholder = searchPlaceholder;
      UITextField *searchField = [[searchBar subviews] lastObject];
      [searchField setReturnKeyType:UIReturnKeyDone];
      self.tableView.tableHeaderView = searchBar;
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
	NSLog(@"The count is %d", [objectDict count]);
	if (objectDict) return [objectDict count];
  return 1;
}


- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (objectDict) return [[objectDict objectAtIndex:section]count];
	return [objects count];
}


- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  return nil;
}



- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {}


- (void)searchBarSearchButtonClicked:(UISearchBar *)sb{
	[sb resignFirstResponder];
}




- (void) showDetails {
  [self tableView:self.tableView didSelectRowAtIndexPath:touchedIndexPath];
}


- (void) showOnMap {
  [self showOnMapForIndexPath];
}

- (void) sortByName {}

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
  touchedIndexPath = nil;
}


- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	if (!objectDict) return nil;
	return sections;
}


- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString
																																						 *)title 
							 atIndex:(NSInteger)index {
	return index;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	// this table has multiple sections. One for each unique character that an element begins with
	// [A,B,C,D,E,F,G,H,I,K,L,M,N,O,P,R,S,T,U,V,X,Y,Z]
	// return the letter that represents the requested section
	// this is actually a delegate method, but we forward the request to the datasource in the view controller
	if (!objectDict) return nil;
	return [sections objectAtIndex:section];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
  [self tableView:tableView didSelectRowAtIndexPath:indexPath];
  //touchedIndexPath = [indexPath retain];
  //UIActionSheet *as = [[[UIActionSheet alloc]initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Show Details", @"Show On Map", nil]autorelease];
  //iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  //[as showInView:t.tabBarController.view];
}


@end

