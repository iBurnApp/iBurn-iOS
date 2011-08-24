//
//  CreditsViewController.h
//  iBurn
//
//  Created by Andrew Johnson on 8/21/11.


#import "CreditsViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "PageViewer.h"
#import "iBurnAppDelegate.h"

@implementation CreditsViewController


- (void) addTextRowWithTitle:(NSString*)titleText 
										 bodyText:(NSString*)bodyText 
											 toView:(UIView*)bgView 
													row:(int)row {
	int rowHeight = 47;
	int offset = 135;
	CGRect fr = CGRectMake(10, row*rowHeight+5+offset, self.view.frame.size.width-40, 24);
	UILabel *titleLabel = [[[UILabel alloc]initWithFrame:fr]autorelease];
	titleLabel.text = titleText;
	titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
	[bgView addSubview:titleLabel];

	// sorry for this hack :(
	int height = 22;
	if ([titleText isEqualToString:@"Data Dev"]) {
		height = 40;
	}
	fr = CGRectMake(10, row*rowHeight + 22 + offset, self.view.frame.size.width-40, height);

	UILabel *textLabel = [[[UILabel alloc]initWithFrame:fr]autorelease];
	textLabel.font = [UIFont fontWithName:@"Helvetica" size:13];
	textLabel.numberOfLines = 0;
	textLabel.text = bodyText;
	textLabel.backgroundColor = [UIColor clearColor];
	[bgView addSubview:textLabel];
	
}


- (void) addImageRowWithTitle:(NSString*)titleText 
												 bodyText:(NSString*)bodyText 
										imageName:(NSString*)imageName
											 toView:(UIView*)bgView 
													row:(int)row {
	int rowHeight = 67;
	CGRect fr = CGRectMake(10, row*rowHeight+5, self.view.frame.size.width-20-57, 24);
	UILabel *titleLabel = [[[UILabel alloc]initWithFrame:fr]autorelease];
	titleLabel.text = titleText;
	titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
	[bgView addSubview:titleLabel];

	fr = CGRectMake(10, row*rowHeight + 27, self.view.frame.size.width-57-30, 44);
	UILabel *textLabel = [[[UILabel alloc]initWithFrame:fr]autorelease];
	textLabel.font = [UIFont fontWithName:@"Helvetica" size:13];
	textLabel.numberOfLines = 0;
	textLabel.text = bodyText;
	[bgView addSubview:textLabel];
	
	UIImageView *iv = [[[UIImageView alloc]initWithImage:[UIImage imageNamed:imageName]]autorelease];
	fr = CGRectMake(self.view.frame.size.width-57-10, row*rowHeight+10, iv.image.size.width, iv.image.size.height);
	iv.frame = fr;
	[bgView addSubview:iv];
	
}

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
	[super loadView];
	self.title = @"Credits";
}


#pragma mark Table view methods

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *) indexPath {
	switch (indexPath.row) {
		case 0:
			return 80;
			break;
		case 1:
			return 67;
			break;
		case 2:
			return 67;
			break;
		case 3:
			return 43;
			break;
		case 4:
			return 43;
			break;
		case 5:
			return 55;
			break;
		default:
			return 0;
			break;
	}
	
}


- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}


- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 7;
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
 	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  
  if (![t canConnectToInternet]) {
    UIAlertView *as = [[[UIAlertView alloc]initWithTitle:@"No Internet Connection" message:@"Sorry, please try again later." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil]autorelease];
    [as show];
    return;
  }
  
	switch (indexPath.row) {
		case 1:
			[[UIApplication sharedApplication]openURL:[NSURL URLWithString:@"http://itunes.apple.com/us/app/gaia-gps-offline-topo-maps/id329127297?mt=8"]];			
			break;
		case 2:
			[[UIApplication sharedApplication]openURL:[NSURL URLWithString:@"http://itunes.apple.com/us/app/marine-charts/id386584429?mt=8"]];
			break;
		case 6:
			[[UIApplication sharedApplication]openURL:[NSURL URLWithString:@"http://www.burnermap.com"]];
			break;
		default:
			break;
	}
}


- (NSIndexPath*)tableView:(UITableView *)tb willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.row == 1 || indexPath.row == 2 || indexPath.row == 3) {
    return indexPath;
  }
  return nil;
}


- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *MyIdentifier = @"MyIdentifier";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:MyIdentifier] autorelease];
	}
	switch (indexPath.row) {
		case 0:
			cell.textLabel.text = @"R.I.P. Rod Garrett";
			cell.detailTextLabel.text = @"BRC City Planner, Designer of the Man, Liberator of Map Data.";
			cell.detailTextLabel.numberOfLines = 0;
			cell.imageView .image = [UIImage imageNamed:@"rod_garrett.jpg"];
			//cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			break;
		case 1:
			cell.textLabel.text = @"App Dev";
			cell.detailTextLabel.text = @"Anna & Andrew Johnson. Check out their hiking app, Gaia GPS.";
			cell.detailTextLabel.numberOfLines = 0;
			cell.imageView .image = [UIImage imageNamed:@"gaia-icon.png"];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			break;
		case 2:
			cell.textLabel.text = @"Cartography";
			cell.detailTextLabel.text = @"Virgil Zetterlind. Check out his boating app, Marine Charts.";
			cell.detailTextLabel.numberOfLines = 0;
			cell.imageView .image = [UIImage imageNamed:@"earthnc-icon.png"];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			break;
    case 3:
			cell.textLabel.text = @"Funding";
			cell.detailTextLabel.text = @"Andrew Johnstone and TrailBehind, Inc.";
			break;
		case 4:
			cell.textLabel.text = @"Artwork";
			cell.detailTextLabel.text = @"Kim Rullo and Andrew Johnstone";
			break;
		case 5:
			cell.textLabel.text = @"Data Dev";
			cell.detailTextLabel.numberOfLines = 0;
			cell.detailTextLabel.text = @"Josh Braegger, Jeff Johnson, Tom Longson, Mikel Maron";
			break;
		default:
			break;
	}
	return cell;		
}
	

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}


@end
