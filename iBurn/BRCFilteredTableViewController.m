 //
//  BRCFilteredTableViewController.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCFilteredTableViewController.h"
@import YapDatabase;
@import YapDatabase.YapDatabaseSearchResultsView;
#import "BRCDatabaseManager.h"
#import "BRCDataObject.h"
#import "BRCDetailViewController.h"
#import "BRCDataObjectTableViewCell.h"
#import "BRCFilteredTableViewController.h"
#import "BRCFilteredTableViewController_Private.h"
#import "UIColor+iBurn.h"
@import PureLayout;
#import "CLLocationManager+iBurn.h"
#import "BRCEventObject.h"
#import "BRCAppDelegate.h"
#import <Parse/Parse.h>
#import "PFAnalytics+iBurn.h"
#import "BRCArtObjectTableViewCell.h"
#import "iBurn-Swift.h"
@import AVFoundation;

@interface BRCFilteredTableViewController () <UIToolbarDelegate, CLLocationManagerDelegate>
@property (nonatomic, strong, readonly) YapDatabaseConnection *searchConnection;
@property (nonatomic, strong, readonly) YapDatabaseSearchQueue *searchQueue;
@end

@implementation BRCFilteredTableViewController

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // UISearchController bug http://stackoverflow.com/a/32955784
    [self.searchController.view removeFromSuperview];
}

- (instancetype)initWithViewClass:(Class)viewClass viewName:(NSString *)viewName searchViewName:(NSString *)searchViewName
{
    if (self = [super init]) {
        _viewClass = viewClass;
        _viewName = viewName;
        _searchViewName = searchViewName;
        [self setupLoadingIndicatorView];
        [self setupDatabaseConnection];
        [self setupMappings];
        [self updateMappingsWithCompletionBlock:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(databaseExtensionRegistered:) name:BRCDatabaseExtensionRegisteredNotification object:[BRCDatabaseManager sharedInstance]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerChangedNotification:) name:BRCAudioPlayer.BRCAudioPlayerChangeNotification object:BRCAudioPlayer.sharedInstance];
        [self view]; //wtf
    }
    return self;
}

- (void) databaseExtensionRegistered:(NSNotification*)notification {
    NSString *extensionName = notification.userInfo[@"extensionName"];
    if ([extensionName isEqualToString:self.viewName]) {
        NSLog(@"databaseExtensionRegistered: %@", extensionName);
        [self.tableView reloadData];
    } else if ([extensionName isEqualToString:self.searchViewName]) {
        NSLog(@"databaseExtensionRegistered: %@", extensionName);
        id src = self.searchController.searchResultsController;
        if ([src isKindOfClass:[UITableViewController class]]) {
            UITableViewController *srcTV = src;
            [srcTV.tableView reloadData];
        }
    }
}

/** Called from tabBarController:didSelectViewController: */
- (void) didSelectFromTabBar:(UITabBarController *)tabBarController {
    // Partial 'fix' for autolayout bug #32 https://github.com/Burning-Man-Earth/iBurn-iOS/issues/32
    if (self.searchController.active) {
        self.searchController.active = NO;
    }
}

- (void) setupLoadingIndicatorView {
    self.loadingIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    UIBarButtonItem *loadingButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.loadingIndicatorView];
    self.navigationItem.rightBarButtonItem = loadingButtonItem;
}

- (BOOL) shouldAnimateLoadingIndicator {
    if (self.isUpdatingFilters) {
        return YES;
    } else {
        return NO;
    }
}

- (void) refreshLoadingIndicatorViewAnimation {
    if ([self shouldAnimateLoadingIndicator]) {
        [self.loadingIndicatorView startAnimating];
    } else {
        [self.loadingIndicatorView stopAnimating];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupTableView];
    
    // Apple bug: https://github.com/smileyborg/TableViewCellWithAutoLayoutiOS8/issues/10#issuecomment-69694089
    [self.tableView reloadData];
    [self.tableView setNeedsLayout];
    [self.tableView layoutIfNeeded];
    [self.tableView reloadData];
    
    [self setupSearchController];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
    YapDatabase *database = [BRCDatabaseManager sharedInstance].database;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(yapDatabaseModified:)
                                                 name:YapDatabaseModifiedNotification
                                               object:database];
}

- (void) updateViewConstraints {
    if (!self.hasAddedConstraints) {
        NSParameterAssert(self.tableView != nil);
        [self.tableView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
        self.hasAddedConstraints = YES;
    }
    [super updateViewConstraints];
}

- (void) setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundView = nil;
    self.tableView.backgroundView = [[UIView alloc] init];
    self.tableView.backgroundView.backgroundColor = [UIColor whiteColor];
    self.tableView.estimatedRowHeight = 120;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    [self setupCellIdentifiersForTableView:self.tableView];
    [self.view addSubview:self.tableView];
}

- (void) setupCellIdentifiersForTableView:(UITableView*)tableView {
    NSArray *classesToRegister = @[[BRCEventObject class], [BRCDataObject class], [BRCArtObject class]];
    [classesToRegister enumerateObjectsUsingBlock:^(Class viewClass, NSUInteger idx, BOOL *stop) {
        Class cellClass = [BRCDataObjectTableViewCell cellClassForDataObjectClass:viewClass];
        NSString *cellIdentifier = [cellClass cellIdentifier];
        UINib *nib = [UINib nibWithNibName:NSStringFromClass(cellClass) bundle:nil];
        [tableView registerNib:nib forCellReuseIdentifier:cellIdentifier];
    }];
}

// https://github.com/ccabanero/ios-uisearchcontroller-objc/blob/master/ui-searchcontroller-objc/TableViewController.m
// https://developer.apple.com/library/ios/samplecode/TableSearch_UISearchController/Introduction/Intro.html#//apple_ref/doc/uid/TP40014683-Intro-DontLinkElementID_2
- (void) setupSearchController {
    UITableViewController *searchResultsController = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    [self setupCellIdentifiersForTableView:searchResultsController.tableView];

    searchResultsController.tableView.dataSource = self;
    searchResultsController.tableView.delegate = self;
    searchResultsController.tableView.estimatedRowHeight = 120;
    searchResultsController.tableView.rowHeight = UITableViewAutomaticDimension;
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:searchResultsController];
    self.searchController.searchResultsUpdater = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.hidesNavigationBarDuringPresentation = NO;
    self.searchController.delegate = self;
    
    self.definesPresentationContext = YES;
    
    [self.searchController.searchBar sizeToFit];
    self.searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchController.searchBar.delegate = self;
    
    self.tableView.tableHeaderView = self.searchController.searchBar;
}

- (void)setupDatabaseConnection
{
    YapDatabase *database = [BRCDatabaseManager sharedInstance].database;
    self.databaseConnection = [database newConnection];
    [self.databaseConnection beginLongLivedReadTransaction];
    _searchConnection = [database newConnection];
    _searchQueue = [[YapDatabaseSearchQueue alloc] init];
}

- (void) setupMappings {
    YapDatabaseViewMappingGroupFilter groupFilter = ^BOOL(NSString *group, YapDatabaseReadTransaction *transaction) {
        return YES;
    };
    YapDatabaseViewMappingGroupSort groupSort = ^NSComparisonResult(NSString *group1, NSString *group2, YapDatabaseReadTransaction *transaction) {
        return [group1 compare:group2];
    };
    self.mappings = [[YapDatabaseViewMappings alloc] initWithGroupFilterBlock:groupFilter sortBlock:groupSort view:self.viewName];
    _searchMappings = [[YapDatabaseViewMappings alloc] initWithGroupFilterBlock:groupFilter sortBlock:groupSort view:self.searchViewName];
    NSParameterAssert(self.mappings != nil);
    NSParameterAssert(self.searchMappings != nil);
}

- (void) updateMappingsWithCompletionBlock:(dispatch_block_t)completionBlock {
    [self.databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [self.mappings updateWithTransaction:transaction];
        [self.searchMappings updateWithTransaction:transaction];
    } completionBlock:completionBlock];
}

- (void) locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [manager startUpdatingLocation];
    }
}

- (void) setIsUpdatingFilters:(BOOL)isUpdatingFilters {
    _isUpdatingFilters = isUpdatingFilters;
    [self refreshLoadingIndicatorViewAnimation];
}

- (YapDatabaseViewMappings*) mappingsForTableView:(UITableView*)tableView {
    YapDatabaseViewMappings *mappings = nil;
    if ([self isSearchResultsControllerTableView:tableView]) {
        mappings = self.searchMappings;
    } else {
        mappings = self.mappings;
    }
    NSParameterAssert(mappings != nil);
    return mappings;
}

- (BRCDataObject *)dataObjectForIndexPath:(NSIndexPath *)indexPath tableView:(UITableView *)tableView
{
    NSString *viewName = nil;
    YapDatabaseViewMappings *mappings = [self mappingsForTableView:tableView];
    if ([self isSearchResultsControllerTableView:tableView]) {
        viewName = self.searchViewName;
    } else {
        viewName = self.viewName;
    }
    __block BRCDataObject *dataObject = nil;
    [self.databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        YapDatabaseViewTransaction *viewTransaction = [transaction extension:viewName];
        dataObject = [viewTransaction objectAtIndexPath:indexPath withMappings:mappings];
    }];
    return dataObject;
}

- (BOOL)isSearchResultsControllerTableView:(UITableView *)tableView
{
    UITableViewController *src = (UITableViewController*)self.searchController.searchResultsController;
    if (tableView == src.tableView) {
        return YES;
    }
    return NO;
}

- (UIImageView *)imageViewForFavoriteWithImageName:(NSString *)imageName {
    UIImage *image = [[UIImage imageNamed:imageName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeCenter;
    UIColor *tintColor = [[[UIApplication sharedApplication] keyWindow] tintColor];
    imageView.tintColor = tintColor;
    return imageView;
}

- (void) didChangePreferredContentSize:(NSNotification*)notification {
    // this doens't seem to trigger a re-layout of the cells?
    [self.tableView reloadData];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateViewConstraints];
    [PFAnalytics trackEventInBackground:self.title block:nil];
}

- (void) audioPlayerChangedNotification:(NSNotification*)notification {
    [self.tableView reloadData];
}
#pragma - mark UITableViewDataSource Methods

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    if (![self isSearchResultsControllerTableView:tableView])
    {
        NSMutableArray *groups = [NSMutableArray arrayWithArray:[self.mappings allGroups]];
        [groups insertObject:UITableViewIndexSearch atIndex:0];
        return groups;
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    if (![self isSearchResultsControllerTableView:tableView])
    {
        // https://github.com/kharrison/CodeExamples/blob/master/WorldFacts/WorldFacts/UYLCountryTableViewController.m
        if (index > 0)
        {
            // The index is offset by one to allow for the extra search icon inserted at the front
            // of the index
            
            return  [self.mappings sectionForGroup:title];
        }
        else
        {
            // if magnifying glass http://stackoverflow.com/questions/19093168/uitableview-section-index-not-able-to-scroll-to-search-bar-index
            // The first entry in the index is for the search icon so we return section not found
            // and force the table to scroll to the top.
            
            [tableView setContentOffset:CGPointMake(0.0, -tableView.contentInset.top)];
            return NSNotFound;
        }
    }
    return 0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __block BRCDataObject *dataObject = [self dataObjectForIndexPath:indexPath tableView:tableView];
    Class cellClass = [BRCDataObjectTableViewCell cellClassForDataObjectClass:[dataObject class]];
    NSString *cellIdentifier = [cellClass cellIdentifier];
    BRCDataObjectTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    cell.dataObject = dataObject;
    CLLocation *currentLocation = [BRCAppDelegate sharedAppDelegate].locationManager.location;
    [cell updateDistanceLabelFromLocation:currentLocation dataObject:dataObject];
    [cell setFavoriteButtonAction:^(BRCDataObjectTableViewCell *sender) {
        NSIndexPath *indexPath = [tableView indexPathForCell:sender];
        BRCDataObject *dataObject = [self dataObjectForIndexPath:indexPath tableView:tableView];
        dataObject.isFavorite = sender.favoriteButton.selected;
        // not the best place to do this
        if (dataObject.isFavorite) {
            [PFAnalytics brc_trackEventInBackground:@"Favorite" object:dataObject];
        }
        [[BRCDatabaseManager sharedInstance].readWriteConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * transaction) {
            [transaction setObject:dataObject forKey:dataObject.uniqueID inCollection:[[dataObject class] collection]];
            if ([dataObject isKindOfClass:[BRCEventObject class]]) {
                BRCEventObject *event = (BRCEventObject*)dataObject;
                [event refreshCalendarEntry:transaction];
            }
        }];
    }];
    if ([cell isKindOfClass:[BRCArtObjectTableViewCell class]]) {
        BRCArtObjectTableViewCell *artCell = (BRCArtObjectTableViewCell*)cell;
        [artCell configurePlayPauseButton:(BRCArtObject*)dataObject];
    }
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
    YapDatabaseViewMappings *mappings = [self mappingsForTableView:sender];
    NSInteger count = [mappings numberOfSections];
    return count;
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
    YapDatabaseViewMappings *mappings = [self mappingsForTableView:sender];
    NSInteger count = [mappings numberOfItemsInSection:section];
    return count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCDataObject *dataObject = [self dataObjectForIndexPath:indexPath tableView:tableView];
    BRCDetailViewController *detailVC = [[BRCDetailViewController alloc] initWithDataObject:dataObject];
    detailVC.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:detailVC animated:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UISearchResultsUpdating

-(void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchString = [self.searchController.searchBar text];
    if ([searchString length]) {
        searchString = [NSString stringWithFormat:@"%@*",searchString];
        [self.searchQueue enqueueQuery:searchString];
        [self.searchConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            [[transaction ext:self.searchViewName] performSearchWithQueue:self.searchQueue];
        }];
    }
}

#pragma - mark YapDatabseModified

- (void)yapDatabaseModified:(NSNotification *)notification
{
    // Jump to the most recent commit.
    // End & Re-Begin the long-lived transaction atomically.
    // Also grab all the notifications for all the commits that I jump.
    // If the UI is a bit backed up, I may jump multiple commits.
    
    NSArray *notifications = [self.databaseConnection beginLongLivedReadTransaction];
    
    [self updateMappingsWithCompletionBlock:^{
        [self.tableView reloadData];
        UITableViewController *src = (UITableViewController*)self.searchController.searchResultsController;
        [src.tableView reloadData];
    }];
    return;
#warning TODO fix animations ^^^
    
    // Process the notification(s),
    // and get the change-set(s) as applies to my view and mappings configuration.
    
    NSArray *sectionChanges = nil;
    NSArray *rowChanges = nil;
    
    YapDatabaseViewConnection *viewConnection = [self.databaseConnection ext:self.viewName];
    NSUInteger sizeEstimate = [viewConnection numberOfRawChangesForNotifications:notifications];
    if (sizeEstimate > 150) {
        [self updateMappingsWithCompletionBlock:^{
            [self.tableView reloadData];
        }];
        return;
    }
    
    [viewConnection getSectionChanges:&sectionChanges
                           rowChanges:&rowChanges
                     forNotifications:notifications
                         withMappings:self.mappings];
    
    // No need to update mappings.
    // The above method did it automatically.
    
    if ([sectionChanges count] == 0 & [rowChanges count] == 0)
    {
        // Nothing has changed that affects our tableView
        return;
    }
    
    // If there are too many row changes, just reload the data instead of animating
    if ([rowChanges count] > 50) {
        [self.tableView reloadData];
        return;
    }
    
    [self.tableView beginUpdates];
    
    for (YapDatabaseViewSectionChange *sectionChange in sectionChanges)
    {
        switch (sectionChange.type)
        {
            case YapDatabaseViewChangeDelete :
            {
                [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionChange.index]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeInsert :
            {
                [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionChange.index]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            default:
                break;
        }
    }
    
    for (YapDatabaseViewRowChange *rowChange in rowChanges)
    {
        switch (rowChange.type)
        {
            case YapDatabaseViewChangeDelete :
            {
                [self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeInsert :
            {
                [self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeMove :
            {
                [self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                [self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeUpdate :
            {
                [self.tableView reloadRowsAtIndexPaths:@[ rowChange.indexPath ]
                                      withRowAnimation:UITableViewRowAnimationNone];
                break;
            }
        }
    }
    
    [self.tableView endUpdates];
}


@end
