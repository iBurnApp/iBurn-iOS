//
//  InfoViewController.m
//  iBurn
//
//  Created by Andrew Johnson on 6/26/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "InfoViewController.h"
#import "PageViewer.h"
#import "iBurnAppDelegate.h"

@implementation InfoViewController

#define PADDING 5.0f

// this method is implemented in subclasses

  
- (id)initWithTitle:(NSString*)title {
  self = [super init];
  self.title = title;
	[self.tabBarItem initWithTitle:self.title image:NULL tag:0];
  return self;
}


- (void)loadView {
	[super loadView];
	CGRect tableFrame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
	tableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStyleGrouped];
	tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	tableView.delegate = self;
	tableView.dataSource = self;
	[self.view addSubview:tableView];
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
                                             initWithImage:[UIImage imageNamed:@"empty_star.png"]
                                             style:UIBarButtonItemStylePlain
                                             target:self
                                             action:@selector(addToFavorites:)] autorelease];
	
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
	NSLog(@"The row count is %d", [headerTitles count]);
  return [headerTitles count];
}


- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section {
  return [headerTitles objectAtIndex:section];
}


- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *) indexPath object:(id)object {
	int section = [indexPath section];
	if ([[headerTitles objectAtIndex:indexPath.section]isEqualToString:@"Description"] 
			&& section != 0) { 
			CGSize constraintSize;
			constraintSize.width = self.view.frame.size.width-PADDING*5;
			constraintSize.height = MAXFLOAT;
			CGSize theSize = [[object desc] sizeWithFont:[UIFont systemFontOfSize:17.0f] constrainedToSize:constraintSize lineBreakMode:UILineBreakModeWordWrap];
			return theSize.height+PADDING*4;
		
  }
  return 44.0f;
}


- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
	tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [tableView reloadData];
}


- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath  {
  NSArray *identifiers = [NSArray arrayWithObjects:@"a", @"b", @"c", @"d", @"e", @"f", nil];
	NSInteger section = [indexPath section];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[identifiers objectAtIndex:section]];
  if(!cell) cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:[identifiers objectAtIndex:section]] autorelease];
  if ([[headerTitles objectAtIndex:indexPath.section]isEqualToString:@"Description"]) {
    if(!descriptionLabel) {
      descriptionLabel = [[[UILabel alloc] initWithFrame:CGRectZero]autorelease];
			descriptionLabel.backgroundColor = [UIColor clearColor];
			descriptionLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
      CGSize constraintSize;
			constraintSize.width = cell.contentView.frame.size.width;
			constraintSize.height = MAXFLOAT;
			CGSize theSize = [[cellTexts objectAtIndex:section] sizeWithFont:[UIFont systemFontOfSize:17.0f] 
																										 constrainedToSize:constraintSize 
																												 lineBreakMode:UILineBreakModeWordWrap];
      descriptionLabel.frame = CGRectMake(0, 
                                          PADDING, 
                                          cell.contentView.frame.size.width, 
                                          theSize.height+PADDING*2);
      [cell.contentView addSubview:descriptionLabel];
      descriptionLabel.numberOfLines = 0;
      //descriptionLabel.adjustsFontSizeToFitWidth = true;
      //[descriptionLabel sizeToFit];
    }
    descriptionLabel.text = [cellTexts objectAtIndex:section];
  } else {
    cell.textLabel.text = [cellTexts objectAtIndex:section];
  }
  if ([[headerTitles objectAtIndex:indexPath.section]isEqualToString:@"URL"]
      || [[headerTitles objectAtIndex:indexPath.section]isEqualToString:@"Contact Email"] 
      || [[headerTitles objectAtIndex:indexPath.section]isEqualToString:@"Coordinates"]) {
    cell.textLabel.textColor = [UIColor blueColor];
  }
  cell.textLabel.adjustsFontSizeToFitWidth = YES;
   
  return cell;
}


- (void)tableView:(UITableView *)tb didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  UITableViewCell *cell = [tb cellForRowAtIndexPath:indexPath];
  if ([[headerTitles objectAtIndex:indexPath.section]isEqualToString:@"URL"]) {
    if (![t canConnectToInternet]) {
      UIAlertView *as = [[[UIAlertView alloc]initWithTitle:@"No Internet Connection" message:@"This page will only display if you have previously cached it." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil]autorelease];
      [as show];
    }
    PageViewer *w = [[[PageViewer alloc] initForString:cell.textLabel.text]autorelease];
    [self.navigationController pushViewController:w animated:YES];
  } else if ([[headerTitles objectAtIndex:indexPath.section]isEqualToString:@"Contact Email"]) {
    NSString *mailString = [NSString stringWithFormat:@"mailto:?to=%@",[cell.textLabel.text stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:mailString]];
  } else if ([[headerTitles objectAtIndex:indexPath.section]isEqualToString:@"Coordinates"] && ![t embargoed]) {
    [self showOnMap];
  } else if ([[headerTitles objectAtIndex:indexPath.section]isEqualToString:@"Camp"]) {
    [self showCamp];    
  }

}


- (NSIndexPath*)tableView:(UITableView *)tb willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tb cellForRowAtIndexPath:indexPath];
  if ([[headerTitles objectAtIndex:indexPath.section]isEqualToString:@"URL"]
      || [[headerTitles objectAtIndex:indexPath.section]isEqualToString:@"Camp"]
      || [[headerTitles objectAtIndex:indexPath.section]isEqualToString:@"Coordinates"]
      || [[headerTitles objectAtIndex:indexPath.section]isEqualToString:@"Contact Email"]) {
    return indexPath;
  }
  return nil;
}

- (void) addToFavorites:(id)sender {}


- (void)dealloc {
  [headerTitles release];
  [cellTexts release];
  [tableView release];
  [super dealloc];
}


@end

