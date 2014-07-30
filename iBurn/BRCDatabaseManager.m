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

@interface BRCDatabaseManager()
@property (nonatomic, strong) YapDatabase *database;
@property (nonatomic, strong) YapDatabaseConnection *mainThreadReadOnlyDatabaseConnection;
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
    
    self.mainThreadReadOnlyDatabaseConnection = [self.database newConnection];
    self.mainThreadReadOnlyDatabaseConnection.objectCacheLimit = 500;
    self.mainThreadReadOnlyDatabaseConnection.metadataCacheLimit = 500;
    self.mainThreadReadOnlyDatabaseConnection.name = @"mainThreadReadOnlyDatabaseConnection";
    
    self.readWriteDatabaseConnection = [self.database newConnection];
    self.readWriteDatabaseConnection.objectCacheLimit = 200;
    self.readWriteDatabaseConnection.metadataCacheLimit = 200;
    self.readWriteDatabaseConnection.name = @"readWriteDatabaseConnection";
    
    [self.mainThreadReadOnlyDatabaseConnection beginLongLivedReadTransaction];
    
    NSArray *viewsToRegister = @[[BRCArtObject class],
                                 [BRCCampObject class],
                                 [BRCEventObject class]];
    
    [viewsToRegister enumerateObjectsUsingBlock:^(Class viewClass, NSUInteger idx, BOOL *stop) {
        [self registerDatabaseViewForClass:viewClass extensionType:BRCDatabaseViewExtensionTypeDistance];
        [self registerDatabaseViewForClass:viewClass extensionType:BRCDatabaseViewExtensionTypeName];
        [self registerFullTextSearchForClass:viewClass withPropertiesToIndex:@[@"title"]];
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


- (void)registerDatabaseViewForClass:(Class)viewClass extensionType:(BRCDatabaseViewExtensionType)extensionType
{
    NSString *viewName = [[self class] extensionNameForClass:viewClass extensionType:extensionType];
    YapDatabaseView *view = [self.database registeredExtension:viewName];
    if (view) {
        return;
    }
    
    
    YapDatabaseViewBlockType groupingBlockType;
    YapDatabaseViewGroupingWithKeyBlock groupingBlock;
    
    YapDatabaseViewBlockType sortingBlockType;
    YapDatabaseViewSortingWithObjectBlock sortingBlock;
    
    groupingBlockType = YapDatabaseViewBlockTypeWithKey;
    groupingBlock = ^NSString *(NSString *collection, NSString *key){
        
        if ([collection isEqualToString:[viewClass collection]])
        {
            return [viewClass collection];
        }
        
        return nil;
    };
    
    sortingBlockType = YapDatabaseViewBlockTypeWithObject;
    sortingBlock = ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
                     NSString *collection2, NSString *key2, id obj2){
        if ([group isEqualToString:[viewClass collection]]) {
            if ([obj1 isKindOfClass:viewClass] && [obj2 isKindOfClass:viewClass]) {
                BRCDataObject *data1 = (BRCDataObject *)obj1;
                BRCDataObject *data2 = (BRCDataObject *)obj2;
                
                if (extensionType == BRCDatabaseViewExtensionTypeName) {
                    return [data1.title compare:data2.title options:NSCaseInsensitiveSearch];
                } else if (extensionType == BRCDatabaseViewExtensionTypeDistance) {
                    if (data1.distanceFromUser < data2.distanceFromUser) {
                        return NSOrderedAscending;
                    } else {
                        return NSOrderedDescending;
                    }
                }
            }
        }
        return NSOrderedSame;
    };
    
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
        default:
            return nil;
            break;
    }
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
