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
#import "BRCStringPickerView.h"

@interface BRCEventsTableViewController () <BRCEventsFilterTableViewControllerDelegate>
@property (nonatomic, strong) NSArray *dayPickerRowTitles;
@property (nonatomic, strong) NSArray *festivalDates;
@property (nonatomic, strong) UISegmentedControl *dayPickerSegmentedControl;

@property (nonatomic) BOOL isRefreshingEventTimeSort;
@property (nonatomic, strong) BRCStringPickerView *dayPicker;
@end

@implementation BRCEventsTableViewController
@synthesize selectedDay = _selectedDay;

- (instancetype) initWithViewClass:(Class)viewClass
                          viewName:(NSString*)viewName
                           ftsName:(NSString*)ftsName
             filteredByDayViewName:(NSString*)filteredByDayViewName
filteredByDayExpirationAndTypeViewName:(NSString*)filteredByDayExpirationAndTypeViewName
{
    _filteredByDayViewName = filteredByDayViewName;
    _filteredByDayExpirationAndTypeViewName = filteredByDayExpirationAndTypeViewName;
    if (self = [super initWithViewClass:viewClass viewName:viewName ftsName:ftsName]) {
    }
    return self;
}

- (void) registerDatabaseExtensions {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateAllMappingsWithCompletionBlock:^{
                [self.tableView reloadData];
            }];
        });
    });
}


- (void) dayButtonPressed:(id)sender {
    NSInteger currentSelection = [self indexForDay:self.selectedDay];
    self.dayPicker.selectedIndex = currentSelection;
    
    if (!self.dayPicker.isVisible) {
        [self.dayPicker showFromViewController:self];
    }
}

- (void) filterButtonPressed:(id)sender {
    BRCEventsFilterTableViewController *filterViewController = [[BRCEventsFilterTableViewController alloc] initWithDelegate:self];;
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
    self.dayPicker = [[BRCStringPickerView alloc] initWithTitle:@"Choose a Day" pickerStrings:self.dayPickerRowTitles initialSelection:currentSelection doneBlock:^(BRCStringPickerView *picker, NSUInteger selectedIndex, NSString *selectedValue) {
        NSDate *selectedDate = [self dateForIndex:selectedIndex];
        self.selectedDay = selectedDate;
    } cancelBlock:nil];
}

- (NSDate*) selectedDayInFestivalRange:(NSDate*)dayCandidate {
    NSDate *validDate = nil;
    if ([dayCandidate compare:[BRCEventObject festivalStartDate]] == NSOrderedDescending && [dayCandidate compare:[BRCEventObject festivalEndDate]] == NSOrderedAscending) {
        validDate = dayCandidate;
    } else {
        validDate = [BRCEventObject festivalStartDate];
    }
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
    [self updateAllMappingsWithCompletionBlock:^{
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

- (Class) cellClass {
    return [BRCEventObjectTableViewCell class];
}

- (void)updateFilteredViews
{
    self.isUpdatingFilters = YES;
    YapDatabaseViewFiltering *filtering = [BRCDatabaseManager eventsFiltering];
    [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        YapDatabaseViewFiltering *selectedDayFiltering =[BRCDatabaseManager eventsSelectedDayOnlyFiltering];
        YapDatabaseFilteredViewTransaction *filteredTransaction = [transaction ext:self.filteredByDayViewName];
        [filteredTransaction setFiltering:selectedDayFiltering versionTag:[[NSUUID UUID] UUIDString]];
        filteredTransaction = [transaction ext:self.filteredByDayExpirationAndTypeViewName];
        [filteredTransaction setFiltering:filtering versionTag:[[NSUUID UUID] UUIDString]];
    } completionBlock:^{
        self.isUpdatingFilters = NO;
        [self.tableView reloadData];
    }];
}

- (void) setupMappingsDictionary {
    self.mappingsDictionary = [NSMutableDictionary dictionaryWithCapacity:4];
    
    NSArray *allFestivalDates = [BRCEventObject datesOfFestival];
    NSMutableArray *allGroups = [NSMutableArray arrayWithCapacity:allFestivalDates.count];
    [allFestivalDates enumerateObjectsUsingBlock:^(NSDate *date, NSUInteger idx, BOOL *stop) {
        NSString *group = [[NSDateFormatter brc_eventGroupDateFormatter] stringFromDate:date];
        [allGroups addObject:group];
    }];
    
    [self replaceTimeBasedEventMappings];
}

- (YapDatabaseViewMappings*) activeMappings {
    YapDatabaseViewMappings *activeMappings = [self.mappingsDictionary objectForKey:self.filteredByDayExpirationAndTypeViewName];
    return activeMappings;
}

- (void) replaceTimeBasedEventMappings {
    NSString *group = [[NSDateFormatter brc_eventGroupDateFormatter] stringFromDate:self.selectedDay];
    NSArray *activeTimeGroup = @[group]; // selected day group
    NSArray *mappingsToRefresh = @[self.filteredByDayViewName, self.filteredByDayExpirationAndTypeViewName];
    [mappingsToRefresh enumerateObjectsUsingBlock:^(NSString *viewName, NSUInteger idx, BOOL *stop) {
        YapDatabaseViewMappings *mappings = [[YapDatabaseViewMappings alloc] initWithGroups:activeTimeGroup view:viewName];
        [self.mappingsDictionary setObject:mappings forKey:viewName];
    }];
}

- (void) refreshEventTimeSort {
    if (self.isRefreshingEventTimeSort) {
        return;
    }
    self.isRefreshingEventTimeSort = YES;
    
    // Refresh the distance view sorting block here
    
    [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        YapDatabaseViewTransaction *viewTransaction = [transaction ext:self.viewName];
        if (!viewTransaction) {
            return;
        }
        Class viewClass = self.viewClass;
        YapDatabaseViewGrouping *grouping = [BRCDatabaseManager groupingForClass:viewClass ];
        YapDatabaseViewSorting *sorting = [BRCDatabaseManager sortingForClass:viewClass];
        [viewTransaction setGrouping:grouping sorting:sorting versionTag:[[NSUUID UUID] UUIDString]];
    } completionBlock:^{
        [self updateAllMappingsWithCompletionBlock:^{
            [self.tableView reloadData];
            self.isRefreshingEventTimeSort = NO;
        }];
    }];
}

#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCEventObjectTableViewCell *cell = (BRCEventObjectTableViewCell*)[super tableView:tableView cellForRowAtIndexPath:indexPath];
    cell.eventDayLabel.hidden = NO;
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

@end
