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
#import "BRCStringPickerViewController.h"
#import "NSUserDefaults+iBurn.h"

@interface BRCEventsTableViewController () <BRCEventsFilterTableViewControllerDelegate, UIPopoverPresentationControllerDelegate>
@property (nonatomic, strong, readonly) NSDate *selectedDay;
@property (nonatomic, strong) NSArray *dayPickerRowTitles;
@property (nonatomic, strong) NSArray *festivalDates;
@property (nonatomic, strong) UISegmentedControl *dayPickerSegmentedControl;

@property (nonatomic) BOOL isRefreshingEventTimeSort;
@property (nonatomic, strong) BRCStringPickerViewController *dayPicker;
@end

@implementation BRCEventsTableViewController
@synthesize selectedDay = _selectedDay;

- (void) dayButtonPressed:(id)sender {
    NSInteger currentSelection = [self indexForDay:self.selectedDay];
    self.dayPicker.selectedIndex = currentSelection;

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:self.dayPicker];
    nav.modalPresentationStyle = UIModalPresentationPopover;
    nav.navigationBarHidden = YES;

    self.dayPicker.preferredContentSize = CGSizeMake(280, 200);
    
    UIPopoverPresentationController *popover = nav.popoverPresentationController;
    popover.delegate = self;
    popover.barButtonItem = sender;
    [self presentViewController:nav animated:YES completion:nil];
}

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
    UIBarButtonItem *dayButton = [[UIBarButtonItem alloc] initWithTitle:@"Day" style:UIBarButtonItemStylePlain target:self action:@selector(dayButtonPressed:)];
    self.navigationItem.leftBarButtonItem = dayButton;
    UIBarButtonItem *filterButton = [[UIBarButtonItem alloc] initWithTitle:@"Filter" style:UIBarButtonItemStylePlain target:self action:@selector(filterButtonPressed:)];
    
    UIBarButtonItem *loadingButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.loadingIndicatorView];
    self.navigationItem.rightBarButtonItems = @[filterButton, loadingButtonItem];
    self.selectedDay = [NSDate date];

    self.searchController.hidesNavigationBarDuringPresentation = YES;
    [self setupDayPicker];
}

- (void) setupDayPicker {
    self.festivalDates = [BRCEventObject datesOfFestival];
    
    NSArray *majorEvents = [BRCEventObject majorEvents];
    
    NSParameterAssert(self.festivalDates.count == majorEvents.count);
    NSMutableArray *rowTitles = [NSMutableArray arrayWithCapacity:self.festivalDates.count];
    [self.festivalDates enumerateObjectsUsingBlock:^(NSDate *date, NSUInteger idx, BOOL *stop) {
        NSString *dayOfWeekString = [[NSDateFormatter brc_dayOfWeekDateFormatter] stringFromDate:date];
        NSString *shortDateString = [[NSDateFormatter brc_shortDateFormatter] stringFromDate:date];
        NSString *majorEvent = [majorEvents objectAtIndex:idx];
        NSMutableString *pickerString = [NSMutableString stringWithFormat:@"%@ %@", dayOfWeekString, shortDateString];
        if (majorEvent.length) {
            [pickerString appendFormat:@" - %@", majorEvent];
        }
        [rowTitles addObject:pickerString];
    }];
    self.dayPickerRowTitles = rowTitles;
    NSInteger currentSelection = [self indexForDay:self.selectedDay];
    self.dayPicker = [[BRCStringPickerViewController alloc] initWithPickerStrings:self.dayPickerRowTitles initialSelection:currentSelection doneBlock:^(BRCStringPickerViewController *picker, NSUInteger selectedIndex, NSString *selectedValue) {
        NSDate *selectedDate = [self dateForIndex:selectedIndex];
        self.selectedDay = selectedDate;
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
