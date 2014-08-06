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

@interface BRCFilteredTableViewController () <UIToolbarDelegate, MCSwipeTableViewCellDelegate, CLLocationManagerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, strong) UISearchDisplayController *searchController;
@property (nonatomic) BOOL didUpdateConstraints;
@property (nonatomic) BOOL updatingDistanceInformation;
@property (nonatomic) UIToolbar *sortControlToolbar;
@property (nonatomic, strong) UIImageView *navBarHairlineImageView;
@property (nonatomic, strong) UIImageView *favoriteImageView;
@property (nonatomic, strong) UIImageView *notYetFavoriteImageView;
@property (nonatomic, strong) NSMutableArray *itemsFilteredByDistance;
@property (nonatomic, strong) CLLocation *lastDistanceUpdateLocation;
@property (nonatomic, strong) NSString *ftsExtensionName;
@end

@implementation BRCFilteredTableViewController

- (instancetype)init
{
    if (self = [super init]) {
        self.segmentedControl = [[UISegmentedControl alloc] init];
        self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
        self.segmentedControl.selectedSegmentIndex = 0;
        
        [self.segmentedControl addTarget:self action:@selector(didChangeValueForSegmentedControl:) forControlEvents:UIControlEventValueChanged];
        
        self.sortControlToolbar = [[UIToolbar alloc] init];
        self.sortControlToolbar.delegate = self;
        self.sortControlToolbar.translatesAutoresizingMaskIntoConstraints = NO;
        [self.sortControlToolbar addSubview:self.segmentedControl];
    }
    return self;
}

- (UIBarPosition)positionForBar:(id <UIBarPositioning>)bar {
    return UIBarPositionTopAttached;
}

- (void) setupLocationManager {
    self.locationManager = [CLLocationManager brc_locationManager];
    self.locationManager.delegate = self;
    [self.locationManager startUpdatingLocation];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupLocationManager];
    [self setupDatabaseConnection];
    [self registerFullTextSearchExtension];
    [self updateAllMappingsFromLocation:self.locationManager.location];
    self.navBarHairlineImageView = [self findHairlineImageViewUnder:self.navigationController.navigationBar];
    
    self.favoriteImageView = [self imageViewForFavoriteWithImageName:@"BRCDarkStar"];
    self.notYetFavoriteImageView = [self imageViewForFavoriteWithImageName:@"BRCLightStar"];

    NSArray *segmentedControlInfo = [self segmentedControlInfo];
    [segmentedControlInfo enumerateObjectsUsingBlock:^(NSArray *infoArray, NSUInteger idx, BOOL *stop) {
        NSString *title = [infoArray firstObject];
        [self.segmentedControl insertSegmentWithTitle:title atIndex:idx animated:NO];
    }];
    self.segmentedControl.selectedSegmentIndex = 0;
    
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundView = nil;
    self.tableView.backgroundView = [[UIView alloc] init];
    self.tableView.backgroundView.backgroundColor = [UIColor whiteColor];
    
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    searchBar.delegate = self;
    searchBar.searchBarStyle = UISearchBarStyleMinimal;
    
    self.searchController = [[UISearchDisplayController alloc] initWithSearchBar:searchBar contentsController:self];
    self.searchController.delegate = self;
    self.searchController.searchResultsDataSource = self;
    self.searchController.searchResultsDelegate = self;
    
    self.tableView.tableHeaderView = searchBar;
    
    [self.view addSubview:self.sortControlToolbar];
    [self.view addSubview:self.tableView];
    
    [self updateViewConstraints];
    
    UINib *nib = [UINib nibWithNibName:NSStringFromClass([self cellClass]) bundle:nil];
    [[self tableView] registerNib:nib forCellReuseIdentifier:[[self cellClass] cellIdentifier]];
    [self.searchController.searchResultsTableView registerNib:nib forCellReuseIdentifier:[[self cellClass] cellIdentifier]];
}

// Remove 1px hairline below UINavigationBar
// http://stackoverflow.com/a/19227158/805882
- (UIImageView *)findHairlineImageViewUnder:(UIView *)view {
    if ([view isKindOfClass:UIImageView.class] && view.bounds.size.height <= 1.0) {
        return (UIImageView *)view;
    }
    for (UIView *subview in view.subviews) {
        UIImageView *imageView = [self findHairlineImageViewUnder:subview];
        if (imageView) {
            return imageView;
        }
    }
    return nil;
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

- (void) registerFullTextSearchExtension {
    NSArray *indexedProperties = @[NSStringFromSelector(@selector(title))];
    NSString *ftsName = [BRCDatabaseManager fullTextSearchExtensionNameForClass:self.viewClass withIndexedProperties:indexedProperties];
    YapDatabaseFullTextSearch *fullTextSearch = [BRCDatabaseManager fullTextSearchForClass:self.viewClass withIndexedProperties:indexedProperties];
    self.ftsExtensionName = ftsName;
    [[BRCDatabaseManager sharedInstance].database asyncRegisterExtension:fullTextSearch withName:ftsName completionBlock:^(BOOL ready) {
        NSLog(@"%@ ready %d", ftsName, ready);
    }];
}

// Override this in subclasses
- (void) setupMappingsDictionaryFromLocation:(CLLocation*)fromLocation {
    NSMutableArray *viewNames = [NSMutableArray arrayWithCapacity:2];
    NSString *distanceViewName = nil;
    BOOL distancePreviouslyRegistered = NO;
    [[BRCDatabaseManager sharedInstance] databaseViewForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeDistance fromLocation:fromLocation extensionName:&distanceViewName previouslyRegistered:&distancePreviouslyRegistered];
    [viewNames addObject:distanceViewName];
    
    NSString *favoritesViewName = nil;
    BOOL favoritesPreviouslyRegistered = NO;
    [[BRCDatabaseManager sharedInstance] filteredDatabaseViewForType:BRCDatabaseFilteredViewTypeFavorites parentViewName:distanceViewName extensionName:&favoritesViewName previouslyRegistered:&favoritesPreviouslyRegistered];
    [viewNames addObject:favoritesViewName];
    
    NSMutableDictionary *mutableMappingsDictionary = [NSMutableDictionary dictionaryWithCapacity:viewNames.count];
    
    [viewNames enumerateObjectsUsingBlock:^(NSString *viewName, NSUInteger idx, BOOL *stop) {
        YapDatabaseViewMappings *mappings = [[YapDatabaseViewMappings alloc] initWithGroups:@[[self.viewClass collection]] view:viewName];
        [mutableMappingsDictionary setObject:mappings forKey:viewName];
    }];
    self.mappingsDictionary = mutableMappingsDictionary;
}

- (void) updateAllMappingsFromLocation:(CLLocation*)fromLocation {
    [self setupMappingsDictionaryFromLocation:fromLocation];
    [self.databaseConnection beginLongLivedReadTransaction];
    [self.databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [self.mappingsDictionary enumerateKeysAndObjectsUsingBlock:^(id key, YapDatabaseViewMappings *mappings, BOOL *stop) {
            [mappings updateWithTransaction:transaction];
        }];
    }];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([self shouldRefreshDistanceInformationForNewLocation:self.locationManager.location]) {
        [self refreshDistanceInformationFromLocation:self.locationManager.location];
    }
    self.navBarHairlineImageView.hidden = YES;
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navBarHairlineImageView.hidden = NO;
}


- (void) locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorized) {
        [manager startUpdatingLocation];
    }
}

- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation *recentLocation = [locations lastObject];
    if (!recentLocation) {
        return;
    }
    if ([self shouldRefreshDistanceInformationForNewLocation:recentLocation]) {
        if (!self.updatingDistanceInformation) {
            self.updatingDistanceInformation = YES;
            [self refreshDistanceInformationFromLocation:recentLocation];
        }
    }
}

- (BOOL) shouldRefreshDistanceInformationForNewLocation:(CLLocation*)newLocation {
    if (!self.lastDistanceUpdateLocation) {
        return YES;
    }
    if (!newLocation) {
        return YES;
    }
    CLLocationDistance distanceSinceLastDistanceUpdate = [self.lastDistanceUpdateLocation distanceFromLocation:newLocation];
    
    CLLocationDistance minimumLocationUpdateDistance = 5; // 5 meters
    
    if (distanceSinceLastDistanceUpdate > minimumLocationUpdateDistance) {
        return YES;
    }
    return NO;
}

- (void) registerDynamicViewsFromLocation:(CLLocation*)location {
    // Registering Distance View and Filtered Subviews
    NSString *distanceViewName = nil;
    YapDatabaseView *distanceView = [[BRCDatabaseManager sharedInstance] databaseViewForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeDistance fromLocation:location extensionName:&distanceViewName previouslyRegistered:NULL];
    [[BRCDatabaseManager sharedInstance].database asyncRegisterExtension:distanceView withName:distanceViewName completionBlock:^(BOOL ready) {
        NSLog(@"%@ ready %d", distanceViewName, ready);
        if (ready && self.viewClass == [BRCEventObject class]) {
            NSString *filteredDistanceViewName = nil;
            YapDatabaseFilteredView *filteredDistanceView = [[BRCDatabaseManager sharedInstance] filteredDatabaseViewForType:BRCDatabaseFilteredViewTypeEventExpirationAndType parentViewName:distanceViewName extensionName:&filteredDistanceViewName previouslyRegistered:NULL];
            [[BRCDatabaseManager sharedInstance].database asyncRegisterExtension:filteredDistanceView withName:filteredDistanceViewName completionBlock:^(BOOL ready) {
                NSLog(@"%@ ready %d", filteredDistanceViewName, ready);
            }];
        }
    }];
}

- (void) refreshDistanceInformationFromLocation:(CLLocation*)fromLocation {
    NSString *distanceViewName = nil;
    [[BRCDatabaseManager sharedInstance] databaseViewForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeDistance fromLocation:fromLocation extensionName:&distanceViewName previouslyRegistered:nil];
    NSLog(@"Unregistering distance view: %@", distanceViewName);
    [[BRCDatabaseManager sharedInstance].database asyncUnregisterExtension:distanceViewName completionBlock:^{
        NSLog(@"Unregistered distance view: %@", distanceViewName);
        __block YapDatabaseView *distanceView = [[BRCDatabaseManager sharedInstance] databaseViewForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeDistance fromLocation:(CLLocation*)fromLocation extensionName:nil previouslyRegistered:nil];
        NSLog(@"Registering distance view: %@", distanceViewName);
        [[BRCDatabaseManager sharedInstance].database asyncRegisterExtension:distanceView withName:distanceViewName completionBlock:^(BOOL ready) {
            NSLog(@"%@ ready %d", distanceViewName, ready);
            YapDatabaseViewMappings *distanceMappings = [self.mappingsDictionary objectForKey:distanceViewName];
            [self.databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
                [distanceMappings updateWithTransaction:transaction];
            } completionBlock:^{
                NSLog(@"Finished updating distance view: %@", distanceView);
                self.updatingDistanceInformation = NO;
                self.lastDistanceUpdateLocation = fromLocation;
                [self.tableView reloadData];
            }];
        }];
    }];
}

- (NSString*) selectedDataObjectGroup {
    return [[self viewClass] collection];
}

- (Class) cellClass {
    return [BRCDataObjectTableViewCell class];
}

- (NSArray *) segmentedControlInfo {
    NSString *distanceViewName = nil;
    [[BRCDatabaseManager sharedInstance] databaseViewForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeDistance fromLocation:nil extensionName:&distanceViewName previouslyRegistered:nil];
    NSString *favoritesViewName = nil;
    [[BRCDatabaseManager sharedInstance] filteredDatabaseViewForType:BRCDatabaseFilteredViewTypeFavorites parentViewName:distanceViewName extensionName:&favoritesViewName previouslyRegistered:nil];
    return @[@[@"Distance", distanceViewName],
             @[@"Favorites", favoritesViewName]];
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    if (self.didUpdateConstraints) {
        return;
    }
    [self.sortControlToolbar autoPinToTopLayoutGuideOfViewController:self withInset:0];
    [self.sortControlToolbar autoMatchDimension:ALDimensionWidth toDimension:ALDimensionWidth ofView:self.view];
    [self.sortControlToolbar autoSetDimension:ALDimensionHeight toSize:40];
    [self.sortControlToolbar autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [self.segmentedControl autoCenterInSuperview];
    [self.segmentedControl autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:10.0f];
    [self.segmentedControl autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:10.0f];
    [self.segmentedControl autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:5.0f];
    [self.segmentedControl autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:5.0f];

    [self.tableView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.sortControlToolbar withOffset:1.0f];
    [self.tableView autoPinToBottomLayoutGuideOfViewController:self withInset:0];
    [self.tableView autoMatchDimension:ALDimensionWidth toDimension:ALDimensionWidth ofView:self.view];
    [self.tableView autoAlignAxisToSuperviewAxis:ALAxisVertical];
    self.didUpdateConstraints = YES;
}

- (YapDatabaseViewMappings*) activeMappings {
    NSString *activeExtensionName = [self activeExtensionNameForSelectedSegmentIndex];
    YapDatabaseViewMappings *activeMappings = [self.mappingsDictionary objectForKey:activeExtensionName];
    return activeMappings;
}

- (NSDictionary*) inactiveMappingsDictionary {
    NSString *activeMappingsName = [self activeExtensionNameForSelectedSegmentIndex];
    NSMutableDictionary *mutableMappings = [self.mappingsDictionary mutableCopy];
    if (activeMappingsName) {
        [mutableMappings removeObjectForKey:activeMappingsName];
    }
    return mutableMappings;
}

- (NSString*) activeExtensionNameForSelectedSegmentIndex {
    NSArray *infoArray = [[self segmentedControlInfo] objectAtIndex:self.segmentedControl.selectedSegmentIndex];
    return [infoArray lastObject];
}

- (void)didChangeValueForSegmentedControl:(UISegmentedControl *)sender
{
    // Mappings have changed
    [self.tableView reloadData];
}

- (BRCDataObject *)dataObjectForIndexPath:(NSIndexPath *)indexPath tableView:(UITableView *)tableView
{
    __block BRCDataObject *dataObject = nil;
    if ([self isSearchResultsControllerTableView:tableView] && [self.searchResults count] > indexPath.row) {
        dataObject = self.searchResults[indexPath.row];
    }
    else {
        [self.databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            YapDatabaseViewTransaction *viewTransaction = [transaction extension:[self activeExtensionNameForSelectedSegmentIndex]];
            dataObject = [viewTransaction objectAtIndexPath:indexPath withMappings:self.activeMappings];
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
    cell.dataObject = dataObject;
    [cell updateDistanceLabelFromLocation:self.locationManager.location toLocation:dataObject.location];
    // Adding gestures per state basis.
    UIImageView *viewState = [self imageViewForFavoriteStatus:dataObject.isFavorite];
    UIColor *color = [UIColor brc_navBarColor];
    [cell setSwipeGestureWithView:viewState color:color mode:MCSwipeTableViewCellModeSwitch state:MCSwipeTableViewCellState1 completionBlock:^(MCSwipeTableViewCell *swipeCell, MCSwipeTableViewCellState state, MCSwipeTableViewCellMode mode) {
        BRCDataObjectTableViewCell *dataCell = (BRCDataObjectTableViewCell*)swipeCell;
        [self.databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            dataObject = [[transaction objectForKey:dataObject.uniqueID inCollection:[[dataObject class] collection]] copy];
        }];
        dataObject.isFavorite = !dataObject.isFavorite;
        dataCell.dataObject = dataObject;
        [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            [transaction setObject:dataObject forKey:dataObject.uniqueID inCollection:[[dataObject class] collection]];
        } completionBlock:nil];
    }];
    cell.delegate = self;
    return cell;
}

- (void)swipeTableViewCell:(BRCDataObjectTableViewCell *)cell didSwipeWithPercentage:(CGFloat)percentage {
    // We want to switch states to give a hint of the future value
    // is there a way to optimize this further?
    if (percentage >= cell.firstTrigger) {
        BOOL inverseFavorite = !cell.dataObject.isFavorite;
        cell.view1 = [self imageViewForFavoriteStatus:inverseFavorite];
        [cell setTitleLabelBold:inverseFavorite];
    } else if (percentage < cell.firstTrigger) {
        BOOL isFavorite = cell.dataObject.isFavorite;
        cell.view1 = [self imageViewForFavoriteStatus:isFavorite];
        [cell setTitleLabelBold:isFavorite];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
    if ([self isSearchResultsControllerTableView:sender]) {
        return 1;
    }
    return [self.activeMappings numberOfSections];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [[self cellClass] cellHeight];
}

- (CGFloat) tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [[self cellClass] cellHeight];
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
    if ([self isSearchResultsControllerTableView:sender]) {
        return [self.searchResults count];
    }
    return [self.activeMappings numberOfItemsInSection:section];
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

- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar;                    // called when cancel button pressed
{
    // ugly hack to re-hide the 1px navBarHairlineImageView after search bar disappears
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.navBarHairlineImageView = [self findHairlineImageViewUnder:self.navigationController.navigationBar];
        self.navBarHairlineImageView.hidden = YES;
    });
}

#pragma - mark  UISearchDisplayDelegate Methods

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    if ([searchString length]) {
        searchString = [NSString stringWithFormat:@"%@*",searchString];
        [self.databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            NSMutableArray *tempSearchResults = [NSMutableArray array];
            [[transaction ext:self.ftsExtensionName] enumerateKeysAndObjectsMatching:searchString usingBlock:^(NSString *collection, NSString *key, id object, BOOL *stop) {
                if (object) {
                    [tempSearchResults addObject:object];
                }
            }];
            self.searchResults = [tempSearchResults copy];
        }];
    }
    else {
        self.searchResults = nil;
    }
    return YES;
}

#pragma - mark YapDatabseModified

- (void)yapDatabaseModified:(NSNotification *)notification
{
    // Jump to the most recent commit.
    // End & Re-Begin the long-lived transaction atomically.
    // Also grab all the notifications for all the commits that I jump.
    // If the UI is a bit backed up, I may jump multiple commits.
    
    NSArray *notifications = [self.databaseConnection beginLongLivedReadTransaction];
    
    // Process the notification(s),
    // and get the change-set(s) as applies to my view and mappings configuration.
    
    NSArray *sectionChanges = nil;
    NSArray *rowChanges = nil;
    
    [self updateAllMappingsFromLocation:self.locationManager.location];
    return;
    
    YapDatabaseViewMappings *activeMappings = self.activeMappings;
    if (activeMappings) {
        NSString *activeExtensionName = [self activeExtensionNameForSelectedSegmentIndex];
        YapDatabaseViewConnection *viewConnection = [self.databaseConnection ext:activeExtensionName];
        
        // sometimes this takes a long time if there are a LOT of changes and will block
        // the main thread
        [viewConnection getSectionChanges:&sectionChanges
                               rowChanges:&rowChanges
                         forNotifications:notifications
                             withMappings:activeMappings];
        NSDictionary *inactiveMappings = [self inactiveMappingsDictionary];
        [self.databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            [inactiveMappings enumerateKeysAndObjectsUsingBlock:^(id key, YapDatabaseViewMappings *inactiveMappings, BOOL *stop) {
                [inactiveMappings updateWithTransaction:transaction];
            }];
        }];
    } else {
        [self updateAllMappingsFromLocation:self.locationManager.location];
    }

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
