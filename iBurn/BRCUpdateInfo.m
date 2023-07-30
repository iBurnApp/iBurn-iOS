//
//  BRCUpdateInfo.m
//  iBurn
//
//  Created by Christopher Ballinger on 6/28/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "BRCUpdateInfo.h"
#import "NSDateFormatter+iBurn.h"
#import "BRCArtObject.h"
#import "BRCCampObject.h"
#import "BRCEventObject.h"
#import "BRCRecurringEventObject.h"
#import "BRCMapPoint.h"
#import "iBurn-Swift.h"

static NSString * const kBRCUpdateTypeCamps = @"camps";
static NSString * const kBRCUpdateTypeArt = @"art";
static NSString * const kBRCUpdateTypeEvents = @"events";
static NSString * const kBRCUpdateTypeTiles = @"tiles";
static NSString * const kBRCUpdateTypePoints = @"points";


@implementation BRCUpdateInfo

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{NSStringFromSelector(@selector(fileName)): @"file",
             NSStringFromSelector(@selector(lastUpdated)): @"updated"};
}

+ (NSValueTransformer *)lastUpdatedJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^NSDate*(NSString* dateString, BOOL *success, NSError *__autoreleasing *error) {
        NSDate *date = [[NSDateFormatter brc_playaEventsAPIDateFormatter] dateFromString:dateString];
        return date;
    }];
}

- (Class) dataObjectClass {
    return [[self class] classForDataType:self.dataType];
}

- (NSString*) yapKey {
    NSString *yapKey = [[self class] yapKeyForDataType:self.dataType];
    return yapKey;
}

+ (Class) classForDataType:(BRCUpdateDataType)dataType {
    switch (dataType) {
        case BRCUpdateDataTypeArt:
            return [BRCArtObject class];
            break;
        case BRCUpdateDataTypeCamps:
            return [BRCCampObject class];
            break;
        case BRCUpdateDataTypeEvents:
            return [BRCRecurringEventObject class];
            break;
        case BRCUpdateDataTypePoints:
            return [BRCMapPoint class];
            break;
        default:
            break;
    }
    return nil;
}

+ (BRCUpdateDataType) dataTypeForClass:(Class)dataObjectClass {
    if (dataObjectClass == [BRCCampObject class]) {
        return BRCUpdateDataTypeCamps;
    } else if (dataObjectClass == [BRCArtObject class]) {
        return BRCUpdateDataTypeArt;
    } else if (dataObjectClass == [BRCRecurringEventObject class] || dataObjectClass == [BRCEventObject class]) {
        return BRCUpdateDataTypeEvents;
    } else if (dataObjectClass == [BRCMapPoint class]) {
        return BRCUpdateDataTypePoints;
    }
    return BRCUpdateDataTypeUnknown;
}

/** Converts from updates.json keys */
+ (BRCUpdateDataType) dataTypeFromString:(NSString*)dataTypeString {
    if (!dataTypeString) {
        return BRCUpdateDataTypeUnknown;
    }
    if ([dataTypeString isEqualToString:kBRCUpdateTypeArt]) {
        return BRCUpdateDataTypeArt;
    } else if ([dataTypeString isEqualToString:kBRCUpdateTypeCamps]) {
        return BRCUpdateDataTypeCamps;
    } else if ([dataTypeString isEqualToString:kBRCUpdateTypeEvents]) {
        return BRCUpdateDataTypeEvents;
    } else if ([dataTypeString isEqualToString:kBRCUpdateTypeTiles]) {
        return BRCUpdateDataTypeTiles;
    } else if ([dataTypeString isEqualToString:kBRCUpdateTypePoints]) {
        return BRCUpdateDataTypePoints;
    }
    return BRCUpdateDataTypeUnknown;
}

- (void) setFetchStatus:(BRCUpdateFetchStatus)fetchStatus {
    _fetchStatus = fetchStatus;
    if (fetchStatus == BRCUpdateFetchStatusComplete) {
        _ingestionDate = [NSDate present];
    }
}

+ (NSString*) stringFromDataType:(BRCUpdateDataType)dataType {
    switch (dataType) {
        case BRCUpdateDataTypeArt:
            return kBRCUpdateTypeArt;
            break;
        case BRCUpdateDataTypeCamps:
            return kBRCUpdateTypeCamps;
            break;
        case BRCUpdateDataTypeEvents:
            return kBRCUpdateTypeEvents;
            break;
        case BRCUpdateDataTypeTiles:
            return kBRCUpdateTypeTiles;
            break;
        case BRCUpdateDataTypePoints:
            return kBRCUpdateTypePoints;
            break;
        default:
            return nil;
            break;
    }
}

/** Return yapKey for a subclass of BRCDataObject */
+ (NSString*) yapKeyForClass:(Class)dataObjectClass {
    BRCUpdateDataType dataType = [self dataTypeForClass:dataObjectClass];
    NSString *yapKey = [self yapKeyForDataType:dataType];
    return yapKey;
}

+ (NSString*) yapKeyForDataType:(BRCUpdateDataType)dataType {
    NSString *yapKey = [self stringFromDataType:dataType];
    return yapKey;
}

@end
