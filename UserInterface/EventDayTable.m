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

@implementation EventDayTable
@synthesize events;


+ (NSDate*) dateFromDay:(int)day month:(int)month {
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
  [gregorian setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
	NSDateComponents *components = [gregorian components:NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit fromDate:[NSDate date]];
	[components setDay:day];
	[components setMonth:month];
	NSDate * date = [gregorian dateFromComponents:components];
	[gregorian release];
	return date;
}


+ (NSDate*) dateFromDay:(int)day month:(int)month hour:(int)hour minutes:(int)minutes {
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
  [gregorian setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
	NSDateComponents *components = [gregorian components:NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit fromDate:[NSDate date]];
	[components setHour:hour];
	[components setHour:minutes];
	[components setHour:9];
	[components setDay:day];
	[components setMonth:month];
	NSDate * date = [gregorian dateFromComponents:components];
	[gregorian release];
	return date;
}


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


- (NSArray*) getEventsForTitle:(NSString*) ttl {
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  EventNodeController *nc = (EventNodeController*)[t eventNodeController];
	return [[nc eventDateHash]objectForKey:[self dayString:ttl]];
}



- (void) sortByCurrent { 
  self.events = [self getEventsForTitle:self.title];
  [self.tableView reloadData];
	self.navigationItem.rightBarButtonItem.enabled = YES;
}


- (NSString*) dayString:(NSString*)ttl {
	NSString *dayString;
	if ([ttl isEqualToString:@"August 29"])
		dayString = @"29";
	if ([ttl isEqualToString:@"August 30"])
		dayString = @"30";
	if ([ttl isEqualToString:@"August 31"])
		dayString = @"31";
	if ([ttl isEqualToString:@"September 1"])
		dayString = @"01";
	if ([ttl isEqualToString:@"September 2"])
		dayString = @"02";
	if ([ttl isEqualToString:@"September 3"])
		dayString = @"03";
	if ([ttl isEqualToString:@"September 4"])
		dayString = @"04";
	if ([ttl isEqualToString:@"September 5"])
		dayString = @"05";
	return dayString;
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
	for (Favorite *f in favs) {
		if ([f Event]) {
			if ([[self dayString:self.title] isEqualToString:[Event getDay:[[f Event]startTime]]]) {
	  		[objects addObject:[f Event]];
			}
		}
	}
	
  NSSortDescriptor *lastDescriptor =
  [[[NSSortDescriptor alloc] initWithKey:@"startTime"
                               ascending:YES
                                selector:@selector(compare:)] autorelease];
  NSArray *descriptors = [NSArray arrayWithObjects:lastDescriptor, nil];
  NSArray *sortedArray = [objects sortedArrayUsingDescriptors:descriptors];
  self.events = sortedArray;
  [self.tableView reloadData];
	self.navigationItem.rightBarButtonItem.enabled = YES;
}



- (void) sortByName { 
  self.events = [self getEventsForTitle:self.title];
	NSSortDescriptor *lastDescriptor =
  [[[NSSortDescriptor alloc] initWithKey:@"name"
                               ascending:YES
                                selector:@selector(compare:)] autorelease];
  NSArray *descriptors = [NSArray arrayWithObjects:lastDescriptor, nil];
  NSArray *sortedArray = [self.events sortedArrayUsingDescriptors:descriptors];
  self.events = sortedArray;
	
  [self.tableView reloadData];
	self.navigationItem.rightBarButtonItem.enabled = NO;
}



- (void) sortTable:(id)sender {
	switch ([sender selectedSegmentIndex]) {
    case 0:  // name
			[self sortByCurrent];
      break;
    case 1:  // distance
			[self sortByFavorites];
      break;
    default: // favorites
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
	[sortControl release];
	sortControl = [[[UISegmentedControl alloc]initWithItems:[NSArray arrayWithObjects:@"Time", @"Favorites", @"Name",nil]]retain];
	sortControl.tintColor = [UIColor colorWithRed:35/255.0f green:97/255.0f blue:222/255.0f alpha:1];
	sortControl.backgroundColor = [UIColor blackColor];
	CGRect fr = sortControl.frame;
	fr.size.width = self.view.frame.size.width;
	sortControl.frame = fr;
	sortControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	sortControl.segmentedControlStyle = UISegmentedControlStyleBar;
	[sortControl addTarget:self action:@selector(sortTable:) forControlEvents:UIControlEventValueChanged];
	
	self.tableView.tableHeaderView = sortControl;
	
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]initWithTitle:@"Now" 
																																						style:UIBarButtonItemStyleDone 
																																					 target:self 
																																					 action:@selector(scrollIfToday)]autorelease];
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
		UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"] autorelease];
		cell.textLabel.text = @"Mark some favorites.";
		return cell;
	}
  if(events == nil) {
		UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"] autorelease];
		cell.textLabel.text = @"Loading, please be patient.";
		return cell;
	}
	static NSString *CellIdentifier = @"Cell";
  DetailTableCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[[DetailTableCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
  }
  //cell.accessoryType = UITableViewCellAccessoryNone;
	
	cell.textLabel.text = [[events objectAtIndex:indexPath.row]name];  
  static NSDateFormatter *formatter = nil;
  if (!formatter) {
    formatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale;
    enUSPOSIXLocale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
    [formatter setLocale:enUSPOSIXLocale];
    [formatter setDateFormat:@"hh:mm a"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"PDT"]];
  }  
  cell.detailTextLabel.text = [formatter stringFromDate:[[events objectAtIndex:indexPath.row]startTime]];
	
  return cell;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (events == nil || [events count] == 0) {
		return;
	} 
	int eventIndex = [indexPath indexAtPosition: [indexPath length] - 1];
	EventInfoViewController *eventView = [[[EventInfoViewController alloc] initWithEvent:[events objectAtIndex:eventIndex]]autorelease];
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


- (void)dealloc {
  [events release];
	[sortControl release];
	[super dealloc];
}


@end


