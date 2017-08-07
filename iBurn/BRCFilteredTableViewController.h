//
//  BRCFilteredTableViewController.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BRCFilteredTableViewController : UIViewController <UISearchResultsUpdating, UISearchBarDelegate, UISearchControllerDelegate, UITableViewDataSource, UITableViewDelegate, UIPageViewControllerDataSource>

@property (nonatomic, strong, readonly) UITableView *tableView;

@property (nonatomic, strong, readonly) NSString *viewName;
@property (nonatomic, strong, readonly) NSString *searchViewName;
@property (nonatomic, strong, readonly) Class viewClass;

- (instancetype) initWithViewClass:(Class)viewClass
                          viewName:(NSString*)viewName
                    searchViewName:(NSString*)searchViewName;


/** Called from tabBarController:didSelectViewController: */
- (void) didSelectFromTabBar:(UITabBarController *)tabBarController;

@end
