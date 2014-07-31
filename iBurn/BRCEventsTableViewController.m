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

@interface BRCEventsTableViewController ()
@end

@implementation BRCEventsTableViewController

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
