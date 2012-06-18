//
//  SettingsTableViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-25.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "SyncViewController.h"


@implementation SyncViewController

- (id)init {	
	if(self = [super init]) {
		[self.tabBarItem initWithTitle:self.title image:[UIImage imageNamed:@"sync.png"] tag:0];
		self.title = @"Sync";
		[self.navigationItem setTitle:@"Sync with Web"];
	}
  return self;
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 6;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}


- (void) switchEm: (UIControl *) sender {}


- (void) doSync: (UIControl *) sender {
	UIAlertView *doSync = [[UIAlertView alloc]
								   initWithTitle:@"Syncing"
								   message:@"Not Yet Implemented"
								   delegate:self 
								   cancelButtonTitle:nil
								   otherButtonTitles:@"OK", nil];
	[doSync show];
	[doSync release];	
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  NSArray *texts = [NSArray arrayWithObjects:@"Sync Map",@"Sync Camps",@"Sync Art Installs", @"Sync Events", @"Sync Tweets", @"Sync!", nil];
	NSInteger section = [indexPath section];
	UITableViewCell *cell;
  UISwitch *switchView = NULL;
  switchView = [[UISwitch alloc] initWithFrame: CGRectMake(4.0f, 16.0f, 100.0f, 28.0f)];
  cell = [tableView dequeueReusableCellWithIdentifier:[texts objectAtIndex:indexPath.row]];
  if(!cell) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[texts objectAtIndex:indexPath.row]] autorelease];
    [switchView addTarget:self action:@selector(switchEm:) forControlEvents:UIControlEventValueChanged];
  }
  cell.selectionStyle = UITableViewCellSelectionStyleGray;
  switchView.on = TRUE;
  cell.textLabel.text = [texts objectAtIndex:indexPath.row];
  cell.accessoryView = switchView;
  [switchView setTag:999-section];
  if (section == 5) {
    UIButton *syncButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    syncButton.frame = CGRectMake(20.0f, 20.0f, 200.0f, 44.0f); // position in the parent view and set the size of the button
    [syncButton setTitle:@"Sync!" forState:UIControlStateNormal];
    [syncButton addTarget:self action:@selector(doSync:) forControlEvents:UIControlEventTouchUpInside];
    cell.accessoryView = syncButton;
  }			
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}


@end

