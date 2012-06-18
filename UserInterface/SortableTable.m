//
//  SortableTable.m
//  iBurn
//
//  Created by Andrew Johnson on 8/21/11.
//


#import "SortableTable.h"

@implementation SortableTable
@synthesize sortControl;

- (id)init {
	if (self = [super init]) {
		[self.tabBarItem initWithTitle:self.title image:[UIImage imageNamed:@"art2.png"] tag:0];
		self.title = @"Art";
		[self.navigationItem setTitle:@"Art Installations"];
	}
  return self;
}


- (void) loadView {
  [super loadView];
	
	
	sortControl = [[UISegmentedControl alloc]initWithItems:[NSArray arrayWithObjects:@"Name", @"Distance",nil]];
	CGRect fr = sortControl.frame;
	fr.size.width = self.view.frame.size.width;
	sortControl.frame = fr;
	sortControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	sortControl.segmentedControlStyle = UISegmentedControlStyleBar;
	self.tableView.tableHeaderView = sortControl;
	
}


- (void) requestDone { }


- (void) switchTables:(int)index {
}

/*
- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath {	
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
}


- (CGFloat)tableView:(UITableView *)aTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 50.0;
}

*/


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {  
  return YES;
}  


- (void)dealloc {
  [sortControl release];
	[super dealloc];
}

@end
