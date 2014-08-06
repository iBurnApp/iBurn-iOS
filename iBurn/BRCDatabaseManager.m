//
//  BRCDatabaseManager.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDatabaseManager.h"
#import "YapDatabaseRelationship.h"
#import "YapDatabaseView.h"
#import "YapDatabaseFullTextSearch.h"
#import "BRCArtObject.h"
#import "BRCEventObject.h"
#import "BRCCampObject.h"
#import "YapDatabaseFilteredView.h"
#import "NSDateFormatter+iBurn.h"
#import "NSUserDefaults+iBurn.h"

@interface BRCDatabaseManager()
@property (nonatomic, strong) YapDatabase *database;
@property (nonatomic, strong) YapDatabaseConnection *readOnlyConnection;
@property (nonatomic, strong) YapDatabaseConnection *readWriteDatabaseConnection;
@end

@implementation BRCDatabaseManager

- (NSString *)yapDatabaseDirectory {
    NSString *applicationSupportDirectory = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
    NSString *directory = [applicationSupportDirectory stringByAppendingPathComponent:applicationName];
    return directory;
}

- (NSString *)yapDatabasePathWithName:(NSString *)name
{
    
    return [[self yapDatabaseDirectory] stringByAppendingPathComponent:name];
}

- (BOOL)setupDatabaseWithName:(NSString *)name
{
    YapDatabaseOptions *options = [[YapDatabaseOptions alloc] init];
    options.corruptAction = YapDatabaseCorruptAction_Fail;
    
    NSString *databaseDirectory = [self yapDatabaseDirectory];
    if (![[NSFileManager defaultManager] fileExistsAtPath:databaseDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:databaseDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *databasePath = [self yapDatabasePathWithName:name];
    
    self.database = [[YapDatabase alloc] initWithPath:databasePath
                                     objectSerializer:NULL
                                   objectDeserializer:NULL
                                   metadataSerializer:NULL
                                 metadataDeserializer:NULL
                                      objectSanitizer:NULL
                                    metadataSanitizer:NULL
                                              options:options];
    self.database.defaultObjectPolicy = YapDatabasePolicyShare;
    self.readWriteDatabaseConnection = [self.database newConnection];
    self.readWriteDatabaseConnection.objectPolicy = YapDatabasePolicyShare;
    self.readWriteDatabaseConnection.objectCacheLimit = 200;
    self.readWriteDatabaseConnection.metadataCacheLimit = 200;
    self.readWriteDatabaseConnection.name = @"readWriteDatabaseConnection";
    
    self.readOnlyConnection = [self.database newConnection];
    self.readWriteDatabaseConnection.objectPolicy = YapDatabasePolicyShare;
    self.readWriteDatabaseConnection.objectCacheLimit = 200;
    self.readWriteDatabaseConnection.metadataCacheLimit = 200;
    self.readWriteDatabaseConnection.name = @"readOnlyDatabaseConnection";

    if (self.database) {
        return YES;
    }
    else {
        return NO;
    }
}

+ (instancetype)sharedInstance
{
    static id databaseManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        databaseManager = [[[self class] alloc] init];
    });
    
    return databaseManager;
}

+ (YapDatabaseViewBlockType)groupingBlockTypeForClass:(Class)viewClass extensionType:(BRCDatabaseViewExtensionType)extensionType {
    YapDatabaseViewBlockType groupingBlockType;
    if (viewClass == [BRCEventObject class]) {
        groupingBlockType = YapDatabaseViewBlockTypeWithObject;
    } else {
        groupingBlockType = YapDatabaseViewBlockTypeWithKey;
    }
    
    return groupingBlockType;
}

+ (YapDatabaseViewGroupingBlock)groupingBlockForClass:(Class)viewClass extensionType:(BRCDatabaseViewExtensionType)extensionType {
    YapDatabaseViewGroupingBlock groupingBlock;
    
    if (viewClass == [BRCEventObject class]) {
        groupingBlock = ^NSString *(NSString *collection, NSString *key, id object){
            if ([object isKindOfClass:[BRCEventObject class]]) {
                BRCEventObject *eventObject = (BRCEventObject*)object;
                NSDateFormatter *dateFormatter = [NSDateFormatter brc_threadSafeGroupDateFormatter];
                NSString *groupName = [dateFormatter stringFromDate:eventObject.startDate];
                return groupName;
            }
            return nil;
        };
    } else {
        groupingBlock = ^NSString *(NSString *collection, NSString *key){
            if ([collection isEqualToString:[viewClass collection]])
            {
                return [viewClass collection];
            }
            return nil;
        };
    }
    
    return groupingBlock;
}

+ (YapDatabaseViewBlockType)sortingBlockTypeForClass:(Class)viewClass extensionType:(BRCDatabaseViewExtensionType)extensionType {
    YapDatabaseViewBlockType sortingBlockType = YapDatabaseViewBlockTypeWithObject;
    return sortingBlockType;
}

+ (NSComparisonResult) compareDistanceOfFirstObject:(BRCDataObject*)object1 secondObject:(BRCDataObject*)object2 fromLocation:(CLLocation*)fromLocation {
    CLLocation *currentLocation = fromLocation;
    if (!currentLocation) {
        return NSOrderedSame;
    }
    CLLocation *location1 = [object1 location];
    CLLocationDistance distance1 = [location1 distanceFromLocation:currentLocation];
    CLLocation *location2 = [object2 location];
    CLLocationDistance distance2 = [location2 distanceFromLocation:currentLocation];
    if (location1 && !location2) {
        return NSOrderedAscending;
    } else if (!location1 && location2) {
        return NSOrderedDescending;
    } else if (!location1 && !location2) {
        return NSOrderedSame;
    }
    return [@(distance1) compare:@(distance2)];
}

+ (YapDatabaseViewSortingBlock)sortingBlockForClass:(Class)viewClass extensionType:(BRCDatabaseViewExtensionType)extensionType fromLocation:(CLLocation*)fromLocation {
    YapDatabaseViewSortingBlock sortingBlock;
    if (extensionType == BRCDatabaseViewExtensionTypeTime) {
        sortingBlock = ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
                         NSString *collection2, NSString *key2, id obj2){
            if ([obj1 isKindOfClass:[BRCEventObject class]] && [obj2 isKindOfClass:[BRCEventObject class]]) {
                BRCEventObject *event1 = (BRCEventObject *)obj1;
                BRCEventObject *event2 = (BRCEventObject *)obj2;
                
                if (event1.isAllDay && !event2.isAllDay) {
                    return NSOrderedDescending;
                }
                else if (!event1.isAllDay && event2.isAllDay) {
                    return NSOrderedAscending;
                }
                
                NSComparisonResult dateComparison = [event1.startDate compare:event2.startDate];
                if (dateComparison == NSOrderedSame) {
                    NSComparisonResult distanceComparison = [self compareDistanceOfFirstObject:event1 secondObject:event2 fromLocation:fromLocation];
                    return distanceComparison;
                } else {
                    return dateComparison;
                }
            }
            return NSOrderedSame;
        };
    } else if (extensionType == BRCDatabaseViewExtensionTypeDistance) {
        sortingBlock = ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
                         NSString *collection2, NSString *key2, id obj2){
            if ([obj1 isKindOfClass:viewClass] && [obj2 isKindOfClass:viewClass]) {
                BRCDataObject *data1 = (BRCDataObject *)obj1;
                BRCDataObject *data2 = (BRCDataObject *)obj2;
                NSComparisonResult result = [self compareDistanceOfFirstObject:data1 secondObject:data2 fromLocation:fromLocation];
                if (result == NSOrderedSame) {
                    result = [data1.title compare:data2.title];
                }
                return result;
            }
            return NSOrderedSame;
        };
    }
    
    return sortingBlock;
}

/**
 *  Does not register the view, but checks if it is registered and returns
 *  the registered view if it exists. (Caller should register the view)
 */
+ (YapDatabaseView*) databaseViewForClass:(Class)viewClass
                            extensionType:(BRCDatabaseViewExtensionType)extensionType
                             fromLocation:(CLLocation*)fromLocation
{
    YapDatabaseViewBlockType groupingBlockType = [[self class] groupingBlockTypeForClass:viewClass extensionType:extensionType];
    YapDatabaseViewGroupingBlock groupingBlock = [[self class] groupingBlockForClass:viewClass extensionType:extensionType];
    YapDatabaseViewBlockType sortingBlockType = [[self class] sortingBlockTypeForClass:viewClass extensionType:extensionType];
    YapDatabaseViewSortingBlock sortingBlock = [[self class] sortingBlockForClass:viewClass extensionType:extensionType fromLocation:fromLocation];
    YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
    NSString *versionTag = versionTag = [[NSUUID UUID] UUIDString];
    options.allowedCollections = [NSSet setWithObject:[viewClass collection]];
    
    YapDatabaseView *databaseView =
    [[YapDatabaseView alloc] initWithGroupingBlock:groupingBlock
                                 groupingBlockType:groupingBlockType
                                      sortingBlock:sortingBlock
                                  sortingBlockType:sortingBlockType
                                        versionTag:versionTag
                                           options:options];
    return databaseView;
}

+ (NSString*) fullTextSearchNameForClass:(Class)viewClass
                   withIndexedProperties:(NSArray *)properties {
    NSMutableString *viewName = [NSMutableString stringWithString:NSStringFromClass(viewClass)];
    [viewName appendString:@"-SearchFilter("];
    [properties enumerateObjectsUsingBlock:^(NSString *property, NSUInteger idx, BOOL *stop) {
        [viewName appendString:property];
        if (idx - 1 < properties.count) {
            [viewName appendString:@","];
        }
    }];
    [viewName appendString:@")"];
    return viewName;
}

+ (YapDatabaseFullTextSearch*) fullTextSearchForClass:(Class)viewClass
                                withIndexedProperties:(NSArray *)properties
{
    YapDatabaseFullTextSearchBlockType blockType = YapDatabaseFullTextSearchBlockTypeWithObject;
    YapDatabaseFullTextSearchWithObjectBlock block = ^(NSMutableDictionary *dict, NSString *collection, NSString *key, id object) {
        
        [properties enumerateObjectsUsingBlock:^(NSString *property, NSUInteger idx, BOOL *stop) {
            if ([object isKindOfClass:viewClass]) {
                if ([object respondsToSelector:NSSelectorFromString(property)]) {
                    if ([object valueForKey:property] != nil && ![[object valueForKey:property] isEqual:[NSNull null]]) {
                        //may have to check if NSString and NSURL have length?
                        
                        [dict setObject:[object valueForKey:property] forKey:property];
                    }
                }
            }
        }];
    };
    
    YapDatabaseFullTextSearch *fullTextSearch = [[YapDatabaseFullTextSearch alloc] initWithColumnNames:properties
                                                                                                 block:block
                                                                                             blockType:blockType];
    return fullTextSearch;
}

/**
 *  Does not register the view, but checks if it is registered and returns
 *  the registered view if it exists. (Caller should register the view)
 */
+ (YapDatabaseFilteredView*) filteredViewForType:(BRCDatabaseFilteredViewType)filterType
                                  parentViewName:(NSString*)parentViewName
                              allowedCollections:(NSSet*)allowedCollections
{
    YapDatabaseViewBlockType filteringBlockType = YapDatabaseViewBlockTypeWithObject;
    YapDatabaseViewFilteringBlock favoritesFilteringBlock = ^BOOL (NSString *group, NSString *collection, NSString *key, id object)
    {
        if ([object isKindOfClass:[BRCDataObject class]]) {
            BRCDataObject *dataObject = (BRCDataObject*)object;
            return dataObject.isFavorite;
        }
        return NO;
    };
    
    YapDatabaseViewFilteringBlock everythingFilteringBlock = [[self class] everythingFilteringBlock];
    
    YapDatabaseViewFilteringBlock filteringBlock = nil;
    
    YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];

    if (filterType == BRCDatabaseFilteredViewTypeFavorites) {
        filteringBlock = favoritesFilteringBlock;
    } else if (filterType == BRCDatabaseFilteredViewTypeEventExpirationAndType) {
        filteringBlock = everythingFilteringBlock;
    }
    if (allowedCollections) {
        options.allowedCollections = allowedCollections;
    }
    YapDatabaseFilteredView *filteredView =
    [[YapDatabaseFilteredView alloc] initWithParentViewName:parentViewName
                                             filteringBlock:filteringBlock
                                         filteringBlockType:filteringBlockType versionTag:nil options:options];
    return filteredView;
}

+ (NSString*) stringForExtensionType:(BRCDatabaseViewExtensionType)extensionType {
    switch (extensionType) {
        case BRCDatabaseViewExtensionTypeDistance:
            return @"Distance";
            break;
        case BRCDatabaseViewExtensionTypeTime:
            return @"Time";
            break;
        default:
            return nil;
            break;
    }
}

+ (NSString*) stringForFilteredExtensionType:(BRCDatabaseFilteredViewType)extensionType {
    switch (extensionType) {
        case BRCDatabaseFilteredViewTypeEventExpirationAndType:
            return @"EventExpirationAndType";
            break;
        case BRCDatabaseFilteredViewTypeFavorites:
            return @"Favorites";
            break;
        case BRCDatabaseFilteredViewTypeFullTextSearch:
            return @"Search";
            break;
        default:
            return nil;
            break;
    }
}

+ (NSString*) filteredViewNameForType:(BRCDatabaseFilteredViewType)filterType
                       parentViewName:(NSString*)parentViewName {
    NSParameterAssert(filterType != BRCDatabaseViewExtensionTypeUnknown);
    if (filterType == BRCDatabaseViewExtensionTypeUnknown) {
        return nil;
    }
    NSString *extensionString = [self stringForFilteredExtensionType:filterType];
    NSParameterAssert(parentViewName != nil);
    NSParameterAssert(extensionString != nil);
    return [NSString stringWithFormat:@"%@-%@Filter", parentViewName, extensionString];
}

+ (NSString*) databaseViewNameForClass:(Class)viewClass
                         extensionType:(BRCDatabaseViewExtensionType)extensionType {
    NSParameterAssert(extensionType != BRCDatabaseViewExtensionTypeUnknown);
    if (extensionType == BRCDatabaseViewExtensionTypeUnknown) {
        return nil;
    }
    NSString *classString = NSStringFromClass(viewClass);
    NSString *extensionString = [self stringForExtensionType:extensionType];
    NSParameterAssert(extensionString != nil);
    return [NSString stringWithFormat:@"%@%@View", classString, extensionString];
}

+ (YapDatabaseViewFilteringBlock)everythingFilteringBlock
{
    BOOL showExpiredEvents = [[NSUserDefaults standardUserDefaults] showExpiredEvents];
    
    NSSet *filteredSet = [NSSet setWithArray:[[NSUserDefaults standardUserDefaults] selectedEventTypes]];
    
    YapDatabaseViewFilteringBlock filteringBlock = ^BOOL (NSString *group, NSString *collection, NSString *key, id object)
    {
        if ([object isKindOfClass:[BRCEventObject class]]) {
            BRCEventObject *eventObject = (BRCEventObject*)object;
            BOOL eventHasEnded = eventObject.hasEnded;
            BOOL eventMatchesTypeFilter = [filteredSet containsObject:@(eventObject.eventType)];
            
            if ((eventMatchesTypeFilter || [filteredSet count] == 0)) {
                if (showExpiredEvents) {
                    return YES;
                } else {
                    return !eventHasEnded;
                }
            }
            
        }
        return NO;
    };
    
    return filteringBlock;
}

@end
