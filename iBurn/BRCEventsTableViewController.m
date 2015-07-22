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

static const CGFloat kDayPickerHeight = 65.0f;

@interface BRCEventsTableViewController () <BRCEventsFilterTableViewControllerDelegate, UIPopoverPresentationControllerDelegate>
@property (nonatomic, strong, readonly) NSDate *selectedDay;
@property (nonatomic, strong) NSArray *dayPickerRowTitles;
@property (nonatomic, strong) NSArray *festivalDates;
@property (nonatomic, strong) UISegmentedControl *dayPickerSegmentedControl;

@property (nonatomic) BOOL isRefreshingEventTimeSort;
@property (nonatomic, strong) ASDayPicker *dayPicker;
@property (nonatomic, strong) NSLayoutConstraint *dayPickerHeight;
@property (nonatomic, strong) NSLayoutConstraint *tableViewHeaderHeight;
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
    
    [self layoutTableHeaderViewWithWidth:self.view.bounds.size.width];
}

// http://stackoverflow.com/questions/27512738/uisearchbar-subview-of-uitableviewheader
- (void) layoutTableHeaderViewWithWidth:(CGFloat)width {
    NSParameterAssert(self.tableView != nil);
    // Configure header view
    UIView *tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 0)];
    tableHeaderView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Create container view for search bar
    UIView *searchBarContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 44)];
    searchBarContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    NSParameterAssert(self.searchController.searchBar != nil);
    self.searchController.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [searchBarContainerView addSubview:self.searchController.searchBar];
    [self.searchController.searchBar sizeToFit];
    
    [self setupDayPicker];
    [tableHeaderView addSubview:self.dayPicker];
    [tableHeaderView addSubview:searchBarContainerView];
    
    // setup table header view constraints
    [searchBarContainerView autoSetDimension:ALDimensionHeight toSize:44.0];
    [searchBarContainerView autoSetDimension:ALDimensionWidth toSize:width];
    [searchBarContainerView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:tableHeaderView];
    _dayPickerHeight = [self.dayPicker autoSetDimension:ALDimensionHeight toSize:kDayPickerHeight];
    [self.dayPicker autoSetDimension:ALDimensionWidth toSize:width];
    [self.dayPicker autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:tableHeaderView withOffset:8];
    [self.dayPicker autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:searchBarContainerView];
    
    NSLayoutConstraint *headerWidthConstraint = [NSLayoutConstraint
                                                 constraintWithItem:tableHeaderView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual
                                                 toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:width
                                                 ];
    [tableHeaderView addConstraint:headerWidthConstraint];
    CGFloat height = [tableHeaderView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    [tableHeaderView removeConstraint:headerWidthConstraint];
    
    tableHeaderView.frame = CGRectMake(0, 0, width, height);
    [tableHeaderView autoSetDimension:ALDimensionWidth toSize:width];
    self.tableViewHeaderHeight = [tableHeaderView autoSetDimension:ALDimensionHeight toSize:height];
    //tableHeaderView.translatesAutoresizingMaskIntoConstraints = YES;
    
    // Then add header to table view
    self.tableView.tableHeaderView = tableHeaderView;
}

- (void) updateViewConstraints {
    if (!self.hasAddedConstraints) {
        NSParameterAssert(self.tableView != nil);
        NSParameterAssert(self.dayPicker != nil);
        
        [self.tableView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
        self.hasAddedConstraints = YES;
    }
    [super updateViewConstraints];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self layoutTableHeaderViewWithWidth:self.view.bounds.size.width];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self layoutTableHeaderViewWithWidth:self.view.bounds.size.width];
}

- (void) setupDayPicker {
    self.dayPicker = [[ASDayPicker alloc] initForAutoLayout];
    self.dayPicker.daysScrollView.scrollEnabled = NO;
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

#pragma mark UISearchControllerDelegate

- (void)willPresentSearchController:(UISearchController *)searchController {
    self.dayPicker.userInteractionEnabled = NO;
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.5 animations:^{
        self.dayPicker.alpha = 0.0;
        [self.dayPicker removeConstraint:self.dayPickerHeight];
        self.tableViewHeaderHeight.constant = self.tableViewHeaderHeight.constant - kDayPickerHeight;
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
    }];
}

- (void)willDismissSearchController:(UISearchController *)searchController {
    self.dayPicker.userInteractionEnabled = YES;
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.5 animations:^{
        self.dayPicker.alpha = 1.0;
        //self.dayPickerHeight.constant = kDayPickerHeight;
        //self.tableViewHeaderHeight.constant = self.tableViewHeaderHeight.constant + kDayPickerHeight;
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        [self layoutTableHeaderViewWithWidth:self.view.bounds.size.width];
    }];
}

- (void) didDismissSearchController:(UISearchController *)searchController {
    
}


@end
