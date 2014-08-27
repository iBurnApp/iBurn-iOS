//
//  BRCDatabaseManager.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YapDatabase.h"

typedef NS_ENUM(NSUInteger, BRCDatabaseViewExtensionType) {
    BRCDatabaseViewExtensionTypeUnknown,
    BRCDatabaseViewExtensionTypeName,
    BRCDatabaseViewExtensionTypeDistance,
    BRCDatabaseViewExtensionTypeTime,
    BRCDatabaseViewExtensionTypeFullTextSearch
};

typedef NS_ENUM(NSUInteger, BRCDatabaseFilteredViewType) {
    BRCDatabaseFilteredViewTypeUnknown,
    BRCDatabaseFilteredViewTypeFavorites,
    BRCDatabaseFilteredViewTypeEventExpirationAndType
};

@interface BRCDatabaseManager : NSObject

@property (nonatomic, strong, readonly) YapDatabase *database;
@property (nonatomic, strong, readonly) YapDatabaseConnection *readWriteDatabaseConnection;

@property (nonatomic, strong) NSString *eventNameViewName;
@property (nonatomic, strong) NSString *eventDistanceViewName;
@property (nonatomic, strong) NSString *eventTimeViewName;


- (BOOL)setupDatabaseWithName:(NSString*)databaseName;

+ (instancetype) sharedInstance;

+ (NSString*) extensionNameForClass:(Class)extensionClass extensionType:(BRCDatabaseViewExtensionType)extensionType;
+ (NSString*) filteredExtensionNameForFilterType:(BRCDatabaseFilteredViewType)extensionType parentName:(NSString *)parentName;

@end
