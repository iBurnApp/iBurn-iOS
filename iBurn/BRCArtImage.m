#import "BRCArtImage.h"
#import <Mantle/NSValueTransformer+MTLPredefinedTransformerAdditions.h>

@implementation BRCArtImage

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
        NSStringFromSelector(@selector(thumbnailURL)): @"thumbnail_url",
        NSStringFromSelector(@selector(galleryRef)): @"gallery_ref"
    };
}

+ (NSValueTransformer *)thumbnailURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

@end