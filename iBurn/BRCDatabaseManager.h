//
//  BRCDatabaseManager.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YapDatabase.h"

@interface BRCDatabaseManager : NSObject

@property (nonatomic, strong, readonly) YapDatabase *database;
@property (nonatomic, strong, readonly) YapDatabaseConnection *mainThreadReadOnlyDatabaseConnection;
@property (nonatomic, strong, readonly) YapDatabaseConnection *readWriteDatabaseConnection;

- (BOOL)setupDatabaseWithName:(NSString*)databaseName;

+ (instancetype) sharedInstance;

@end
