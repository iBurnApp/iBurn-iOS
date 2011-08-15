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

@implementation EventDayTable
@synthesize events;

#pragma mark -
#pragma mark Initialization


- (NSArray*) getEventsForTitle:(NSString*) ttl {
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  EventNodeController *nc = (EventNodeController*)[t eventNodeController];
  if ([ttl isEqualToString:@"August 30"])
    return [[nc eventDateHash]objectForKey:@"30"];
  if ([ttl isEqualToString:@"August 31"])
    return [[nc eventDateHash]objectForKey:@"31"];
  if ([ttl isEqualToString:@"September 1"])
    return [[nc eventDateHash]objectForKey:@"01"];
  if ([ttl isEqualToString:@"September 2"])
    return [[nc eventDateHash]objectForKey:@"02"];
  if ([ttl isEqualToString:@"September 3"])
    return [[nc eventDateHash]objectForKey:@"03"];
  if ([ttl isEqualToString:@"September 4"])
    return [[nc eventDateHash]objectForKey:@"04"];
  if ([ttl isEqualToString:@"September 5"])
    return [[nc eventDateHash]objectForKey:@"05"];
  if ([ttl isEqualToString:@"September 6"])
    return [[nc eventDateHash]objectForKey:@"06"];
  if ([ttl isEqualToString:@"September 7"])
    return [[nc eventDateHash]objectForKey:@"07"];
}


- (void) requestDone {
  self.events = [self getEventsForTitle:self.title];
  [self.tableView reloadData];
}


- (void) viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self requestDone];
}


- (id)initWithTitle:(NSString*)ttl {
  self = [super initWithStyle:UITableViewStylePlain];
  self.title = ttl;
  return self;
}


#pragma mark -
#pragma mark View lifecycle

/*
- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}
*/

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/

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
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"MDT"]];
  }  
  cell.detailTextLabel.text = [formatter stringFromDate:[[events objectAtIndex:indexPath.row]startTime]];
	
  return cell;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (events == nil) {
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
    [super dealloc];
}


@end

