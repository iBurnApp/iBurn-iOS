//
//  BRCFilteredTableViewController.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BRCFilteredTableViewController : UITableViewController <UISearchDisplayDelegate, UISearchBarDelegate>

@property (nonatomic, strong, readonly) NSString *viewName;

@property (nonatomic, strong, readonly) Class viewClass;

- (instancetype) initWithViewClass:(Class)viewClass;

@end
