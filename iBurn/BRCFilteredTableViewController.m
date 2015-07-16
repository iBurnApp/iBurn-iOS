 //
//  BRCFilteredTableViewController.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCFilteredTableViewController.h"
#import "YapDatabaseViewTransaction.h"
#import "YapDatabaseViewMappings.h"
#import "YapDatabaseViewConnection.h"
#import "YapDatabaseFullTextSearch.h"
#import "YapDatabase.h"
#import "BRCDatabaseManager.h"
#import "BRCDataObject.h"
#import "BRCDetailViewController.h"
#import "BRCDataObjectTableViewCell.h"
#import "BRCFilteredTableViewController.h"
#import "BRCFilteredTableViewController_Private.h"
#import "UIColor+iBurn.h"
#import "PureLayout.h"
#import "CLLocationManager+iBurn.h"
#import "BRCEventObject.h"
#import "YapDatabaseFilteredViewTransaction.h"
#import "BRCAppDelegate.h"
#import "YapDatabaseSearchQueue.h"
#import "YapDatabaseSearchResultsViewTransaction.h"

@interface BRCFilteredTableViewController () <UIToolbarDelegate, CLLocationManagerDelegate>
@property (nonatomic, strong, readonly) YapDatabaseConnection *searchConnection;
@property (nonatomic, strong, readonly) YapDatabaseSearchQueue *searchQueue;
@property (nonatomic, strong) UIImageView *favoriteImageView;
@property (nonatomic, strong) UIImageView *notYetFavoriteImageView;
@end

@implementation BRCFilteredTableViewController

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithViewClass:(Class)viewClass viewName:(NSString *)viewName searchViewName:(NSString *)searchViewName
{
    if (self = [super initWithStyle:UITableViewStylePlain]) {
        _viewClass = viewClass;
        _viewName = viewName;
        _searchViewName = searchViewName;
        [self setupLoadingIndicatorView];
        [self setupDatabaseConnection];
        [self setupMappings];
        [self updateMappingsWithCompletionBlock:nil];
    }
    return self;
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
    self.favoriteImageView = [self imageViewForFavoriteWithImageName:@"BRCHeartFilledIcon"];
    self.notYetFavoriteImageView = [self imageViewForFavoriteWithImageName:@"BRCHeartIcon"];
    
    [self setupTableView];
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

- (void) setupTableView {
    self.tableView.backgroundView = nil;
    self.tableView.backgroundView = [[UIView alloc] init];
    self.tableView.backgroundView.backgroundColor = [UIColor whiteColor];
    self.tableView.estimatedRowHeight = 120;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    [self setupCellIdentifiersForTableView:self.tableView];
}

- (void) setupCellIdentifiersForTableView:(UITableView*)tableView {
    NSArray *classesToRegister = @[[BRCEventObject class], [BRCDataObject class]];
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
        if (self.viewClass == [BRCDataObject class]) {
            // special case where filtering by all objects
            return YES;
        }
        if ([group isEqualToString:[self.viewClass collection]]) {
            return YES;
        }
        return NO;
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

- (UIImageView *) imageViewForFavoriteStatus:(BOOL)isFavorite {
    UIImageView *viewState = nil;
    if (isFavorite) {
        viewState = self.favoriteImageView;
    } else {
        viewState = self.notYetFavoriteImageView;
    }
    return viewState;
}

- (void) didChangePreferredContentSize:(NSNotification*)notification {
    // this doens't seem to trigger a re-layout of the cells?
    [self.tableView reloadData];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma - mark UITableViewDataSource Methods

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __block BRCDataObject *dataObject = [self dataObjectForIndexPath:indexPath tableView:tableView];
    Class cellClass = [BRCDataObjectTableViewCell cellClassForDataObjectClass:[dataObject class]];
    NSString *cellIdentifier = [cellClass cellIdentifier];
    BRCDataObjectTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    cell.dataObject = dataObject;
    CLLocation *currentLocation = [BRCAppDelegate appDelegate].locationManager.location;
    [cell updateDistanceLabelFromLocation:currentLocation];
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
