//
//  BRCFilteredTableViewController.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BRCFilteredTableViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchDisplayDelegate, UISearchBarDelegate>

@property (nonatomic, strong, readonly) UITableView *tableView;
@property (nonatomic, strong, readonly) UISegmentedControl *segmentedControl;

// Set class of object to display
@property (nonatomic, strong) Class viewClass;

// Override this in subclasses
- (NSArray *) segmentedControlTitles;

@end
