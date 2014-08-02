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
#import "BRCActionSheetStringPicker.h"
#import "NSDate+iBurn.h"
#import "NSDateFormatter+iBurn.h"
#import "BRCEventsFilterTableViewController.h"

@interface BRCEventsTableViewController ()
@property (nonatomic, strong) NSDate *selectedDay;
@property (nonatomic, strong) NSArray *dayPickerRowTitles;
@property (nonatomic, strong) NSArray *festivalDates;
@property (nonatomic, strong) UISegmentedControl *dayPickerSegmentedControl;
@end

@implementation BRCEventsTableViewController
@synthesize selectedDay = _selectedDay;

- (instancetype) init {
    if (self = [super init]) {
    }
    return self;
}

- (void) dayButtonPressed:(id)sender {
    NSInteger currentSelection = [self indexForDay:self.selectedDay];
    BRCActionSheetStringPicker *dayPicker = [[BRCActionSheetStringPicker alloc] initWithTitle:nil rows:self.dayPickerRowTitles initialSelection:currentSelection doneBlock:^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
        NSDate *selectedDate = [self dateForIndex:selectedIndex];
        self.selectedDay = selectedDate;
    } cancelBlock:^(ActionSheetStringPicker *picker) {
        
    } origin:sender];
    dayPicker.segmentedControl = self.dayPickerSegmentedControl;
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
    self.navigationItem.rightBarButtonItem = filterButton;
    self.selectedDay = [NSDate date];

    [self setupDayPicker];
}

- (void)didChangeValueForDayPickerSegmentedControl:(UISegmentedControl *)sender
{
    // Mappings have changed
}

- (void) setupDayPickerSegmentedControl {
    self.dayPickerSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Soon", @"Now", @"All"]];
    self.dayPickerSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.dayPickerSegmentedControl.selectedSegmentIndex = 0;
    
    [self.dayPickerSegmentedControl addTarget:self action:@selector(didChangeValueForDayPickerSegmentedControl:) forControlEvents:UIControlEventValueChanged];
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
    [self setupDayPickerSegmentedControl];
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
    return @[@[@"Time", [BRCDatabaseManager extensionNameForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeTime]],
             @[@"Distance", [BRCDatabaseManager sharedInstance].eventDistanceViewName],
             @[@"Name", [BRCDatabaseManager sharedInstance].eventDistanceViewName],
             @[@"Favorites", [BRCDatabaseManager sharedInstance].eventDistanceViewName]];
}

- (Class) cellClass {
    return [BRCEventObjectTableViewCell class];
}

- (void) setupMappingsDictionary {
    //[super setupMappingsDictionary];
    self.mappingsDictionary = [NSMutableDictionary dictionaryWithCapacity:4];
    NSString *favoritesName = [BRCDatabaseManager filteredExtensionNameForClass:[self viewClass] filterType:BRCDatabaseFilteredViewTypeFavorites parentName:[BRCDatabaseManager extensionNameForClass:[self viewClass] extensionType:BRCDatabaseViewExtensionTypeTime]];
    
    
    NSArray *allFestivalDates = [BRCEventObject datesOfFestival];
    NSMutableArray *allGroups = [NSMutableArray arrayWithCapacity:allFestivalDates.count];
    [allFestivalDates enumerateObjectsUsingBlock:^(NSDate *date, NSUInteger idx, BOOL *stop) {
        NSString *group = [[NSDateFormatter brc_threadSafeGroupDateFormatter] stringFromDate:date];
        [allGroups addObject:group];
    }];
    
    YapDatabaseViewMappings *favoritesMappings = [[YapDatabaseViewMappings alloc] initWithGroups:allGroups view:favoritesName];
    [self.mappingsDictionary setObject:favoritesMappings forKey:favoritesName];
    [self replaceTimeBasedEventMappings];
}

- (void) replaceTimeBasedEventMappings {
    NSString *timeName = [BRCDatabaseManager sharedInstance].eventTimeViewName;
    NSString *nameName = [BRCDatabaseManager sharedInstance].eventNameViewName;
    NSString *distanceName = [BRCDatabaseManager sharedInstance].eventDistanceViewName;

    NSString *group = [[NSDateFormatter brc_threadSafeGroupDateFormatter] stringFromDate:self.selectedDay];
    NSArray *activeTimeGroup = @[group]; // selected day group
    
    NSArray *mappingsToRefresh = @[timeName, nameName, distanceName];
    
    [mappingsToRefresh enumerateObjectsUsingBlock:^(NSString *viewName, NSUInteger idx, BOOL *stop) {
        YapDatabaseViewMappings *mappings = [[YapDatabaseViewMappings alloc] initWithGroups:activeTimeGroup view:viewName];
        [self.mappingsDictionary setObject:mappings forKey:viewName];
    }];
}


@end
