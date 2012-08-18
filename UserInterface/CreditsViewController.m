//
//  CreditsViewController.h
//  iBurn
//
//  Created by Andrew Johnson on 8/21/11.


#import "CreditsViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "PageViewer.h"
#import "iBurnAppDelegate.h"
#import "util.h"

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
  NSDictionary *dict = [[util creditsArray]objectAtIndex:indexPath.row];
  if ([dict objectForKey:@"icon"]) {
    return 67; 
  }
  return 43;	
}


- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}


- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [[util creditsArray]count];
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
 	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  
  NSDictionary *dict = [[util creditsArray]objectAtIndex:indexPath.row];
  if(![dict objectForKey:@"url"]) {
    return;
  }

  if (![t canConnectToInternet]) {
    UIAlertView *as = [[[UIAlertView alloc]initWithTitle:@"No Internet Connection" message:@"Sorry, please try again later." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil]autorelease];
    [as show];
    return;
  }
  [[UIApplication sharedApplication]openURL:[NSURL URLWithString:[dict objectForKey:@"url"]]];			
}


- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *MyIdentifier = @"MyIdentifier";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:MyIdentifier] autorelease];
	}
  NSDictionary *dict = [[util creditsArray]objectAtIndex:indexPath.row];
  cell.textLabel.text = [dict objectForKey:@"title"];
  cell.detailTextLabel.text = [dict objectForKey:@"description"];
  cell.detailTextLabel.numberOfLines = 0;
  if ([dict objectForKey:@"icon"]) {
    cell.imageView.image = [UIImage imageNamed:[dict objectForKey:@"icon"]];    
  }
  if ([dict objectForKey:@"url"]) {
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
  } else {
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
  }
	return cell;		
}
	
@end
