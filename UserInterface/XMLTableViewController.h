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
  UISearchBar *searchBar;
  NSIndexPath *touchedIndexPath;
	UISegmentedControl *sortControl;

}

- (id) initWithSearchPlaceholder:(NSString*)searchPlaceholder;
- (void) loadObjectsForEntity:(NSString *)entityName;

@end
