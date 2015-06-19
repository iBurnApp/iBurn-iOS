//
//  BRCFilteredTableViewController_Private.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/31/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCFilteredTableViewController.h"

@interface BRCFilteredTableViewController ()
@property (nonatomic, strong) NSMutableDictionary *mappingsDictionary;
@property (nonatomic, strong) YapDatabaseConnection *databaseConnection;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicatorView;

@property (nonatomic) BOOL isUpdatingFilters;

- (void) setupMappingsDictionary;
- (void) updateAllMappingsWithCompletionBlock:(dispatch_block_t)completionBlock;

- (BOOL) shouldAnimateLoadingIndicator;
- (void) refreshLoadingIndicatorViewAnimation;

- (Class) cellClass;

- (BOOL)isSearchResultsControllerTableView:(UITableView *)tableView;
@end
