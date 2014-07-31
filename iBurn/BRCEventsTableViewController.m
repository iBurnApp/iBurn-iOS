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

@interface BRCEventsTableViewController ()
@property (nonatomic, strong) NSDate *selectedDay;
@property (nonatomic, strong) NSDateFormatter *dayOfTheWeekFormatter;
@property (nonatomic, strong) NSArray *dayPickerRowTitles;
@property (nonatomic, strong) NSArray *festivalDates;
@property (nonatomic, strong) UISegmentedControl *dayPickerSegmentedControl;
@end

@implementation BRCEventsTableViewController

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
    self.dayOfTheWeekFormatter = [[NSDateFormatter alloc] init];
    self.dayOfTheWeekFormatter.dateFormat = @"EEEE";
    NSDateFormatter *shortDateFormatter = [[NSDateFormatter alloc] init];
    shortDateFormatter.dateFormat = @"M/d";
    self.selectedDay = [NSDate date];
    self.festivalDates = [BRCEventObject datesOfFestival];
    
    NSArray *majorEvents = [BRCEventObject majorEvents];
    
    NSParameterAssert(self.festivalDates.count == majorEvents.count);
    NSMutableArray *rowTitles = [NSMutableArray arrayWithCapacity:self.festivalDates.count];
    [self.festivalDates enumerateObjectsUsingBlock:^(NSDate *date, NSUInteger idx, BOOL *stop) {
        NSString *dayOfWeekString = [self.dayOfTheWeekFormatter stringFromDate:date];
        NSString *shortDateString = [shortDateFormatter stringFromDate:date];
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
    
    self.navigationItem.leftBarButtonItem.title = [self.dayOfTheWeekFormatter stringFromDate:self.selectedDay];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
}

- (NSArray *) segmentedControlInfo {
    NSArray *newTitles = @[@[@"Time", [BRCDatabaseManager extensionNameForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeTime]]];
    return [newTitles arrayByAddingObjectsFromArray:[super segmentedControlInfo]];
}

- (Class) cellClass {
    return [BRCEventObjectTableViewCell class];
}

- (void) setupMappingsDictionary {
    [super setupMappingsDictionary];
    NSMutableDictionary *mappingsDictionary = [self.mappingsDictionary mutableCopy];
    NSString *favoritesName = [BRCDatabaseManager filteredExtensionNameForClass:[self viewClass] filterType:BRCDatabaseFilteredViewTypeFavorites];
    NSString *timeName = [BRCDatabaseManager extensionNameForClass:self.viewClass extensionType:BRCDatabaseViewExtensionTypeTime];
    NSArray *favoritesGroups = @[@""];
    NSArray *activeTimeGroup = @[@""];
    YapDatabaseViewMappings *favoritesMappings = [[YapDatabaseViewMappings alloc] initWithGroups:favoritesGroups view:favoritesName];
    YapDatabaseViewMappings *timeMappings = [[YapDatabaseViewMappings alloc] initWithGroups:activeTimeGroup view:timeName];
    [mappingsDictionary setObject:favoritesMappings forKey:favoritesName];
    [mappingsDictionary setObject:timeMappings forKey:timeName];
    self.mappingsDictionary = mappingsDictionary;
}

@end
