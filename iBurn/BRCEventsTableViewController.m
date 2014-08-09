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
@property (nonatomic, strong) NSDate *selectedDay;
@property (nonatomic, strong) NSArray *dayPickerRowTitles;
@property (nonatomic, strong) NSArray *festivalDates;
@property (nonatomic, strong) UISegmentedControl *dayPickerSegmentedControl;
@property (nonatomic, strong, readwrite) NSString *timeAndDistanceViewName;
@property (nonatomic, strong, readwrite) NSString *filteredTimeAndDistanceViewName;
@property (nonatomic, strong, readwrite) NSString *filteredDistanceViewName;
@property (nonatomic, strong, readwrite) NSString *favoritesFilterForTimeAndDistanceViewName;

@property (nonatomic, strong) BRCStringPickerView *dayPicker;
@end

@implementation BRCEventsTableViewController
@synthesize selectedDay = _selectedDay;

- (void) setupDatabaseExtensionNames {
    [super setupDatabaseExtensionNames];
    self.timeAndDistanceViewName = [BRCDatabaseManager databaseViewNameForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeTimeThenDistance];
    self.filteredTimeAndDistanceViewName = [BRCDatabaseManager filteredViewNameForType:BRCDatabaseFilteredViewTypeEventExpirationAndType parentViewName:self.timeAndDistanceViewName];
    self.filteredDistanceViewName = [BRCDatabaseManager filteredViewNameForType:BRCDatabaseFilteredViewTypeEventExpirationAndType parentViewName:self.distanceViewName];
    self.favoritesFilterForTimeAndDistanceViewName = [BRCDatabaseManager filteredViewNameForType:BRCDatabaseFilteredViewTypeFavoritesOnly parentViewName:self.timeAndDistanceViewName];
}

- (void) registerDatabaseExtensions {
    [self registerFullTextSearchExtension];
    CLLocation *fromLocation = self.locationManager.location;
    self.isUpdatingDistanceInformation = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL success = NO;
        YapDatabaseView *timeAndDistanceView = [BRCDatabaseManager databaseViewForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeTimeThenDistance fromLocation:fromLocation];
        success = [[BRCDatabaseManager sharedInstance].database registerExtension:timeAndDistanceView withName:self.timeAndDistanceViewName];
        NSLog(@"%@ %d", self.timeAndDistanceViewName, success);
        NSSet *allowedCollections = [self allowedCollections];
        YapDatabaseFilteredView *filteredTimeAndDistanceView = [BRCDatabaseManager filteredViewForType:BRCDatabaseFilteredViewTypeEventExpirationAndType parentViewName:self.timeAndDistanceViewName allowedCollections:allowedCollections];
        success = [[BRCDatabaseManager sharedInstance].database registerExtension:filteredTimeAndDistanceView withName:self.filteredTimeAndDistanceViewName];
        NSLog(@"%@ %d", self.filteredTimeAndDistanceViewName, success);
        
        YapDatabaseView *distanceView = [BRCDatabaseManager databaseViewForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeDistance fromLocation:fromLocation];
        success = [[BRCDatabaseManager sharedInstance].database registerExtension:distanceView withName:self.distanceViewName];
        NSLog(@"%@ %d", self.distanceViewName, success);
        YapDatabaseFilteredView *filteredDistanceView = [BRCDatabaseManager filteredViewForType:BRCDatabaseFilteredViewTypeEventExpirationAndType parentViewName:self.distanceViewName allowedCollections:allowedCollections];
        success = [[BRCDatabaseManager sharedInstance].database registerExtension:filteredDistanceView withName:self.filteredDistanceViewName];
        NSLog(@"%@ %d", self.filteredDistanceViewName, success);
        
        YapDatabaseFilteredView *favoritesView = [BRCDatabaseManager filteredViewForType:BRCDatabaseFilteredViewTypeFavoritesOnly parentViewName:self.timeAndDistanceViewName allowedCollections:allowedCollections];
        success = [[BRCDatabaseManager sharedInstance].database registerExtension:favoritesView withName:self.favoritesFilterForTimeAndDistanceViewName];
        NSLog(@"%@ %d", self.favoritesFilterForTimeAndDistanceViewName, success);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateAllMappingsWithCompletionBlock:^{
                self.isUpdatingDistanceInformation = NO;
                self.lastDistanceUpdateLocation = fromLocation;
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
        [self refreshDistanceInformationFromLocation:self.locationManager.location];
    } cancelBlock:nil];
}

- (void) setSelectedDay:(NSDate *)selectedDay {
    if (!selectedDay) {
        selectedDay = [NSDate date];
    }
    if ([selectedDay compare:[BRCEventObject festivalStartDate]] == NSOrderedDescending && [selectedDay compare:[BRCEventObject festivalEndDate]] == NSOrderedAscending) {
        _selectedDay = selectedDay;
    } else {
        _selectedDay = [BRCEventObject festivalStartDate];
    }
    NSString *dayString = [[NSDateFormatter brc_dayOfWeekDateFormatter] stringFromDate:_selectedDay];
    self.navigationItem.leftBarButtonItem.title = dayString;
    [self replaceTimeBasedEventMappings];
    [self updateAllMappingsWithCompletionBlock:^{
        [self.tableView reloadData];
    }];
}

- (void)didChangeValueForSegmentedControl:(UISegmentedControl *)sender
{
    [self.tableView reloadData];
}

- (NSDate*) selectedDay {
    if (!_selectedDay) {
        _selectedDay = [NSDate date];
    }
    return _selectedDay;
}

- (NSArray *) segmentedControlInfo {
    return @[@[@"Time", self.filteredTimeAndDistanceViewName],
             @[@"Distance", self.filteredDistanceViewName],
             @[@"Favorites", self.favoritesFilterForTimeAndDistanceViewName]];
}

- (Class) cellClass {
    return [BRCEventObjectTableViewCell class];
}

- (void)updateFilteredViewsCompletion:(void (^)(void))completion
{
    YapDatabaseViewBlockType filterBlockType = YapDatabaseViewBlockTypeWithObject;
    YapDatabaseViewFilteringBlock filteringBlock = [BRCDatabaseManager eventsFilteringBlock];
    
    NSString *timeViewName = [BRCDatabaseManager databaseViewNameForClass:[BRCEventObject class] extensionType:BRCDatabaseViewExtensionTypeTimeThenDistance];
    NSString *filteredTimeViewName = [BRCDatabaseManager filteredViewNameForType:BRCDatabaseFilteredViewTypeEventExpirationAndType parentViewName:timeViewName];
    
    NSString *distanceViewName = [BRCDatabaseManager databaseViewNameForClass:[BRCEventObject class] extensionType:BRCDatabaseViewExtensionTypeDistance];
    
    NSString *filteredDistanceViewName = [BRCDatabaseManager filteredViewNameForType:BRCDatabaseFilteredViewTypeEventExpirationAndType parentViewName:distanceViewName];
    
    NSArray *eventsFilteredByExpirationAndTypeViewsArray = @[filteredTimeViewName, filteredDistanceViewName];
    
    [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [eventsFilteredByExpirationAndTypeViewsArray enumerateObjectsUsingBlock:^(NSString *filteredViewName, NSUInteger idx, BOOL *stop) {
            YapDatabaseFilteredViewTransaction *filteredTransaction = [transaction ext:filteredViewName];
            [filteredTransaction setFilteringBlock:filteringBlock
                                filteringBlockType:filterBlockType
                                        versionTag:[[NSUUID UUID] UUIDString]];
        }];
    } completionBlock:completion];
}

- (void) setupMappingsDictionary {
    self.mappingsDictionary = [NSMutableDictionary dictionaryWithCapacity:4];
    
    NSArray *allFestivalDates = [BRCEventObject datesOfFestival];
    NSMutableArray *allGroups = [NSMutableArray arrayWithCapacity:allFestivalDates.count];
    [allFestivalDates enumerateObjectsUsingBlock:^(NSDate *date, NSUInteger idx, BOOL *stop) {
        NSString *group = [[NSDateFormatter brc_threadSafeGroupDateFormatter] stringFromDate:date];
        [allGroups addObject:group];
    }];
    
    YapDatabaseViewMappings *favoritesMappings = [[YapDatabaseViewMappings alloc] initWithGroups:allGroups view:self.favoritesFilterForTimeAndDistanceViewName];
    [self.mappingsDictionary setObject:favoritesMappings forKey:self.favoritesFilterForTimeAndDistanceViewName];
    [self replaceTimeBasedEventMappings];
}

- (void) replaceTimeBasedEventMappings {
    NSString *group = [[NSDateFormatter brc_threadSafeGroupDateFormatter] stringFromDate:self.selectedDay];
    NSArray *activeTimeGroup = @[group]; // selected day group
    NSArray *mappingsToRefresh = @[self.filteredTimeAndDistanceViewName, self.filteredDistanceViewName];
    [mappingsToRefresh enumerateObjectsUsingBlock:^(NSString *viewName, NSUInteger idx, BOOL *stop) {
        YapDatabaseViewMappings *mappings = [[YapDatabaseViewMappings alloc] initWithGroups:activeTimeGroup view:viewName];
        [self.mappingsDictionary setObject:mappings forKey:viewName];
    }];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCEventObjectTableViewCell *cell = (BRCEventObjectTableViewCell*)[super tableView:tableView cellForRowAtIndexPath:indexPath];
    cell.eventDayLabel.hidden = NO;
    return cell;
}

 #pragma - mark BRCEventsFilterTableViewControllerDelegate Methods

- (void)didSetNewFilterSettingsInFilterTableViewController:(BRCEventsFilterTableViewController *)viewController
{
    [self updateFilteredViewsCompletion:nil];
}

@end
