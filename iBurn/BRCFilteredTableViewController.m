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
#import "YapDatabase.h"
#import "BRCDatabaseManager.h"
#import "BRCDataObject.h"
#import "BRCDetailViewController.h"

static NSString *const BRCFilteredTableViewCellIdentifier = @"BRCFilteredTableViewCellIdentifier";

@interface BRCFilteredTableViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) YapDatabaseViewMappings *nameMappings;
@property (nonatomic, strong) YapDatabaseViewMappings *distanceMappings;
@property (nonatomic, strong) YapDatabaseConnection *databaseConnection;
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
    
    [[self segmentedControlTitles] enumerateObjectsUsingBlock:^(NSString *title, NSUInteger idx, BOOL *stop) {
        [self.segmentedControl insertSegmentWithTitle:title atIndex:idx animated:NO];
    }];
    self.segmentedControl.selectedSegmentIndex = 0;
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    searchBar.delegate = self;
    
    UISearchDisplayController *searchDisplayController = [[UISearchDisplayController alloc] initWithSearchBar:searchBar contentsController:self];
    searchDisplayController.delegate = self;
    searchDisplayController.searchResultsDataSource = self;
    
    self.tableView.tableHeaderView = searchBar;
    
    [self.view addSubview:self.segmentedControl];
    [self.view addSubview:self.tableView];
    
    
    [self setupConstraints];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:BRCFilteredTableViewCellIdentifier];
    
    self.databaseConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
    [self.databaseConnection beginLongLivedReadTransaction];
    
    self.nameMappings = [[YapDatabaseViewMappings alloc] initWithGroups:@[[self.viewClass collection]] view:[BRCDatabaseManager extensionNameForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeName]];
    self.distanceMappings = [[YapDatabaseViewMappings alloc] initWithGroups:@[[self.viewClass collection]] view:[BRCDatabaseManager extensionNameForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeDistance]];
    
    [self.databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction){
        // One-time initialization
        [self.nameMappings updateWithTransaction:transaction];
        [self.distanceMappings updateWithTransaction:transaction];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(yapDatabaseModified:)
                                                 name:YapDatabaseModifiedNotification
                                               object:self.databaseConnection.database];
}

- (NSArray *) segmentedControlTitles {
    return @[@"Name", @"Distance", @"Favorites"];
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
    BRCDatabaseViewExtensionType activeExtensionType = [self extensionTypeForSelectedSegmentIndex];
    if (activeExtensionType == BRCDatabaseViewExtensionTypeName) {
        return self.nameMappings;
    } else if (activeExtensionType == BRCDatabaseViewExtensionTypeDistance) {
        return self.distanceMappings;
    } else {
        return nil;
    }
}

- (BRCDatabaseViewExtensionType) extensionTypeForSelectedSegmentIndex {
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        return BRCDatabaseViewExtensionTypeName;
    } else if (self.segmentedControl.selectedSegmentIndex == 1) {
        return BRCDatabaseViewExtensionTypeDistance;
    } else { // else if favorites, etc
        return BRCDatabaseViewExtensionTypeUnknown;
    }
}

- (NSString*) activeExtensionName {
    BRCDatabaseViewExtensionType activeExtensionType = [self extensionTypeForSelectedSegmentIndex];
    return [BRCDatabaseManager extensionNameForClass:self.viewClass extensionType:activeExtensionType];
}

- (void)didChangeValueForSegmentedControl:(UISegmentedControl *)sender
{
    // Mappings have changed
    [self.tableView reloadData];
}

- (BRCDataObject *)dataObjectForIndexPath:(NSIndexPath *)indexPath
{
    __block BRCDataObject *dataObject = nil;
    [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [transaction enumerateRowsInAllCollectionsUsingBlock:^(NSString *collection, NSString *key, id object, id metadata, BOOL *stop) {
            dataObject = (BRCDataObject *)object;
            *stop = YES;
        }];
    }];
    
    return dataObject;
}

#pragma - mark UITableViewDataSource Methods

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:BRCFilteredTableViewCellIdentifier forIndexPath:indexPath];
    __block BRCDataObject *dataObject = nil;
    [self.databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        YapDatabaseViewTransaction *viewTransaction = [transaction extension:[self activeExtensionName]];
        dataObject = [viewTransaction objectAtIndexPath:indexPath withMappings:self.activeMappings];
    }];
    cell.textLabel.text = dataObject.title;
    cell.detailTextLabel.text = dataObject.detailDescription;
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
    return [self.activeMappings numberOfSections];
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
    return [self.activeMappings numberOfItemsInSection:section];
}

////// Optional //////

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.navigationController pushViewController:[[BRCDetailViewController alloc] initWithDataObject:[self dataObjectForIndexPath:indexPath]]  animated:YES];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    NSMutableArray *titles = [[[UILocalizedIndexedCollation currentCollation] sectionIndexTitles] mutableCopy];
    [titles insertObject:UITableViewIndexSearch atIndex:0];
    return titles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return [[UILocalizedIndexedCollation currentCollation] sectionForSectionIndexTitleAtIndex:index];
}

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
    
    [[self.databaseConnection ext:[self activeExtensionName]] getSectionChanges:&sectionChanges
                                                                     rowChanges:&rowChanges
                                                               forNotifications:notifications
                                                                   withMappings:self.activeMappings];
    
    // No need to update mappings.
    // The above method did it automatically.
    
    if ([sectionChanges count] == 0 & [rowChanges count] == 0)
    {
        // Nothing has changed that affects our tableView
        return;
    }
    
    // Familiar with NSFetchedResultsController?
    // Then this should look pretty familiar
    
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
