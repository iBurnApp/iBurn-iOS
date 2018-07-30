//
//  BRCFilteredTableViewController_Private.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/31/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCFilteredTableViewController.h"
#import "iBurn-Swift.h"
@import YapDatabase;

NS_ASSUME_NONNULL_BEGIN
@interface BRCFilteredTableViewController () <YapViewHandlerDelegate>
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) YapViewHandler *viewHandler;
@property (nonatomic, strong) YapViewHandler *searchViewHandler;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicatorView;

@property (nonatomic) BOOL isUpdatingFilters;

@property (nonatomic) BOOL hasAddedConstraints;

- (void) setupMappings;

- (BOOL) shouldAnimateLoadingIndicator;
- (void) refreshLoadingIndicatorViewAnimation;

- (BOOL)isSearchResultsControllerTableView:(UITableView *)tableView;

@end
NS_ASSUME_NONNULL_END
