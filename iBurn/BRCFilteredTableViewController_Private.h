//
//  BRCFilteredTableViewController_Private.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/31/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCFilteredTableViewController.h"

@interface BRCFilteredTableViewController ()
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) YapDatabaseViewMappings *mappings;
@property (nonatomic, strong) YapDatabaseViewMappings *searchMappings;
@property (nonatomic, strong) YapDatabaseConnection *databaseConnection;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicatorView;

@property (nonatomic) BOOL isUpdatingFilters;

- (void) setupMappings;
- (void) updateMappingsWithCompletionBlock:(dispatch_block_t)completionBlock;

- (BOOL) shouldAnimateLoadingIndicator;
- (void) refreshLoadingIndicatorViewAnimation;

- (BOOL)isSearchResultsControllerTableView:(UITableView *)tableView;

@end
