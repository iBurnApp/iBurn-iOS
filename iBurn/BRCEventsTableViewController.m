//
//  BRCEventsTableViewController.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCEventsTableViewController.h"
#import "BRCDatabaseManager.h"
#import "BRCEventObjectTableViewCell.h"
#import "YapDatabaseViewMappings.h"
#import "BRCDataObject.h"
#import "BRCFilteredTableViewController_Private.h"
#import "BRCEventObject.h"
#import "NSDate+iBurn.h"
#import "NSDateFormatter+iBurn.h"
#import "BRCEventsFilterTableViewController.h"
#import "NSUserDefaults+iBurn.h"
#import "ASDayPicker.h"
#import "FBKVOController.h"
#import "PureLayout.h"

@interface BRCEventsTableViewController () <BRCEventsFilterTableViewControllerDelegate, UIPopoverPresentationControllerDelegate>
@property (nonatomic, strong, readonly) NSDate *selectedDay;
@property (nonatomic, strong) NSArray *dayPickerRowTitles;
@property (nonatomic, strong) NSArray *festivalDates;
@property (nonatomic, strong) UISegmentedControl *dayPickerSegmentedControl;

@property (nonatomic) BOOL isRefreshingEventTimeSort;
@property (nonatomic, strong, readonly) ASDayPicker *dayPicker;
@property (nonatomic, strong) UIView *tableHeaderView;
@end

@implementation BRCEventsTableViewController
@synthesize selectedDay = _selectedDay;

- (void) filterButtonPressed:(id)sender {
    BRCEventsFilterTableViewController *filterViewController = [[BRCEventsFilterTableViewController alloc] initWithDelegate:self];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:filterViewController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (NSInteger) indexForDay:(NSDate*)date {
    NSInteger dayCount = [NSDate brc_daysBetweenDate:[self.festivalDates firstObject] andDate:date];
    NSParameterAssert(dayCount >= 0);
    return dayCount;
}

- (NSDate*) dateForIndex:(NSInteger)index {
    NSParameterAssert(index < self.festivalDates.count);
    return [self.festivalDates objectAtIndex:index];
}

- (void) viewDidLoad {
    [super viewDidLoad];
    UIBarButtonItem *filterButton = [[UIBarButtonItem alloc] initWithTitle:@"Filter" style:UIBarButtonItemStylePlain target:self action:@selector(filterButtonPressed:)];
    
    UIBarButtonItem *loadingButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.loadingIndicatorView];
    self.navigationItem.rightBarButtonItems = @[filterButton, loadingButtonItem];
    self.selectedDay = [NSDate date];

    self.searchController.hidesNavigationBarDuringPresentation = YES;
    [self setupDayPicker];
    [self setupTableHeaderView];
}

- (void) setupTableHeaderView {
    NSParameterAssert(self.searchController != nil);
    NSParameterAssert(self.dayPicker != nil);
    self.tableHeaderView = [[UIView alloc] initForAutoLayout];
    self.tableView.tableHeaderView = self.tableHeaderView;
    [self.tableHeaderView autoMatchDimension:ALDimensionWidth toDimension:ALDimensionWidth ofView:self.view];
    [self.tableHeaderView autoSetDimension:ALDimensionHeight toSize:100];
    [self.searchController.searchBar removeFromSuperview];
    [self.tableHeaderView addSubview:self.searchController.searchBar];
    [self.tableHeaderView addSubview:self.dayPicker];
    [self.searchController.searchBar autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero excludingEdge:ALEdgeTop];
    [self.dayPicker autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsMake(8, 0, 0, 0) excludingEdge:ALEdgeBottom];
    [self.searchController.searchBar autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.dayPicker];
    [self.dayPicker autoSetDimension:ALDimensionHeight toSize:64];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void) setupDayPicker {
    _dayPicker = [[ASDayPicker alloc] initForAutoLayout];
    [self.dayPicker setStartDate:[BRCEventObject festivalStartDate] endDate:[BRCEventObject festivalEndDate]];
    [self.dayPicker setWeekdayTitles:[ASDayPicker weekdayTitlesWithLocaleIdentifier:nil length:3 uppercase:YES]];
    self.dayPicker.selectedDate = self.selectedDay;
    [self.dayPicker setSelectedDateBackgroundImage:[UIImage imageNamed:@"BRCDateSelection"]];
    [self.KVOController observe:self.dayPicker keyPath:NSStringFromSelector(@selector(selectedDate)) options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew block:^(id observer, ASDayPicker *dayPicker, NSDictionary *change) {
        NSDate *newDate = dayPicker.selectedDate;
        self.selectedDay = newDate;
    }];
}

- (NSDate*) selectedDayInFestivalRange:(NSDate*)dayCandidate {
    NSDate *validDate = [dayCandidate brc_dateWithinStartDate:[BRCEventObject festivalStartDate] endDate:[BRCEventObject festivalEndDate]];
    return validDate;
}

- (void) setSelectedDay:(NSDate *)selectedDay {
    if (!selectedDay) {
        selectedDay = [NSDate date];
    }
    NSDate *selectedDayInFestivalRange = [self selectedDayInFestivalRange:selectedDay];
    _selectedDay = selectedDayInFestivalRange;
    NSString *dayString = [[NSDateFormatter brc_dayOfWeekDateFormatter] stringFromDate:_selectedDay];
    self.navigationItem.leftBarButtonItem.title = dayString;
    [self updateFilteredViews];
    [self replaceTimeBasedEventMappings];
    [self updateMappingsWithCompletionBlock:^{
        [self.tableView reloadData];
    }];
}

- (NSDate*) selectedDay {
    if (!_selectedDay) {
        NSDate *selectedDayInFestivalRange = [self selectedDayInFestivalRange:[NSDate date]];
        _selectedDay = selectedDayInFestivalRange;
    }
    return _selectedDay;
}

- (void)updateFilteredViews
{
    self.isUpdatingFilters = YES;
    [[BRCDatabaseManager sharedInstance] refreshEventFilteredViewsWithSelectedDay:self.selectedDay completionBlock:^{
        self.isUpdatingFilters = NO;
        [self.tableView reloadData];
    }];
}

- (void) setupMappings {
    // we need to override search mappings for events
    self.searchMappings = [[YapDatabaseViewMappings alloc] initWithGroupFilterBlock:^BOOL(NSString *group, YapDatabaseReadTransaction *transaction) {
        return YES;
    } sortBlock:^NSComparisonResult(NSString *group1, NSString *group2, YapDatabaseReadTransaction *transaction) {
        return [group1 compare:group2];
    } view:self.searchViewName];
    [self replaceTimeBasedEventMappings];
}

- (void) replaceTimeBasedEventMappings {
    NSString *group = [[NSDateFormatter brc_eventGroupDateFormatter] stringFromDate:self.selectedDay];
    NSArray *activeTimeGroup = @[group]; // selected day group
    self.mappings = [[YapDatabaseViewMappings alloc] initWithGroups:activeTimeGroup view:self.viewName];
}

- (void) refreshEventTimeSort {
    if (self.isRefreshingEventTimeSort) {
        return;
    }
    self.isRefreshingEventTimeSort = YES;
    [[BRCDatabaseManager sharedInstance] refreshEventsSortingWithCompletionBlock:^{
        [self updateMappingsWithCompletionBlock:^{
            [self.tableView reloadData];
            self.isRefreshingEventTimeSort = NO;
        }];
    }];
}

#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCEventObjectTableViewCell *cell = (BRCEventObjectTableViewCell*)[super tableView:tableView cellForRowAtIndexPath:indexPath];
    cell.locationLabel.hidden = NO;
    return cell;
}

 #pragma - mark BRCEventsFilterTableViewControllerDelegate Methods

- (void)didSetNewFilterSettingsInFilterTableViewController:(BRCEventsFilterTableViewController *)viewController
{
    [self updateFilteredViews];
}

- (void)didSetNewSortSettingsInFilterTableViewController:(BRCEventsFilterTableViewController *)viewController
{
    [self refreshEventTimeSort];
}

#pragma mark UIAdaptivePresentationControllerDelegate

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    // This makes our date picker appear in a popover
    return UIModalPresentationNone;
}

@end
