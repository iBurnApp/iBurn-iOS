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
#import "BRCLocationManager.h"
#import "BRCFilteredTableViewController.h"
#import "BRCFilteredTableViewController_Private.h"

@interface BRCFilteredTableViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, strong) UISearchDisplayController *searchController;
@property (nonatomic) BOOL observerIsRegistered;
@property (nonatomic, strong) CLLocation *lastDistanceUpdateLocation;
@property (nonatomic) BOOL updatingDistanceInformation;
@end

@implementation BRCFilteredTableViewController

- (instancetype)init
{
    if (self = [super init]) {
        self.segmentedControl = [[UISegmentedControl alloc] init];
        self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
        self.segmentedControl.selectedSegmentIndex = 0;
        
        [self.segmentedControl addTarget:self action:@selector(didChangeValueForSegmentedControl:) forControlEvents:UIControlEventValueChanged];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupDatabaseConnection];
    [self setupMappingsDictionary];
    [self updateAllMappings];
    
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
    
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    searchBar.delegate = self;
    
    self.searchController = [[UISearchDisplayController alloc] initWithSearchBar:searchBar contentsController:self];
    self.searchController.delegate = self;
    self.searchController.searchResultsDataSource = self;
    self.searchController.searchResultsDelegate = self;
    
    self.tableView.tableHeaderView = searchBar;
    
    [self.view addSubview:self.segmentedControl];
    [self.view addSubview:self.tableView];
    
    [self setupConstraints];
    
    UINib *nib = [UINib nibWithNibName:NSStringFromClass([self cellClass]) bundle:nil];
    [[self tableView] registerNib:nib forCellReuseIdentifier:[[self cellClass] cellIdentifier]];
    [self.searchController.searchResultsTableView registerNib:nib forCellReuseIdentifier:[[self cellClass] cellIdentifier]];
    
    
}

- (void)setupDatabaseConnection
{
    self.databaseConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
    [self.databaseConnection beginLongLivedReadTransaction];
    
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(yapDatabaseModified:)
                                                 name:YapDatabaseModifiedNotification
                                               object:self.databaseConnection.database];
}

// Override this in subclasses
- (void) setupMappingsDictionary {
    NSMutableArray *viewNames = [NSMutableArray arrayWithCapacity:3];
    [viewNames addObject:[BRCDatabaseManager extensionNameForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeName]];
    [viewNames addObject:[BRCDatabaseManager extensionNameForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeDistance]];
    [viewNames addObject:[BRCDatabaseManager filteredExtensionNameForFilterType:BRCDatabaseFilteredViewTypeFavorites parentName:[BRCDatabaseManager extensionNameForClass:[self viewClass] extensionType:BRCDatabaseViewExtensionTypeTime]]];
    
    NSMutableDictionary *mutableMappingsDictionary = [NSMutableDictionary dictionaryWithCapacity:viewNames.count];
    
    [viewNames enumerateObjectsUsingBlock:^(NSString *viewName, NSUInteger idx, BOOL *stop) {
        YapDatabaseViewMappings *mappings = [[YapDatabaseViewMappings alloc] initWithGroups:@[[self.viewClass collection]] view:viewName];
        [mutableMappingsDictionary setObject:mappings forKey:viewName];
    }];
    self.mappingsDictionary = mutableMappingsDictionary;
}

- (void) updateAllMappings {
    [self.databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [self.mappingsDictionary enumerateKeysAndObjectsUsingBlock:^(id key, YapDatabaseViewMappings *mappings, BOOL *stop) {
            [mappings updateWithTransaction:transaction];
        }];
    }];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshDistanceInformation];
}

- (void) refreshDistanceInformation {
    if ([self shouldRefreshDistanceInformation]) {
        [self registerRecentLocationObserver];
    }
}

- (BOOL) shouldRefreshDistanceInformation {
    if (!self.lastDistanceUpdateLocation) {
        return YES;
    }
    CLLocation *recentLocation = [BRCLocationManager sharedInstance].recentLocation;
    if (!recentLocation) {
        return YES;
    }
    NSDate *now = [NSDate date];
    NSDate *mostRecentLocationDate = self.lastDistanceUpdateLocation.timestamp;
    
    NSTimeInterval timeIntervalSinceLastDistanceUpdate = [now timeIntervalSinceDate:mostRecentLocationDate];
    CLLocationDistance distanceSinceLastDistanceUpdate = [ self.lastDistanceUpdateLocation distanceFromLocation:recentLocation];
    
    NSTimeInterval minimumLocationUpdateTimeInterval = 5 * 60; // 5 minutes
    CLLocationDistance minimumLocationUpdateDistance = 25; // 25 meters
    
    if (timeIntervalSinceLastDistanceUpdate > minimumLocationUpdateTimeInterval || distanceSinceLastDistanceUpdate > minimumLocationUpdateDistance) {
        return YES;
    }
    return NO;
}

- (void) registerRecentLocationObserver {
    if (self.observerIsRegistered) {
        return;
    }
    [[BRCLocationManager sharedInstance] addObserver:self forKeyPath:NSStringFromSelector(@selector(recentLocation)) options:NSKeyValueObservingOptionNew context:NULL];
    [[BRCLocationManager sharedInstance] updateRecentLocation];
    self.observerIsRegistered = YES;
}

- (void) unregisterRecentLocationObserver {
    if (!self.observerIsRegistered) {
        return;
    }
    [[BRCLocationManager sharedInstance] removeObserver:self forKeyPath:NSStringFromSelector(@selector(recentLocation)) context:NULL];
    self.observerIsRegistered = NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([object isKindOfClass:[BRCLocationManager class]]) {
        if ([keyPath isEqualToString:NSStringFromSelector(@selector(recentLocation))]) {
            CLLocation *recentLocation = [BRCLocationManager sharedInstance].recentLocation;
            if (!recentLocation) {
                return;
            }
            [self unregisterRecentLocationObserver];
            if ([self shouldRefreshDistanceInformation] && !self.updatingDistanceInformation) {
                self.updatingDistanceInformation = YES;
                Class objectClass = self.viewClass;
                [[BRCLocationManager sharedInstance] updateDistanceForAllObjectsOfClass:objectClass fromLocation:recentLocation completionBlock:^{
                    NSLog(@"Distances updated for %@", NSStringFromClass(objectClass));
                    self.lastDistanceUpdateLocation = recentLocation;
                    self.updatingDistanceInformation = NO;
                }];
            }
        }
    }
}

- (Class) cellClass {
    return [BRCDataObjectTableViewCell class];
}

- (NSArray *) segmentedControlInfo {
    return @[@[@"Distance", [BRCDatabaseManager extensionNameForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeDistance]],
             @[@"Name", [BRCDatabaseManager extensionNameForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeName]],
             @[@"Favorites", [BRCDatabaseManager filteredExtensionNameForFilterType:BRCDatabaseFilteredViewTypeFavorites parentName:[BRCDatabaseManager extensionNameForClass:[self viewClass] extensionType:BRCDatabaseViewExtensionTypeName]]]];
}

- (void)setupConstraints
{
    id topGuide = self.topLayoutGuide;
    id bottomGuide = self.bottomLayoutGuide;
    NSDictionary *views = NSDictionaryOfVariableBindings(_tableView,_segmentedControl,topGuide,bottomGuide);
    NSDictionary *metrics = @{@"segmentedControlHeight":@(33)};
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_segmentedControl]|" options:0 metrics:metrics views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_tableView]|" options:0 metrics:metrics views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[topGuide][_segmentedControl(==segmentedControlHeight)]-1-[_tableView][bottomGuide]" options:0 metrics:metrics views:views]];
    
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

- (NSString *) activeFullTextSearchExtensionName {
    return [BRCDatabaseManager extensionNameForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeFullTextSearch];
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

#pragma - mark UITableViewDataSource Methods

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCDataObjectTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[[self cellClass] cellIdentifier] forIndexPath:indexPath];
    BRCDataObject *dataObject = [self dataObjectForIndexPath:indexPath tableView:tableView];
    [cell setDataObject:dataObject];
    return cell;
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

#pragma - mark  UISearchDisplayDelegate Methods

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    if ([searchString length]) {
        
        searchString = [NSString stringWithFormat:@"%@*",searchString];
        
        [self.databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            NSMutableArray *tempSearchResults = [NSMutableArray array];
            
            [[transaction ext:[self activeFullTextSearchExtensionName]] enumerateKeysAndObjectsMatching:searchString usingBlock:^(NSString *collection, NSString *key, id object, BOOL *stop) {
                
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
    }

    
    NSDictionary *inactiveMappings = [self inactiveMappingsDictionary];
    [self.databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [inactiveMappings enumerateKeysAndObjectsUsingBlock:^(id key, YapDatabaseViewMappings *inactiveMappings, BOOL *stop) {
            [inactiveMappings updateWithTransaction:transaction];
        }];
    }];

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
