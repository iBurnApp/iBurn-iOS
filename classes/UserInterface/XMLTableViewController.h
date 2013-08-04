//
//  XMLTableViewController.h
//  iBurn
//
//  Created by Andrew Johnson on 6/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DetailTableCell.h"

@interface XMLTableViewController : UITableViewController <UISearchBarDelegate, UIActionSheetDelegate> {
	CGSize cellSize;
	NSMutableArray *objects;
	NSMutableArray *objectDict;
  UISearchBar *searchBar;
  NSIndexPath *touchedIndexPath;
	UISegmentedControl *sortControl;
	NSMutableArray *sections;
}

@property (nonatomic, strong) NSMutableArray *objects;
@property (nonatomic, strong) NSMutableArray *objectDict;
@property (nonatomic, retain) NSString* objectType;


- (id) initWithSearchPlaceholder:(NSString*)searchPlaceholder;
- (void) loadObjectsForEntity:(NSString *)entityName;
- (void) sortByNameForEntity:(NSString*)entityName;
- (void) sortBySimpleNameForEntity:(NSString*)entityName;

- (void) sortByName;

@end
