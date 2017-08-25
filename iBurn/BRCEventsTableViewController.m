//
//  BRCEventsTableViewController.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "ASDayPicker.h"
#import "BRCDatabaseManager.h"
#import "BRCDataObject.h"
#import "BRCEventObject.h"
#import "BRCEventObjectTableViewCell.h"
#import "BRCEventsFilterTableViewController.h"
#import "BRCEventsTableViewController.h"
#import "BRCFilteredTableViewController_Private.h"
#import "NSDate+iBurn.h"
#import "NSDateFormatter+iBurn.h"
#import "NSUserDefaults+iBurn.h"
#import "PureLayout.h"
#import <KVOController/NSObject+FBKVOController.h>
@import YapDatabase;

// layout metrics
static const CGFloat kDayPickerHeight = 65.0f;

@interface BRCEventsTableViewController () <BRCEventsFilterTableViewControllerDelegate, UIPopoverPresentationControllerDelegate>

// data
@property (nonatomic, strong, readonly) NSDate *selectedDay;
@property (nonatomic, strong) NSArray *festivalDates;
@property (nonatomic) BOOL isRefreshingEventTimeSort;
    
// UI
@property (nonatomic, strong) ASDayPicker *dayPicker;
@property (nonatomic, strong) NSLayoutConstraint *dayPickerHeight;

@end

@implementation BRCEventsTableViewController
	
@synthesize selectedDay = _selectedDay;
	
#pragma mark - lifecycle
	
- (void) viewDidLoad {
    [super viewDidLoad];
    
    [self setAutomaticallyAdjustsScrollViewInsets:NO];
    
    // setup navbar
    UIBarButtonItem *filterButton = [[UIBarButtonItem alloc] initWithTitle:@"Filter" style:UIBarButtonItemStylePlain target:self action:@selector(filterButtonPressed:)];
	UIBarButtonItem *loadingButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.loadingIndicatorView];
	self.navigationItem.rightBarButtonItems = @[filterButton, loadingButtonItem];
    
    // setup subviews
    [self setupSubviews];
    [self setupConstraints];
    
    // setup search
    self.searchController.searchBar.backgroundColor = [UIColor whiteColor];
    
    // setup data
    self.selectedDay = [NSDate date];
}
    
#pragma mark - subviews
    
- (void) setupSubviews {
    // date picker
    self.dayPicker = [[ASDayPicker alloc] initWithFrame:CGRectZero];
    [self.dayPicker.daysScrollView setScrollEnabled:NO];
    [self.dayPicker setStartDate:[BRCEventObject festivalStartDate] endDate:[BRCEventObject festivalEndDate]];
    [self.dayPicker setWeekdayTitles:[ASDayPicker weekdayTitlesWithLocaleIdentifier:nil length:3 uppercase:YES]];
    [self.dayPicker setSelectedDate:self.selectedDay];
    [self.dayPicker setSelectedDateBackgroundImage:[UIImage imageNamed:@"BRCDateSelection"]];
    [self.KVOController observe:self.dayPicker keyPath:NSStringFromSelector(@selector(selectedDate)) options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew block:^(id observer, ASDayPicker *dayPicker, NSDictionary *change) {
        self.selectedDay = dayPicker.selectedDate;
    }];
    [self.view addSubview:self.dayPicker];
}
    
- (void) setupConstraints {
    // date picker
    self.dayPicker.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dayPicker.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:64].active = YES;
    [self.dayPicker.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.dayPicker.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
    self.dayPickerHeight = [self.dayPicker.heightAnchor constraintEqualToConstant:kDayPickerHeight];
    self.dayPickerHeight.active = YES;
    
    // table
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView.topAnchor constraintEqualToAnchor:self.dayPicker.bottomAnchor].active = YES;
    [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
    [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
    
    // ** hack: tell our superclass not to override these
    self.hasAddedConstraints = YES;
}

#pragma mark - Data
	
- (NSInteger) indexForDay:(NSDate*)date {
	NSInteger dayCount = [NSDate brc_daysBetweenDate:[self.festivalDates firstObject] andDate:date];
	NSParameterAssert(dayCount >= 0);
	return dayCount;
}
	
- (NSDate*) dateForIndex:(NSInteger)index {
	NSParameterAssert(index < self.festivalDates.count);
	return [self.festivalDates objectAtIndex:index];
}
    
- (NSDate*) selectedDayInFestivalRange:(NSDate*)dayCandidate {
    return [dayCandidate brc_dateWithinStartDate:[BRCEventObject festivalStartDate] endDate:[BRCEventObject festivalEndDate]];
}
    
- (void) setSelectedDay:(NSDate *)selectedDay {
    if (!selectedDay) {
        selectedDay = [NSDate date];
    }
    
    _selectedDay = [self selectedDayInFestivalRange:selectedDay];
    self.navigationItem.leftBarButtonItem.title = [[NSDateFormatter brc_dayOfWeekDateFormatter] stringFromDate:_selectedDay];
    [self updateFilteredViews];
    [self replaceTimeBasedEventMappings];
    [self updateMappingsWithCompletionBlock:^{
        [self.tableView reloadData];
    }];
}
    
- (NSDate*) selectedDay {
    if (!_selectedDay) {
        _selectedDay = [self selectedDayInFestivalRange:[NSDate date]];
    }
    
    return _selectedDay;
}
    
- (void)updateFilteredViews {
    self.isUpdatingFilters = YES;
    
    [BRCDatabaseManager.shared refreshEventFilteredViewsWithSelectedDay:self.selectedDay completionBlock:^{
        self.isUpdatingFilters = NO;
        [self.tableView reloadData];
    }];
}
    
- (void) setupMappings {
    // we need to override search mappings for events
    [self replaceTimeBasedEventMappings];
}
    
- (void) replaceTimeBasedEventMappings {
    NSString *selectedDay = [[NSDateFormatter brc_eventGroupDateFormatter] stringFromDate:self.selectedDay];
    self.mappings = [[YapDatabaseViewMappings alloc] initWithGroupFilterBlock:^BOOL(NSString *group, YapDatabaseReadTransaction *transaction) {
        if (group && selectedDay) {
            return [group containsString:selectedDay];
        } else {
            return NO;
        }
    } sortBlock:^NSComparisonResult(NSString *group1, NSString *group2, YapDatabaseReadTransaction *transaction) {
        return [group1 compare:group2];
    } view:self.viewName];
    
    BOOL searchSelectedDayOnly = [NSUserDefaults standardUserDefaults].searchSelectedDayOnly;
    self.searchMappings = [[YapDatabaseViewMappings alloc] initWithGroupFilterBlock:^BOOL(NSString *group, YapDatabaseReadTransaction *transaction) {
        if (searchSelectedDayOnly) {
            if (group && selectedDay) {
                return [group containsString:selectedDay];
            } else {
                return NO;
            }
        } else {
            return YES;
        }
    } sortBlock:^NSComparisonResult(NSString *group1, NSString *group2, YapDatabaseReadTransaction *transaction) {
        return [group1 compare:group2];
    } view:self.searchViewName];
}
    
- (void) refreshEventTimeSort {
    if (self.isRefreshingEventTimeSort) {
        return;
    }
    
    self.isRefreshingEventTimeSort = YES;
    [BRCDatabaseManager.shared refreshEventsSortingWithCompletionBlock:^{
        [self updateMappingsWithCompletionBlock:^{
            [self.tableView reloadData];
            self.isRefreshingEventTimeSort = NO;
        }];
    }];
}

#pragma mark - Input

- (void) filterButtonPressed:(id)sender {
    BRCEventsFilterTableViewController *filterViewController = [[BRCEventsFilterTableViewController alloc] initWithDelegate:self];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:filterViewController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    if (![self isSearchResultsControllerTableView:tableView]) {
        NSArray *rawGroups = [self.mappings allGroups];
        NSMutableArray *groups = [NSMutableArray arrayWithCapacity:rawGroups.count];
        [rawGroups enumerateObjectsUsingBlock:^(NSString *groupName, NSUInteger idx, BOOL *stop) {
            NSString *hour = [[groupName componentsSeparatedByString:@" "] lastObject];
            NSInteger hourNumber = hour.integerValue;
            hourNumber = hourNumber % 12;
            if (hourNumber == 0) {
                hourNumber = 12;
            }
            hour = [NSString stringWithFormat:@"%d", (int)hourNumber];
            [groups addObject:hour];
        }];
        
        [groups insertObject:UITableViewIndexSearch atIndex:0];
        return groups;
    }
    
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    if (![self isSearchResultsControllerTableView:tableView]) {
        // https://github.com/kharrison/CodeExamples/blob/master/WorldFacts/WorldFacts/UYLCountryTableViewController.m
        if (index > 0) {
            // The index is offset by one to allow for the extra search icon inserted at the front
            // of the index
            return index - 1;
        } else {
            // if magnifying glass http://stackoverflow.com/questions/19093168/uitableview-section-index-not-able-to-scroll-to-search-bar-index
            // The first entry in the index is for the search icon so we return section not found
            // and force the table to scroll to the top.
            
            [tableView setContentOffset:CGPointMake(0.0, -tableView.contentInset.top)];
            return NSNotFound;
        }
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    if ([cell isKindOfClass:[BRCEventObjectTableViewCell class]]) {
        BRCEventObjectTableViewCell *eventCell = (BRCEventObjectTableViewCell*)cell;
        eventCell.locationLabel.hidden = NO;
    }
    
    return cell;
}

 #pragma - mark BRCEventsFilterTableViewControllerDelegate

- (void)didSetNewFilterSettingsInFilterTableViewController:(BRCEventsFilterTableViewController *)viewController {
    [self updateFilteredViews];
}

- (void)didSetNewSortSettingsInFilterTableViewController:(BRCEventsFilterTableViewController *)viewController {
    [self refreshEventTimeSort];
}

#pragma mark - UIAdaptivePresentationControllerDelegate

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    // This makes our date picker appear in a popover
    return UIModalPresentationNone;
}

@end
