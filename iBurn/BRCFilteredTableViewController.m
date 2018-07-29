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
#import "BRCArtObjectTableViewCell.h"
#import "iBurn-Swift.h"
@import AVFoundation;

@interface BRCFilteredTableViewController () <UIToolbarDelegate, CLLocationManagerDelegate, UIPageViewControllerDelegate>
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(databaseExtensionRegistered:) name:BRCDatabaseExtensionRegisteredNotification object:BRCDatabaseManager.shared];
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
    [tableView registerCustomCellClasses];
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
    YapDatabase *database = BRCDatabaseManager.shared.database;
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
    _viewHandler = [[YapViewHandler alloc] initWithManager:BRCDatabaseManager.shared.longLived delegate:self viewName:self.viewName groupFilter:groupFilter groupSort:groupSort];
    _searchViewHandler = [[YapViewHandler alloc] initWithManager:BRCDatabaseManager.shared.longLived delegate:self viewName:self.searchViewName groupFilter:groupFilter groupSort:groupSort];
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

- (YapViewHandler*) viewHandlerForTableView:(UITableView*)tableView {
    YapViewHandler *viewHandler = nil;
    if ([self isSearchResultsControllerTableView:tableView]) {
        viewHandler = self.searchViewHandler;
    } else {
        viewHandler = self.viewHandler;
    }
    return viewHandler;
}

- (DataObjectWithMetadata *)dataObjectForIndexPath:(NSIndexPath *)indexPath tableView:(UITableView *)tableView
{
    YapViewHandler *viewHandler = [self viewHandlerForTableView:tableView];
    __block BRCObjectMetadata *metadata = nil;
    BRCDataObject *dataObject = [viewHandler objectAtIndexPath:indexPath readBlock:^(BRCDataObject * _Nonnull dataObject, YapDatabaseReadTransaction * _Nonnull transaction) {
        metadata = [dataObject metadataWithTransaction:transaction];
    }];
    DataObjectWithMetadata *data = [[DataObjectWithMetadata alloc] initWithObject:dataObject metadata:metadata];
    return data;
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
    [self.navigationController.navigationBar setColorTheme:BRCImageColors.plain animated:YES];
}

- (void) audioPlayerChangedNotification:(NSNotification*)notification {
    [self.tableView reloadData];
}
#pragma - mark UITableViewDataSource Methods

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    if (![self isSearchResultsControllerTableView:tableView])
    {
        NSMutableArray *groups = [NSMutableArray arrayWithArray:[self.viewHandler allGroups]];
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
            
            return  [self.viewHandler sectionForGroup:title];
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

//- (CGFloat) tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
//    __block DataObjectWithMetadata *data = [self dataObjectForIndexPath:indexPath tableView:tableView];
//    if ([data.object isKindOfClass:BRCArtObject.class]) {
//        BRCArtObject *art = (BRCArtObject*)data.object;
//        if (art.thumbnailURL) {
//            return 180;
//        }
//    }
//    return UITableViewAutomaticDimension;
//}
//
//- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
//    __block DataObjectWithMetadata *data = [self dataObjectForIndexPath:indexPath tableView:tableView];
//    if ([data.object isKindOfClass:BRCArtObject.class]) {
//        BRCArtObject *art = (BRCArtObject*)data.object;
//        if (art.thumbnailURL) {
//            return 180;
//        }
//    }
//    return UITableViewAutomaticDimension;
//}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DataObjectWithMetadata *data = [self dataObjectForIndexPath:indexPath tableView:tableView];
    BRCDataObject *dataObject = data.object;
    NSString *cellIdentifier = dataObject.tableCellIdentifier;
    BRCDataObjectTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    [cell setDataObject:dataObject metadata:data.metadata];
    CLLocation *currentLocation = BRCAppDelegate.shared.locationManager.location;
    [cell updateDistanceLabelFromLocation:currentLocation dataObject:dataObject];
    [cell setFavoriteButtonAction:^(BRCDataObjectTableViewCell *sender) {
        NSIndexPath *indexPath = [tableView indexPathForCell:sender];
        DataObjectWithMetadata *data = [self dataObjectForIndexPath:indexPath tableView:tableView];
        BRCDataObject *dataObject = data.object;
        BOOL isFavorite = sender.favoriteButton.selected;
        [BRCDatabaseManager.shared.readWriteConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * transaction) {
            BRCObjectMetadata *metadata = [[dataObject metadataWithTransaction:transaction] copy];
            metadata.isFavorite = isFavorite;
            [dataObject replaceMetadata:metadata transaction:transaction];
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
    YapViewHandler *viewHandler = [self viewHandlerForTableView:sender];
    NSInteger count = [viewHandler numberOfSections];
    return count;
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
    YapViewHandler *viewHandler = [self viewHandlerForTableView:sender];
    NSInteger count = [viewHandler numberOfItemsInSection:section];
    return count;
}

- (void)tableView:(UITableView *)tableView prefetchRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
//    NSMutableArray *urls = [NSMutableArray arrayWithCapacity:indexPaths.count];
//    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//        DataObjectWithMetadata *data = [self dataObjectForIndexPath:obj tableView:tableView];
//        if ([data.object isKindOfClass:BRCArtObject.class]) {
//            BRCArtObject *art = (BRCArtObject*)data.object;
//            if (art.thumbnailURL) {
//                [urls addObject:art.thumbnailURL];
//            }
//        }
//    }];
//    [BRCDataObject prefetchImageURLs:urls];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DataObjectWithMetadata *data = [self dataObjectForIndexPath:indexPath tableView:tableView];
    BRCDataObject *dataObject = data.object;
    BRCDetailViewController *detailVC = [[BRCDetailViewController alloc] initWithDataObject:dataObject];
    detailVC.indexPath = indexPath;
    detailVC.hidesBottomBarWhenPushed = YES;
    BRCImageColors *colors = detailVC.colors;
    UIPageViewController *pageVC = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
    pageVC.dataSource = self;
    pageVC.delegate = self;
    pageVC.hidesBottomBarWhenPushed = YES;
    self.navigationController.navigationBar.translucent = NO;
    UINavigationBar *navBar = self.navigationController.navigationBar;
    [navBar setColorTheme:colors animated:YES];

    [pageVC setViewControllers:@[detailVC] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
    [pageVC copyChildParameters];
    [self.navigationController pushViewController:pageVC animated:YES];
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

#pragma mark UIPageViewControllerDelegate

// Sent when a gesture-initiated transition ends. The 'finished' parameter indicates whether the animation finished, while the 'completed' parameter indicates whether the transition completed or bailed out (if the user let go early).
- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed {
    [pageViewController copyChildParameters];
}

#pragma mark UIPageViewControllerDataSource

- (nullable UIViewController*) pageViewController:(UIPageViewController *)pageViewController viewControllerNearViewController:(UIViewController *)viewController direction:(BRCIndexPathDirection)direction {
    if (![viewController isKindOfClass:BRCDetailViewController.class]) {
        return nil;
    }
    BRCDetailViewController *detailVC = (BRCDetailViewController*)viewController;
    NSIndexPath *oldIndex = detailVC.indexPath;
    if (!oldIndex) {
        return nil;
    }
    NSIndexPath *newIndex = [oldIndex nextIndexPathWithDirection:direction tableView:self.tableView];
    if (!newIndex) {
        return nil;
    }
    DataObjectWithMetadata *data = [self dataObjectForIndexPath:newIndex tableView:self.tableView];
    BRCDataObject *dataObject = data.object;
    if (!dataObject) {
        return nil;
    }
    BRCDetailViewController *newDetailVC = [[BRCDetailViewController alloc] initWithDataObject:dataObject];
    newDetailVC.indexPath = newIndex;
    [self.tableView scrollToRowAtIndexPath:newIndex atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    return newDetailVC;
}

- (nullable UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    return [self pageViewController:pageViewController viewControllerNearViewController:viewController direction:BRCIndexPathDirectionBefore];
}

- (nullable UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    return [self pageViewController:pageViewController viewControllerNearViewController:viewController direction:BRCIndexPathDirectionAfter];
}

// MARK: YapViewHandlerDelegate

- (void) didSetupMappings:(YapViewHandler *)handler {
    if (handler == self.viewHandler) {
        [self.tableView reloadData];
    } else if (handler == self.searchViewHandler) {
        UITableViewController *src = (UITableViewController*)self.searchController.searchResultsController;
        [src.tableView reloadData];
    }
}

- (void) didReceiveChanges:(YapViewHandler *)handler sectionChanges:(NSArray<YapDatabaseViewSectionChange *> *)sectionChanges rowChanges:(NSArray<YapDatabaseViewRowChange *> *)rowChanges {
    if (handler == self.viewHandler) {
        [self.tableView handleYapViewChangesWithSectionChanges:sectionChanges rowChanges:rowChanges completion:nil];
    } else if (handler == self.searchViewHandler) {
        UITableViewController *src = (UITableViewController*)self.searchController.searchResultsController;
        [src.tableView handleYapViewChangesWithSectionChanges:sectionChanges rowChanges:rowChanges completion:nil];
    }
}

@end

@implementation DataObjectWithMetadata
- (instancetype) initWithObject:(BRCDataObject*)object metadata:(BRCObjectMetadata*)metadata {
    NSParameterAssert(object && metadata);
    if (self = [super init]) {
        _object = object;
        _metadata = metadata;
    }
    return self;
}
@end
