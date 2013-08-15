//
//  EventDayTable.m
//  iBurn
//
//  Created by Andrew Johnson on 8/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "EventDayTable.h"
#import "iBurnAppDelegate.h"
#import "EventNodeController.h"
#import "EventInfoViewController.h"
#import "NSDate-Utilities.h"
#import "Favorite.h"
#import "Event.h"
#import "util.h"
#import "NSManagedObject_util.h"


@implementation EventDayTable
@synthesize events;


- (void) scrollIfToday {
	NSDate *now = [NSDate date];
	int scrollCount = 0;
	for (Event *e in events) {
		if ([[e startTime] isLaterThanDate:now]) {
			break;
		}		
		scrollCount++;
	}	
	if (scrollCount > 0) {
		[[self tableView] scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:MAX(0,scrollCount-6) inSection:0] 
														atScrollPosition:UITableViewScrollPositionBottom animated:YES];
	}
}	


- (void) sortByCurrent { 
  self.events = [self getEventsForTitle:self.dayName];
  [self.tableView reloadData];
	self.navigationItem.rightBarButtonItem.enabled = YES;
}


- (NSString*) dayString:(NSString*)ttl {
  NSLog(@"day dict %@", [[util dayDict] objectForKey:ttl]);
  return [[[util dayDict] objectForKey:ttl]objectForKey:@"dayString"];      
}


- (NSArray*) getEventsForTitle:(NSString*) ttl {
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  EventNodeController *nc = (EventNodeController*)[t eventNodeController];
	return [[nc eventDateHash]objectForKey:[self dayString:ttl]];
}


- (void) sortByFavorites {
  objectDict = nil;
  
  iBurnAppDelegate *iBurnDelegate = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSManagedObjectContext *moc = [iBurnDelegate managedObjectContext];


  NSArray * allFavObjects = [NSManagedObject objectsForKey:@"bm_id" values:[Favorite favoritesForType:@"Event"] entityName:@"Event" sortField:nil inManagedObjectContext:moc];
  
  objects = [[NSMutableArray alloc]init];

  for (Event *f in allFavObjects) {
    if ([[self dayString:self.dayName] isEqualToString:[Event getDay:[f startTime]]]) {
      [objects addObject:f];
    }
		
	}
  
		
  NSSortDescriptor *lastDescriptor = [[NSSortDescriptor alloc] initWithKey:@"startTime"
                               ascending:YES
                                selector:@selector(compare:)];
  NSArray *descriptors = [NSArray arrayWithObjects:lastDescriptor, nil];
  NSArray *sortedArray = [objects sortedArrayUsingDescriptors:descriptors];
  self.events = sortedArray;
  [self.tableView reloadData];
	self.navigationItem.rightBarButtonItem.enabled = YES;
}



- (void) sortByName { 
  self.events = [self getEventsForTitle:self.dayName];
	NSSortDescriptor *lastDescriptor =
  [[NSSortDescriptor alloc] initWithKey:@"name"
                               ascending:YES
                                selector:@selector(compare:)];
  NSArray *descriptors = [NSArray arrayWithObjects:lastDescriptor, nil];
  NSArray *sortedArray = [self.events sortedArrayUsingDescriptors:descriptors];
  self.events = sortedArray;
	
  [self.tableView reloadData];
	self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void) sortByDistance {
  self.events = [self getEventsForTitle:self.dayName];
	NSSortDescriptor *distanceDescriptor =
  [[NSSortDescriptor alloc] initWithKey:@"distanceAway"
                               ascending:YES
                                selector:@selector(compare:)];
  NSSortDescriptor *timeDescriptor =
  [[NSSortDescriptor alloc] initWithKey:@"startTime"
                               ascending:YES
                                selector:@selector(compare:)];
  NSArray *descriptors = [NSArray arrayWithObjects:distanceDescriptor, timeDescriptor, nil];
  NSArray *sortedArray = [self.events sortedArrayUsingDescriptors:descriptors];
  self.events = sortedArray;
	
  [self.tableView reloadData];
	self.navigationItem.rightBarButtonItem.enabled = NO;
}



- (void) sortTable:(id)sender {
	switch ([sender selectedSegmentIndex]) {
    case 0:  // time
			[self sortByCurrent];
      break;
    case 1:  // distance
      [self sortByDistance];
      break;
    case 2:  // favorites
			[self sortByFavorites];
      break;
    default: // name
			[self sortByName];
      break;
  }  
  [self.tableView reloadData];
}


#pragma mark -
#pragma mark Initialization




- (void) requestDone { }


- (void) viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
	
}


- (void) loadView {
	[super loadView];
	sortControl = [[UISegmentedControl alloc]initWithItems:[NSArray arrayWithObjects:@"Time", @"Distance", @"Favorites", @"Name",nil]];
	sortControl.tintColor = [UIColor colorWithRed:35/255.0f green:97/255.0f blue:222/255.0f alpha:1];
	sortControl.backgroundColor = [UIColor blackColor];
	CGRect fr = sortControl.frame;
	fr.size.width = self.view.frame.size.width;
	sortControl.frame = fr;
	sortControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	sortControl.segmentedControlStyle = UISegmentedControlStyleBar;
	[sortControl addTarget:self action:@selector(sortTable:) forControlEvents:UIControlEventValueChanged];
	
	self.tableView.tableHeaderView = sortControl;
	
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Now" 
																																						style:UIBarButtonItemStyleDone 
																																					 target:self 
																																					 action:@selector(scrollIfToday)];
  sortControl.selectedSegmentIndex = 0;

}


- (id)initWithTitle:(NSString*)ttl {
  self = [super initWithStyle:UITableViewStylePlain];
  self.title = ttl;
  return self;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	// Return the number of sections.
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if([events count] == 0) {
		//NSLog(@"This table is totally empty dude");
		return 1;
	}
  return [events count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([events count] == 0) {
		UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
		cell.textLabel.text = @"Mark some favorites.";
		return cell;
	}
  if(events == nil) {
		UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
		cell.textLabel.text = @"Loading, please be patient.";
		return cell;
	}
	static NSString *CellIdentifier = @"Cell";
  DetailTableCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[DetailTableCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
  }
  //cell.accessoryType = UITableViewCellAccessoryNone;
	Event *event = [events objectAtIndex:indexPath.row];
  
	cell.textLabel.text = [event name];  
  static NSDateFormatter *formatter = nil;
  if (!formatter) {
    formatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale;
    enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [formatter setLocale:enUSPOSIXLocale];
    [formatter setDateFormat:@"hh:mm a"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"MDT"]];
  }
  float distanceAway = [event distanceAway];
  NSString * startTimeString = [formatter stringFromDate:[[events objectAtIndex:indexPath.row]startTime]];
  if ([event.allDay boolValue]) {
    startTimeString = @"All Day";
  }
  if (distanceAway >= 0 && distanceAway < 10000000) {
      cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@",
                                   startTimeString, 
                    [util distanceString:distanceAway convertMax:1000 includeUnit:YES decimalPlaces:2]];
  } else {
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - Unknown Location", startTimeString];
  }
  
	
  return cell;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (events == nil || [events count] == 0) {
		return;
	} 
	int eventIndex = [indexPath indexAtPosition: [indexPath length] - 1];
	EventInfoViewController *eventView = [[EventInfoViewController alloc] initWithEvent:[events objectAtIndex:eventIndex]];
	[[self navigationController] pushViewController:eventView animated:YES];
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
	[super didReceiveMemoryWarning];
	
	// Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
	// For example: self.myOutlet = nil;
}




@end


