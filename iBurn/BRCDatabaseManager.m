//
//  BRCDatabaseManager.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDatabaseManager.h"
#import "YapDatabaseRelationship.h"

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

@end
