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

@implementation BRCUpdateInfo

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{NSStringFromSelector(@selector(fileName)): @"file",
             NSStringFromSelector(@selector(lastUpdated)): @"updated"};
}

+ (NSValueTransformer *)lastUpdatedJSONTransformer {
    return [MTLValueTransformer transformerWithBlock:^NSDate*(NSString* dateString) {
        return [[NSDateFormatter brc_playaEventsAPIDateFormatter] dateFromString:dateString];
    }];
}

- (Class) dataObjectClass {
    return [[self class] classForDataType:self.dataType];
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
            return [BRCEventObject class];
            break;
        default:
            break;
    }
    return nil;
}

+ (NSString*) yapCollection {
    return NSStringFromClass([self class]);
}

/** Converts from updates.json keys */
+ (BRCUpdateDataType) dataTypeFromString:(NSString*)dataTypeString {
    if (!dataTypeString) {
        return BRCUpdateDataTypeUnknown;
    }
    if ([dataTypeString isEqualToString:@"art"]) {
        return BRCUpdateDataTypeArt;
    } else if ([dataTypeString isEqualToString:@"camps"]) {
        return BRCUpdateDataTypeCamps;
    } else if ([dataTypeString isEqualToString:@"events"]) {
        return BRCUpdateDataTypeEvents;
    } else if ([dataTypeString isEqualToString:@"tiles"]) {
        return BRCUpdateDataTypeTiles;
    }
    return BRCUpdateDataTypeUnknown;
}

@end
