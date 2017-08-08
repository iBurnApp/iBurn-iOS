//
//  BRCYapDatabaseObject.m
//  iBurn
//
//  Created by Chris Ballinger on 6/19/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

#import "BRCYapDatabaseObject.h"

@implementation BRCYapDatabaseObject
@synthesize yapKey = _yapKey;
@dynamic yapCollection;

- (instancetype) init {
    return [self initWithYapKey:nil];
}

- (instancetype) initWithYapKey:(NSString *)yapKey {
    if (self = [super init]) {
        if (!yapKey) {
            yapKey = [NSUUID UUID].UUIDString;
        }
        _yapKey = [yapKey copy];
    }
    return self;
}

+ (NSString *)yapCollection
{
    return NSStringFromClass(self.class);
}

- (NSString*) yapCollection {
    return self.class.yapCollection;
}

- (void)saveWithTransaction:(YapDatabaseReadWriteTransaction *)transaction metadata:(nullable id)metadata {
    [transaction setObject:self forKey:self.yapKey inCollection:self.yapCollection withMetadata:metadata];
}

- (void)replaceWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    [transaction replaceObject:self forKey:self.yapKey inCollection:self.yapCollection];
}

- (void)removeWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    [transaction removeObjectForKey:self.yapKey inCollection:self.yapCollection];
}

- (void)touchWithTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    [transaction touchObjectForKey:self.yapKey inCollection:self.yapCollection];
}

/** This will fetch an updated instance of the object */
- (nullable instancetype)refetchWithTransaction:(nonnull YapDatabaseReadTransaction *)transaction {
    id object = [self.class fetchWithYapKey:self.yapKey transaction:transaction];
    return object;
}

+ (nullable instancetype) fetchWithYapKey:(NSString *)yapKey transaction:(YapDatabaseReadTransaction *)transaction {
    NSParameterAssert(yapKey);
    NSParameterAssert(transaction);
    if (!yapKey || !transaction) {
        return nil;
    }
    id object = [transaction objectForKey:yapKey inCollection:self.yapCollection];
    if ([object isKindOfClass:self]) {
        return object;
    }
    return nil;
}

/** It's not necessary to serialize the yapCollection in the object itself */
+ (NSDictionary *)encodingBehaviorsByPropertyKey {
    NSMutableDictionary *behaviors = [[super encodingBehaviorsByPropertyKey] mutableCopy];
    [behaviors setObject:@(MTLModelEncodingBehaviorExcluded) forKey:NSStringFromSelector(@selector(yapCollection))];
    return behaviors;
}

@end
