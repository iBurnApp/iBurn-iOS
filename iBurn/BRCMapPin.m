//
//  BRCMapPin.m
//  iBurn
//
//  Created by iBurn Development Team on 8/8/25.
//  Copyright © 2025 iBurn. All rights reserved.
//

#import "BRCMapPin.h"
#import "YearSettings.h"

@implementation BRCMapPin

@dynamic color;
@dynamic createdDate;
@dynamic notes;

+ (NSString *)yapCollection {
    return @"BRCMapPinCollection";
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _color = @"red";
        _createdDate = [NSDate date];
        self.year = @([YearSettings current].year);
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _color = [coder decodeObjectForKey:@"color"] ?: @"red";
        _createdDate = [coder decodeObjectForKey:@"createdDate"] ?: [NSDate date];
        _notes = [coder decodeObjectForKey:@"notes"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:self.color forKey:@"color"];
    [coder encodeObject:self.createdDate forKey:@"createdDate"];
    [coder encodeObject:self.notes forKey:@"notes"];
}

#pragma mark - Mantle

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSMutableDictionary *paths = [[super JSONKeyPathsByPropertyKey] mutableCopy];
    paths[@"color"] = @"color";
    paths[@"createdDate"] = @"created_date";
    paths[@"notes"] = @"notes";
    return paths;
}

+ (NSValueTransformer *)createdDateJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSString *dateString, BOOL *success, NSError **error) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
        return [formatter dateFromString:dateString];
    } reverseBlock:^id(NSDate *date, BOOL *success, NSError **error) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
        return [formatter stringFromDate:date];
    }];
}

@end