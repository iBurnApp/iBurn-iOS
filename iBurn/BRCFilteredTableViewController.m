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
#import "MCSwipeTableViewCell.h"
#import "CLLocationManager+iBurn.h"
#import "BRCEventObject.h"
#import "YapDatabaseFilteredViewTransaction.h"
#import "BRCAppDelegate.h"

@interface BRCFilteredTableViewController () <UIToolbarDelegate, MCSwipeTableViewCellDelegate, CLLocationManagerDelegate>
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, strong) UISearchDisplayController *searchController;
@property (nonatomic) BOOL didUpdateConstraints;
@property (nonatomic, strong) UIImageView *favoriteImageView;
@property (nonatomic, strong) UIImageView *notYetFavoriteImageView;

@property (nonatomic, strong) UIActivityIndicatorView *searchActivityIndicatorView;
@end

@implementation BRCFilteredTableViewController



- (instancetype)initWithViewClass:(Class)viewClass viewName:(NSString *)viewName ftsName:(NSString *)ftsName
{
    if (self = [super initWithStyle:UITableViewStylePlain]) {
        _viewClass = viewClass;
        _viewName = viewName;
        _ftsName = ftsName;
        [self setupLoadingIndicatorView];
        [self setupDatabaseConnection];
        [self setupMappings];
        [self updateMappingsWithCompletionBlock:nil];
    }
    return self;
}

- (void) setupSearchIndicator {
    self.searchActivityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.searchActivityIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchActivityIndicatorView];
}

- (UIBarPosition)positionForBar:(id <UIBarPositioning>)bar {
    return UIBarPositionTopAttached;
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
    
    self.favoriteImageView = [self imageViewForFavoriteWithImageName:@"BRCDarkStar"];
    self.notYetFavoriteImageView = [self imageViewForFavoriteWithImageName:@"BRCLightStar"];
    
    self.tableView.backgroundView = nil;
    self.tableView.backgroundView = [[UIView alloc] init];
    self.tableView.backgroundView.backgroundColor = [UIColor whiteColor];
    
    [self setupSearchIndicator];
    
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    searchBar.delegate = self;
    searchBar.searchBarStyle = UISearchBarStyleMinimal;
    
    self.searchController = [[UISearchDisplayController alloc] initWithSearchBar:searchBar contentsController:self];
    self.searchController.delegate = self;
    self.searchController.searchResultsDataSource = self;
    self.searchController.searchResultsDelegate = self;
    
    self.tableView.tableHeaderView = searchBar;
    
    [self updateViewConstraints];
    
    UINib *nib = [UINib nibWithNibName:NSStringFromClass([self cellClass]) bundle:nil];
    [[self tableView] registerNib:nib forCellReuseIdentifier:[[self cellClass] cellIdentifier]];
    [self.searchController.searchResultsTableView registerNib:nib forCellReuseIdentifier:[[self cellClass] cellIdentifier]];
}

- (void)setupDatabaseConnection
{
    self.databaseConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
    self.databaseConnection.objectPolicy = YapDatabasePolicyShare;
    [self.databaseConnection beginLongLivedReadTransaction];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(yapDatabaseModified:)
                                                 name:YapDatabaseModifiedNotification
                                               object:self.databaseConnection.database];
}

- (void) setupMappings {
    self.mappings = [[YapDatabaseViewMappings alloc] initWithGroupFilterBlock:^BOOL(NSString *group, YapDatabaseReadTransaction *transaction) {
        if (self.viewClass == [BRCDataObject class]) {
            // special case where filtering by all objects
            return YES;
        }
        if ([group isEqualToString:[self.viewClass collection]]) {
            return YES;
        }
        return NO;
    } sortBlock:^NSComparisonResult(NSString *group1, NSString *group2, YapDatabaseReadTransaction *transaction) {
        return [group1 compare:group2];
    } view:self.viewName];
}

- (void) updateMappingsWithCompletionBlock:(dispatch_block_t)completionBlock {
    [self.databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [self.mappings updateWithTransaction:transaction];
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

- (Class) cellClass {
    return [BRCDataObjectTableViewCell class];
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    if (self.didUpdateConstraints) {
        return;
    }
    [self.searchActivityIndicatorView autoCenterInSuperview];
    [self.searchActivityIndicatorView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
    self.didUpdateConstraints = YES;
}

- (BRCDataObject *)dataObjectForIndexPath:(NSIndexPath *)indexPath tableView:(UITableView *)tableView
{
    __block BRCDataObject *dataObject = nil;
    if ([self isSearchResultsControllerTableView:tableView] && [self.searchResults count] > indexPath.row) {
        dataObject = self.searchResults[indexPath.row];
    }
    else {
        [self.databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            YapDatabaseViewTransaction *viewTransaction = [transaction extension:self.viewName];
            dataObject = [viewTransaction objectAtIndexPath:indexPath withMappings:self.mappings];
        }];
    }
    
    return dataObject;
}

- (BOOL)isSearchResultsControllerTableView:(UITableView *)tableView
{
    if ([tableView isEqual:self.searchDisplayController.searchResultsTableView]) {
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


#pragma - mark UITableViewDataSource Methods

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCDataObjectTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[[self cellClass] cellIdentifier] forIndexPath:indexPath];
    __block BRCDataObject *dataObject = [self dataObjectForIndexPath:indexPath tableView:tableView];
    [cell setStyleFromDataObject:dataObject];
    CLLocation *currentLocation = [BRCAppDelegate appDelegate].locationManager.location;
    [cell updateDistanceLabelFromLocation:currentLocation toLocation:dataObject.location];
    // Adding gestures per state basis.
    UIImageView *viewState = [self imageViewForFavoriteStatus:dataObject.isFavorite];
    UIColor *color = [UIColor brc_navBarColor];
    [cell setSwipeGestureWithView:viewState color:color mode:MCSwipeTableViewCellModeSwitch state:MCSwipeTableViewCellState1 completionBlock:^(MCSwipeTableViewCell *swipeCell, MCSwipeTableViewCellState state, MCSwipeTableViewCellMode mode) {
        BRCDataObjectTableViewCell *dataCell = (BRCDataObjectTableViewCell*)swipeCell;
        [self.databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            dataObject = [[transaction objectForKey:dataObject.uniqueID inCollection:[[dataObject class] collection]] copy];
        }];
        dataObject.isFavorite = !dataObject.isFavorite;
        [dataCell setStyleFromDataObject:dataObject];
        [[BRCDatabaseManager sharedInstance].readWriteConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            if ([dataObject isKindOfClass:[BRCEventObject class]]) {
                BRCEventObject *event = (BRCEventObject*)dataObject;
                if (event.isFavorite) {
                    [BRCEventObject scheduleNotificationForEvent:event transaction:transaction];
                } else {
                    [BRCEventObject cancelScheduledNotificationForEvent:event transaction:transaction];
                }
            }
            [transaction setObject:dataObject forKey:dataObject.uniqueID inCollection:[[dataObject class] collection]];
        } completionBlock:nil];
    }];
    cell.delegate = self;
    return cell;
}

- (void)swipeTableViewCell:(BRCDataObjectTableViewCell *)cell didSwipeWithPercentage:(CGFloat)percentage {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    __block BRCDataObject *dataObject = [self dataObjectForIndexPath:indexPath tableView:self.tableView];
    // We want to switch states to give a hint of the future value
    // is there a way to optimize this further?
    if (percentage >= cell.firstTrigger) {
        BOOL inverseFavorite = !dataObject.isFavorite;
        cell.view1 = [self imageViewForFavoriteStatus:inverseFavorite];
        [cell setTitleLabelBold:inverseFavorite];
    } else if (percentage < cell.firstTrigger) {
        BOOL isFavorite = dataObject.isFavorite;
        cell.view1 = [self imageViewForFavoriteStatus:isFavorite];
        [cell setTitleLabelBold:isFavorite];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
    if ([self isSearchResultsControllerTableView:sender]) {
        return 1;
    }
    return [self.mappings numberOfSections];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [[self cellClass] cellHeight];
}

- (CGFloat) tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [[self cellClass] cellHeight];
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = 0;
    if ([self isSearchResultsControllerTableView:sender]) {
        count = [self.searchResults count];
    } else {
        count = [self.mappings numberOfItemsInSection:section];
    }
    return count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCDataObject *dataObject = [self dataObjectForIndexPath:indexPath tableView:tableView];
    
    BRCDetailViewController *detailVC = [[BRCDetailViewController alloc] initWithDataObject:dataObject];
    [self.navigationController pushViewController:detailVC animated:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma - mark UISearchBarDelegate Methods

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [self.searchDisplayController setActive:YES animated:YES];
}

#pragma - mark  UISearchDisplayDelegate Methods

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    if ([searchString length]) {
        NSMutableArray *tempSearchResults = [NSMutableArray array];
        searchString = [NSString stringWithFormat:@"%@*",searchString];
        [self.searchActivityIndicatorView startAnimating];
        [self.view bringSubviewToFront:self.searchActivityIndicatorView];
        [self.databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
            [[transaction ext:self.ftsName] enumerateKeysAndObjectsMatching:searchString usingBlock:^(NSString *collection, NSString *key, id object, BOOL *stop) {
                if (object) {
                    [tempSearchResults addObject:object];
                }
            }];
        } completionBlock:^{
            self.searchResults = tempSearchResults;
            [self.searchActivityIndicatorView stopAnimating];
            [controller.searchResultsTableView reloadData];
        }];
    } else {
        self.searchResults = nil;
    }
    return NO;
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
