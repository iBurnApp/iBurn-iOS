//
//  FavoritesTableViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-25.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "FavoritesTableViewController.h"
#import "Favorite.h"
#import "ThemeCamp.h"
#import "ArtInstall.h"
#import "Event.h"
#import "CampInfoViewController.h"
#import "ArtInfoViewController.h"
#import "EventInfoViewController.h"
#import "iBurnAppDelegate.h"
#import "DetailTableCell.h"
#import "RMMapView.h"
#import "MapViewController.h"

@implementation FavoritesTableViewController



- (void) deleteIfValid:(NSIndexPath*)indexPath  {
  if (indexPath.row >= [objects count]) return;
	Favorite *fav = [objects objectAtIndex:indexPath.row];	
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSManagedObjectContext *moc = [t managedObjectContext];
  [moc deleteObject:fav];
  NSError *error;
  if (![moc save:&error]) {}
	[objects removeObject: fav];
}


-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete) { return; }
  [self deleteIfValid:indexPath];
  [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
}



- (void) showOnMapForIndexPath {
  Favorite *favorite = [objects objectAtIndex: touchedIndexPath.row];
  id obj;
  if (favorite.ThemeCamp) {    
    obj = favorite.ThemeCamp;
  } else if (favorite.ArtInstall) {
    obj = favorite.ArtInstall;
  } else if (favorite.Event) {
    obj = favorite.Event;
  }  
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  [[t tabBarController]setSelectedViewController:[[[t tabBarController]viewControllers]objectAtIndex:0]];
  MapViewController *mapViewController = (MapViewController*)[[[[t tabBarController]viewControllers]objectAtIndex:0]visibleViewController];
  [mapViewController showMapForObject:obj];
}


- (void) loadFavorites {
	iBurnAppDelegate *iBurnDelegate = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSManagedObjectContext *moc = [iBurnDelegate managedObjectContext];
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Favorite" 
																											 inManagedObjectContext:moc];
	NSFetchRequest *request = [[[NSFetchRequest alloc]init]autorelease];
	[request setEntity:entityDescription];
	NSError *error;
	objects = [[NSMutableArray arrayWithArray:[moc executeFetchRequest:request error:&error]]retain];
	NSMutableArray *newObjects = [NSMutableArray array];
	for (id object in objects) {
		if ([object Event]) {
			[newObjects addObject:object];
		}
	}
	[objects release];
	objects = [newObjects retain];
	if(objects == nil) {
		NSLog(@"Fetch failed with error: %@", error);
	}
}



- (void) requestDone {
  [self loadFavorites];
  [self.tableView reloadData];
}


- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
  [self loadFavorites];
  [self.tableView reloadData];
}


- (id)init {
	if( self = [super init]) {
		[self.tabBarItem initWithTitle:self.title image:[UIImage imageNamed:@"favorites.png"] tag:0];
		self.title = @"Favorites";
	}
    return self;
}



#pragma mark Table view methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	int index = [indexPath indexAtPosition: [indexPath length] - 1];
	Favorite *favorite = [objects objectAtIndex: index];
  if (favorite.ThemeCamp) {    
    CampInfoViewController *infoView = [[[CampInfoViewController alloc] initWithCamp:favorite.ThemeCamp]autorelease];
    [[self navigationController] pushViewController:infoView animated:YES];
  } else if (favorite.ArtInstall) {
    ArtInfoViewController *infoView = [[[ArtInfoViewController alloc] initWithArt:favorite.ArtInstall]autorelease];
    [[self navigationController] pushViewController:infoView animated:YES];
  } else if (favorite.Event) {
    EventInfoViewController *infoView = [[[EventInfoViewController alloc] initWithEvent:favorite.Event]autorelease];
    [[self navigationController] pushViewController:infoView animated:YES];
  }  
}


- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *MyIdentifier = @"MyIdentifier";
	DetailTableCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
	if (cell == nil) {
		cell = [[[DetailTableCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:MyIdentifier] autorelease];
    //[cell setBlackness];
	}
	int storyIndex = [indexPath indexAtPosition: [indexPath length] - 1];
  Favorite *favorite = [objects objectAtIndex: storyIndex];
  if (favorite.ThemeCamp) {    
    cell.textLabel.text = [favorite.ThemeCamp name];
    cell.imageView.image = [UIImage imageNamed:@"camps-reversed.png"];
  } else if (favorite.ArtInstall) {
    cell.textLabel.text = [favorite.ArtInstall name];
    cell.imageView.image = [UIImage imageNamed:@"art-reverse.png"];
  } else if (favorite.Event) {
    cell.textLabel.text = [favorite.Event name];
    cell.imageView.image = [UIImage imageNamed:@"events-reversed.png"];
    //cell.accessoryType = UITableViewCellAccessoryNone;
  }  
	return cell;	
}


@end

