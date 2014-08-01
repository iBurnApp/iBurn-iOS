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

@interface BRCDatabaseManager()
@property (nonatomic, strong) YapDatabase *database;
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
    
    self.readWriteDatabaseConnection = [self.database newConnection];
    self.readWriteDatabaseConnection.objectCacheLimit = 200;
    self.readWriteDatabaseConnection.metadataCacheLimit = 200;
    self.readWriteDatabaseConnection.name = @"readWriteDatabaseConnection";
        
    NSArray *viewsToRegister = @[[BRCArtObject class],
                                 [BRCCampObject class],
                                 [BRCEventObject class]];
    
    [viewsToRegister enumerateObjectsUsingBlock:^(Class viewClass, NSUInteger idx, BOOL *stop) {
        [self registerDatabaseViewForClass:viewClass extensionType:BRCDatabaseViewExtensionTypeDistance];
        [self registerDatabaseViewForClass:viewClass extensionType:BRCDatabaseViewExtensionTypeName];
        [self registerFullTextSearchForClass:viewClass withPropertiesToIndex:@[@"title"]];
        
        //filteredView
        if (viewClass == [BRCEventObject class]) {
            [self registerDatabaseViewForClass:viewClass extensionType:BRCDatabaseViewExtensionTypeTime];
            
            [self registerDatabaseFilteredViewForViewClass:viewClass filteredType:BRCDatabaseFilteredViewTypeFavorites parentType:BRCDatabaseViewExtensionTypeTime];
        }
        else {
            [self registerDatabaseFilteredViewForViewClass:viewClass filteredType:BRCDatabaseFilteredViewTypeFavorites parentType:BRCDatabaseViewExtensionTypeName];
        }
        
    }];
    
    

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

- (YapDatabaseViewBlockType)groupingBlockTypeForClass:(Class)viewClass extensionType:(BRCDatabaseViewExtensionType)extensionType {
    YapDatabaseViewBlockType groupingBlockType;
    if (viewClass == [BRCEventObject class]) {
        groupingBlockType = YapDatabaseViewBlockTypeWithObject;
    } else {
        groupingBlockType = YapDatabaseViewBlockTypeWithKey;
    }
    
    return groupingBlockType;
}

- (YapDatabaseViewGroupingBlock)groupingBlockForClass:(Class)viewClass extensionType:(BRCDatabaseViewExtensionType)extensionType {
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

- (YapDatabaseViewBlockType)sortingBlockTypeForClass:(Class)viewClass extensionType:(BRCDatabaseViewExtensionType)extensionType {
    YapDatabaseViewBlockType sortingBlockType = YapDatabaseViewBlockTypeWithObject;
    return sortingBlockType;
}

- (NSComparisonResult) compareDistanceOfFirstObject:(BRCDataObject*)object1 secondObject:(BRCDataObject*)object2 {
    return [@(object1.distanceFromUser) compare:@(object2.distanceFromUser)];
}

- (YapDatabaseViewSortingBlock)sortingBlockForClass:(Class)viewClass extensionType:(BRCDatabaseViewExtensionType)extensionType {
    YapDatabaseViewSortingBlock sortingBlock;
    if (extensionType == BRCDatabaseViewExtensionTypeTime) {
        sortingBlock = ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
                         NSString *collection2, NSString *key2, id obj2){
            if ([obj1 isKindOfClass:[BRCEventObject class]] && [obj2 isKindOfClass:[BRCEventObject class]]) {
                BRCEventObject *event1 = (BRCEventObject *)obj1;
                BRCEventObject *event2 = (BRCEventObject *)obj2;
                
                if (event1.isAllDay && !event2.isAllDay) {
                    return NSOrderedAscending;
                }
                else if (!event1.isAllDay && event2.isAllDay) {
                    return NSOrderedDescending;
                }
                
                NSComparisonResult dateComparison = [event1.startDate compare:event2.startDate];
                if (dateComparison == NSOrderedSame) {
                    NSComparisonResult distanceComparison = [self compareDistanceOfFirstObject:event1 secondObject:event2];
                    return distanceComparison;
                }
            }
            return NSOrderedSame;
        };
    } else if (extensionType == BRCDatabaseViewExtensionTypeName) {
        sortingBlock = ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
                         NSString *collection2, NSString *key2, id obj2){
            if ([obj1 isKindOfClass:viewClass] && [obj2 isKindOfClass:viewClass]) {
                BRCDataObject *data1 = (BRCDataObject *)obj1;
                BRCDataObject *data2 = (BRCDataObject *)obj2;
                return [data1.title compare:data2.title options:NSCaseInsensitiveSearch];
            }
            return NSOrderedSame;
        };
    } else if (extensionType == BRCDatabaseViewExtensionTypeDistance) {
        sortingBlock = ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
                         NSString *collection2, NSString *key2, id obj2){
            if ([obj1 isKindOfClass:viewClass] && [obj2 isKindOfClass:viewClass]) {
                BRCDataObject *data1 = (BRCDataObject *)obj1;
                BRCDataObject *data2 = (BRCDataObject *)obj2;
                return [self compareDistanceOfFirstObject:data1 secondObject:data2];
            }
            return NSOrderedSame;
        };
    }
    
    return sortingBlock;
}

- (void)registerDatabaseViewForClass:(Class)viewClass extensionType:(BRCDatabaseViewExtensionType)extensionType
{
    NSString *viewName = [[self class] extensionNameForClass:viewClass extensionType:extensionType];
    YapDatabaseView *view = [self.database registeredExtension:viewName];
    if (view) {
        return;
    }
    
    YapDatabaseViewBlockType groupingBlockType = [self groupingBlockTypeForClass:viewClass extensionType:extensionType];
    YapDatabaseViewGroupingBlock groupingBlock = [self groupingBlockForClass:viewClass extensionType:extensionType];
    
    YapDatabaseViewBlockType sortingBlockType = [self sortingBlockTypeForClass:viewClass extensionType:extensionType];
    YapDatabaseViewSortingBlock sortingBlock = [self sortingBlockForClass:viewClass extensionType:extensionType];
    
    YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
    options.isPersistent = YES;
    options.allowedCollections = [NSSet setWithObject:[viewClass collection]];
    
    YapDatabaseView *databaseView =
    [[YapDatabaseView alloc] initWithGroupingBlock:groupingBlock
                                 groupingBlockType:groupingBlockType
                                      sortingBlock:sortingBlock
                                  sortingBlockType:sortingBlockType
                                        versionTag:@"1"
                                           options:options];
    [self.database asyncRegisterExtension:databaseView withName:viewName completionBlock:^(BOOL ready) {
        NSLog(@"%@ ready", viewName);
    }];
}

- (void)registerFullTextSearchForClass:(Class)viewClass withPropertiesToIndex:(NSArray *)properties
{
    NSString *viewName = [[self class] extensionNameForClass:viewClass extensionType:BRCDatabaseViewExtensionTypeFullTextSearch];
    YapDatabaseView *view = [self.database registeredExtension:viewName];
    if (view) {
        return;
    }
    
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
    
    [self.database asyncRegisterExtension:fullTextSearch withName:viewName completionBlock:^(BOOL ready) {
        NSLog(@"%@ ready", viewName);
    }];
}

- (void)registerDatabaseFilteredViewForViewClass:(Class)viewClass filteredType:(BRCDatabaseFilteredViewType)filterType parentType:(BRCDatabaseViewExtensionType)parentExtensionType;
{
    NSString *filteredViewName = [[self class] filteredExtensionNameForClass:viewClass filterType:filterType];
    YapDatabase *view = [self.database registeredExtension:filteredViewName];
    if (view){
        return;
    }
    
    YapDatabaseViewBlockType filteringBlockType = YapDatabaseViewBlockTypeWithObject;
    YapDatabaseViewFilteringBlock favoritesFilteringBlock = ^BOOL (NSString *group, NSString *collection, NSString *key, id object)
    {
        if ([object isKindOfClass:[BRCDataObject class]]) {
            BRCDataObject *dataObject = (BRCDataObject*)object;
            return dataObject.isFavorite;
        }
        return NO;
    };
    
    YapDatabaseViewFilteringBlock eventsFilteringBlock = ^BOOL (NSString *group, NSString *collection, NSString *key, id object)
    {
        // we set the actual filtering block later in the events tab
        return YES;
    };
    
    YapDatabaseViewFilteringBlock filteringBlock = nil;
    
    if (filterType == BRCDatabaseFilteredViewTypeFavorites) {
        filteringBlock = favoritesFilteringBlock;
    } else if (filterType == BRCDatabaseFilteredViewTypeEventType) {
        filteringBlock = eventsFilteringBlock;
    }
 
    
    YapDatabaseFilteredView *filteredView =
    [[YapDatabaseFilteredView alloc] initWithParentViewName:[[self class] extensionNameForClass:viewClass extensionType:parentExtensionType]
                                             filteringBlock:filteringBlock
                                         filteringBlockType:filteringBlockType];
    
    
    [self.database asyncRegisterExtension:filteredView withName:filteredViewName completionBlock:^(BOOL ready) {
        NSLog(@"%@ ready", filteredViewName);
    }];
    
}

+ (NSString*) stringForExtensionType:(BRCDatabaseViewExtensionType)extensionType {
    switch (extensionType) {
        case BRCDatabaseViewExtensionTypeName:
            return @"Name";
            break;
        case BRCDatabaseViewExtensionTypeDistance:
            return @"Distance";
            break;
        case BRCDatabaseViewExtensionTypeFullTextSearch:
            return @"Search";
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
        case BRCDatabaseFilteredViewTypeEventType:
            return @"EventType";
            break;
        case BRCDatabaseFilteredViewTypeFavorites:
            return @"Favorites";
            break;
        default:
            return nil;
            break;
    }
}

+ (NSString*) filteredExtensionNameForClass:(Class)extensionClass filterType:(BRCDatabaseFilteredViewType)extensionType {
    NSParameterAssert(extensionType != BRCDatabaseViewExtensionTypeUnknown);
    if (extensionType == BRCDatabaseViewExtensionTypeUnknown) {
        return nil;
    }
    NSString *classString = NSStringFromClass(extensionClass);
    NSString *extensionString = [self stringForFilteredExtensionType:extensionType];
    NSParameterAssert(extensionString != nil);
    return [NSString stringWithFormat:@"%@%@ExtensionView", classString, extensionString];
}

+ (NSString*) extensionNameForClass:(Class)extensionClass extensionType:(BRCDatabaseViewExtensionType)extensionType {
    NSParameterAssert(extensionType != BRCDatabaseViewExtensionTypeUnknown);
    if (extensionType == BRCDatabaseViewExtensionTypeUnknown) {
        return nil;
    }
    NSString *classString = NSStringFromClass(extensionClass);
    NSString *extensionString = [self stringForExtensionType:extensionType];
    NSParameterAssert(extensionString != nil);
    return [NSString stringWithFormat:@"%@%@ExtensionView", classString, extensionString];
}

@end
