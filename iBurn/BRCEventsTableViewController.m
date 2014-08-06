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
#import "ActionSheetStringPicker.h"

@interface BRCEventsTableViewController ()
@property (nonatomic, strong) NSDate *selectedDay;
@property (nonatomic, strong) NSArray *dayPickerRowTitles;
@property (nonatomic, strong) NSArray *festivalDates;
@property (nonatomic, strong) UISegmentedControl *dayPickerSegmentedControl;
@property (nonatomic, strong, readwrite) NSString *timeAndDistanceViewName;
@property (nonatomic, strong, readwrite) NSString *filteredTimeAndDistanceViewName;
@property (nonatomic, strong, readwrite) NSString *filteredDistanceViewName;
@end

@implementation BRCEventsTableViewController
@synthesize selectedDay = _selectedDay;

- (void) setupViewNames {
    [super setupViewNames];
    self.timeAndDistanceViewName = [BRCDatabaseManager databaseViewNameForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeTime];
    self.filteredTimeAndDistanceViewName = [BRCDatabaseManager filteredViewNameForType:BRCDatabaseFilteredViewTypeEventExpirationAndType parentViewName:self.timeAndDistanceViewName];
    self.filteredDistanceViewName = [BRCDatabaseManager filteredViewNameForType:BRCDatabaseFilteredViewTypeEventExpirationAndType parentViewName:self.distanceViewName];
    self.favoritesViewName = [BRCDatabaseManager filteredViewNameForType:BRCDatabaseFilteredViewTypeFavorites parentViewName:self.timeAndDistanceViewName];
}


- (void) dayButtonPressed:(id)sender {
    NSInteger currentSelection = [self indexForDay:self.selectedDay];
    ActionSheetStringPicker *dayPicker = [[ActionSheetStringPicker alloc] initWithTitle:@"Choose a Day" rows:self.dayPickerRowTitles initialSelection:currentSelection doneBlock:^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
        NSDate *selectedDate = [self dateForIndex:selectedIndex];
        self.selectedDay = selectedDate;
        [self refreshDistanceInformationFromLocation:self.locationManager.location];
    } cancelBlock:nil origin:sender];
    [dayPicker showActionSheetPicker];
}

- (void) filterButtonPressed:(id)sender {
    BRCEventsFilterTableViewController *filterViewController = [[BRCEventsFilterTableViewController alloc] init];
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
}

- (void) setSelectedDay:(NSDate *)selectedDay {
    if ([selectedDay compare:[BRCEventObject festivalStartDate]] == NSOrderedDescending && [selectedDay compare:[BRCEventObject festivalEndDate]] == NSOrderedAscending) {
        _selectedDay = selectedDay;
    } else {
        _selectedDay = [BRCEventObject festivalStartDate];
    }
    NSString *dayString = [[NSDateFormatter brc_dayOfWeekDateFormatter] stringFromDate:self.selectedDay];
    self.navigationItem.leftBarButtonItem.title = dayString;
    [self replaceTimeBasedEventMappings];
    [self updateAllMappings];
    [self.tableView reloadData];
}

- (NSDate*) selectedDay {
    if (!_selectedDay) {
        self.selectedDay = [NSDate date];
    }
    return _selectedDay;
}

- (NSArray *) segmentedControlInfo {
    return @[@[@"Time", self.filteredTimeAndDistanceViewName],
             @[@"Distance", self.filteredDistanceViewName],
             @[@"Favorites", self.favoritesViewName]];
}

- (Class) cellClass {
    return [BRCEventObjectTableViewCell class];
}



- (void) refreshDistanceInformationFromLocation:(CLLocation*)fromLocation {
    if (self.updatingDistanceInformation) {
        return;
    }
    if (![self shouldRefreshDistanceInformationForNewLocation:fromLocation]) {
        return;
    }
    self.updatingDistanceInformation = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL success = NO;
        YapDatabaseView *timeAndDistanceView = [BRCDatabaseManager databaseViewForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeTime fromLocation:fromLocation];
        [[BRCDatabaseManager sharedInstance].database unregisterExtension:self.timeAndDistanceViewName];
        success = [[BRCDatabaseManager sharedInstance].database registerExtension:timeAndDistanceView withName:self.timeAndDistanceViewName];
        NSLog(@"%@ %d", self.timeAndDistanceViewName, success);
        NSSet *allowedCollections = [self allowedCollections];
        YapDatabaseFilteredView *filteredTimeAndDistanceView = [BRCDatabaseManager filteredViewForType:BRCDatabaseFilteredViewTypeEventExpirationAndType parentViewName:self.timeAndDistanceViewName allowedCollections:allowedCollections];
        [[BRCDatabaseManager sharedInstance].database unregisterExtension:self.filteredTimeAndDistanceViewName];
        success = [[BRCDatabaseManager sharedInstance].database registerExtension:filteredTimeAndDistanceView withName:self.filteredTimeAndDistanceViewName];
        NSLog(@"%@ %d", self.filteredTimeAndDistanceViewName, success);

        
        YapDatabaseView *distanceView = [BRCDatabaseManager databaseViewForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeDistance fromLocation:fromLocation];
        [[BRCDatabaseManager sharedInstance].database unregisterExtension:self.distanceViewName];
        success = [[BRCDatabaseManager sharedInstance].database registerExtension:distanceView withName:self.distanceViewName];
        NSLog(@"%@ %d", self.distanceViewName, success);
        YapDatabaseFilteredView *filteredDistanceView = [BRCDatabaseManager filteredViewForType:BRCDatabaseFilteredViewTypeEventExpirationAndType parentViewName:self.distanceViewName allowedCollections:allowedCollections];
        [[BRCDatabaseManager sharedInstance].database unregisterExtension:self.filteredDistanceViewName];
        success = [[BRCDatabaseManager sharedInstance].database registerExtension:filteredDistanceView withName:self.filteredDistanceViewName];
        NSLog(@"%@ %d", self.filteredDistanceViewName, success);
        
        YapDatabaseFilteredView *favoritesView = [BRCDatabaseManager filteredViewForType:BRCDatabaseFilteredViewTypeFavorites parentViewName:self.timeAndDistanceViewName allowedCollections:allowedCollections];
        [[BRCDatabaseManager sharedInstance].database unregisterExtension:self.favoritesViewName];
        success = [[BRCDatabaseManager sharedInstance].database registerExtension:favoritesView withName:self.favoritesViewName];
        NSLog(@"%@ %d", self.favoritesViewName, success);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateAllMappings];
            self.updatingDistanceInformation = NO;
            self.lastDistanceUpdateLocation = fromLocation;
        });
    });
}
- (void) setupMappingsDictionary {
    self.mappingsDictionary = [NSMutableDictionary dictionaryWithCapacity:4];
    
    NSArray *allFestivalDates = [BRCEventObject datesOfFestival];
    NSMutableArray *allGroups = [NSMutableArray arrayWithCapacity:allFestivalDates.count];
    [allFestivalDates enumerateObjectsUsingBlock:^(NSDate *date, NSUInteger idx, BOOL *stop) {
        NSString *group = [[NSDateFormatter brc_threadSafeGroupDateFormatter] stringFromDate:date];
        [allGroups addObject:group];
    }];
    
    YapDatabaseViewMappings *favoritesMappings = [[YapDatabaseViewMappings alloc] initWithGroups:allGroups view:self.favoritesViewName];
    [self.mappingsDictionary setObject:favoritesMappings forKey:self.favoritesViewName];
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
    if ([self isSearchResultsControllerTableView:tableView]) {
        cell.eventDayLabel.hidden = NO;
    } else {
        cell.eventDayLabel.hidden = YES;
    }
    return cell;

}


@end
