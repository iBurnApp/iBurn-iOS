#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface BRCCampImage : MTLModel <MTLJSONSerializing>

@property (nonatomic, copy, readonly, nullable) NSURL *thumbnailURL;

@end

NS_ASSUME_NONNULL_END