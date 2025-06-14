#import "BRCCampImage.h"
#import <Mantle/NSValueTransformer+MTLPredefinedTransformerAdditions.h>

@implementation BRCCampImage

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
        NSStringFromSelector(@selector(thumbnailURL)): @"thumbnail_url"
    };
}

+ (NSValueTransformer *)thumbnailURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

@end