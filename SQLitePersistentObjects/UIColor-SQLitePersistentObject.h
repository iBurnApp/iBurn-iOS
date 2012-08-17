//
//  UIColor-SQLitePersistentObject.h
//  KnitMinder
//
//  Created by Paul Mietz Egli on 12/28/08.
//  Copyright 2008 Fullpower. All rights reserved.
//

#if (TARGET_OS_IPHONE)
#import "NSObject-SQLitePersistence.h"
#import <UIKit/UIKit.h>

@interface UIColor(SQLitePersistence) <SQLitePersistence> 
+ (id)objectWithSQLBlobRepresentation:(NSData *)data;
- (NSData *)sqlBlobRepresentationOfSelf;
+ (BOOL)canBeStoredInSQLite;
+ (NSString *)columnTypeForObjectStorage;
+ (BOOL)shouldBeStoredInBlob;
@end
#endif