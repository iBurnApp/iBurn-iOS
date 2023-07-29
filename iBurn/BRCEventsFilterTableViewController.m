//
//  BRCEventsFilterTableViewController.m
//  iBurn
//
//  Created by David Chiles on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCEventsFilterTableViewController.h"
#import "BRCEventObject.h"
#import "NSUserDefaults+iBurn.h"
#import "BRCDatabaseManager.h"
#import "iBurn-Swift.h"
@import YapDatabase;

typedef NS_ENUM(NSUInteger, BRCTableSection) {
    BRCTableSectionTime,
    BRCTableSectionActions,
    BRCTableSectionType
};

typedef NS_ENUM(NSUInteger, BRCTableAction) {
    BRCTableActionSelectAll,
    BRCTableActionSelectNone
};

NSString *const BRCFilterTableViewCellIdentifier = @"BRCFilterTableViewCellIdentifier";

@interface BRCEventTypeContainer : NSObject

@property (nonatomic, readonly) BRCEventType type;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic) BOOL isSelected;

@end

@implementation BRCEventTypeContainer

- (instancetype)initWithType:(BRCEventType)type
{
    if (self = [self init]) {
        _type = type;
        _title = [BRCEventObject stringForEventType:self.type];
    }
    return self;
}

@end

@interface BRCEventsFilterTableViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *tableViewDataSource;
@property (nonatomic, weak) id <BRCEventsFilterTableViewControllerDelegate> delegate;
@property (nonatomic, strong) NSArray *timeStrings;
@property (nonatomic, strong, readonly) NSArray<NSString*> *actionsArray;
@property (nonatomic, strong) NSArray<BRCEventTypeContainer*> *eventTypeArray;

@property (nonatomic) BOOL showExpiredEvents;
@property (nonatomic) BOOL searchSelectedDayOnly;
@property (nonatomic) BOOL showAllDayEvents;

@property (nonatomic, strong) YapDatabaseConnection* databaseConnection;

@end

@implementation BRCEventsFilterTableViewController

- (id)init
{
    if (self = [super init]) {
        self.databaseConnection = BRCDatabaseManager.shared.readWriteConnection;
    }
    return self;
}

- (instancetype)initWithDelegate:(id<BRCEventsFilterTableViewControllerDelegate>)delegate
{
    if (self = [self init]) {
        self.delegate = delegate;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Filter";
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:BRCFilterTableViewCellIdentifier];
    
    self.timeStrings = @[@"Show Expired Events", @"Search Selected Day Only", @"Show All Day Events"];
    _actionsArray = @[@"Select All", @"Select None"];
    
    self.showExpiredEvents = [[NSUserDefaults standardUserDefaults] showExpiredEvents];
    self.searchSelectedDayOnly = UserSettings.searchSelectedDayOnly;
    self.showAllDayEvents = [NSUserDefaults standardUserDefaults].showAllDayEvents;
    
    //All the event types to select from
    NSArray *eventTypes = BRCEventObject.allVisibleEventTypes;
    
    NSMutableArray *eventTypeMutableArray = [NSMutableArray new];
    
    NSArray *storedSelectedEventTypes = [[NSUserDefaults standardUserDefaults] selectedEventTypes];
    
    [eventTypes enumerateObjectsUsingBlock:^(NSNumber *number, NSUInteger idx, BOOL *stop) {
        BRCEventType type = [number unsignedIntegerValue];
        BRCEventTypeContainer *container = [[BRCEventTypeContainer alloc] initWithType:type];
        container.isSelected = [storedSelectedEventTypes containsObject:@(type)];
        
        [eventTypeMutableArray addObject:container];
    }];
    
    self.eventTypeArray = [eventTypeMutableArray copy];
    
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed:)];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonPressed:)];
    
    self.navigationItem.leftBarButtonItem = cancel;
    self.navigationItem.rightBarButtonItem = done;
    
    [self.view addSubview:self.tableView];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.delegate didSetNewFilterSettings:self];    
}

- (NSArray *)filteredTypes
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isSelected = YES"];
    NSArray *filteredArray = [self.eventTypeArray filteredArrayUsingPredicate:predicate];
    NSArray *filteredTypes = [filteredArray valueForKey:NSStringFromSelector(@selector(type))];
    return filteredTypes;
}

- (void)doneButtonPressed:(id)sender
{
    NSArray *filteredArray = [self filteredTypes];
    [[NSUserDefaults standardUserDefaults] setSelectedEventTypes:filteredArray];
    [[NSUserDefaults standardUserDefaults] setShowExpiredEvents:self.showExpiredEvents];
    UserSettings.searchSelectedDayOnly = self.searchSelectedDayOnly;
    NSUserDefaults.standardUserDefaults.showAllDayEvents = self.showAllDayEvents;
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)cancelButtonPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma - mark UITableViewDataSource Methods

////// Required //////
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch ((BRCTableSection)section) {
        case BRCTableSectionTime:
            return [self.timeStrings count];
        case BRCTableSectionActions:
            return self.actionsArray.count;
        case BRCTableSectionType:
            return [self.eventTypeArray count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:BRCFilterTableViewCellIdentifier];
    
    BRCImageColors *colors = Appearance.currentColors;
    BOOL showCheckMark = NO;
    switch ((BRCTableSection)indexPath.section) {
        case BRCTableSectionTime: {
            if (indexPath.row == 0) {
                showCheckMark = self.showExpiredEvents;
            } else if (indexPath.row == 1) {
                showCheckMark = self.searchSelectedDayOnly;
            } else if (indexPath.row == 2) {
                showCheckMark = self.showAllDayEvents;
            }
            NSString *text = self.timeStrings[indexPath.row];
            cell.textLabel.text = text;
            break;
        }
        case BRCTableSectionActions: {
            NSString *action = self.actionsArray[indexPath.row];
            cell.textLabel.text = action;
            break;
        }
        case BRCTableSectionType: {
            BRCEventTypeContainer *container = self.eventTypeArray[indexPath.row];
            showCheckMark = container.isSelected;
            cell.textLabel.text = container.title;
            colors = [BRCImageColors colorsFor:container.type];
            break;
        }
    }
    cell.textLabel.textColor = colors.secondaryColor;
    cell.backgroundColor = colors.backgroundColor;
    
    if (showCheckMark) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
    
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch ((BRCTableSection)section) {
        case BRCTableSectionTime:
            return @"Time";
        case BRCTableSectionActions:
            return nil;
        case BRCTableSectionType:
            return @"Type";
    }
}


#pragma - mark UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch ((BRCTableSection)indexPath.section) {
        case BRCTableSectionTime: {
            if (indexPath.row == 0) {
                self.showExpiredEvents = !self.showExpiredEvents;
            } else if (indexPath.row == 1) {
                self.searchSelectedDayOnly = !self.searchSelectedDayOnly;
            } else if (indexPath.row == 2) {
                self.showAllDayEvents = !self.showAllDayEvents;
            }
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        }
        case BRCTableSectionActions: {
            BOOL shouldSelect = NO;
            switch ((BRCTableAction)indexPath.row) {
                case BRCTableActionSelectAll:
                    shouldSelect = YES;
                    break;
                case BRCTableActionSelectNone:
                    shouldSelect = NO;
                    break;
            }
            [self.eventTypeArray enumerateObjectsUsingBlock:^(BRCEventTypeContainer *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                obj.isSelected = shouldSelect;
            }];
            [tableView reloadSections:[[NSIndexSet alloc] initWithIndex:BRCTableSectionType] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        }
        case BRCTableSectionType: {
            BRCEventTypeContainer *container = self.eventTypeArray[indexPath.row];
            container.isSelected = !container.isSelected;
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        }
    }
}



@end
